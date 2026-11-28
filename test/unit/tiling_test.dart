import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/photo_editor/engine/tiling.dart';

/// C2/C3: the tiling planner is the memory-cap backbone for 12 MP+ and RAW
/// exports (ROADMAP §5 peak-memory budget) — a wrong plan either blows the
/// cap or leaves a seam. These tests pin coverage, padding clamps and the
/// blit/warp pixel math.
void main() {
  group('planTiles', () {
    test('image smaller than one tile is a single unpadded tile', () {
      final tiles = planTiles(800, 600);
      expect(tiles, hasLength(1));
      final t = tiles.single;
      expect((t.x, t.y, t.width, t.height), (0, 0, 800, 600));
      expect((t.padLeft, t.padTop, t.padRight, t.padBottom), (0, 0, 0, 0));
    });

    test('exact multiple gives full-size tiles with interior padding only', () {
      final tiles = planTiles(4096, 4096);
      expect(tiles, hasLength(4));
      for (final t in tiles) {
        expect(t.width, 2048);
        expect(t.height, 2048);
        // Padding reaches 64 inside the image and clamps to 0 at borders.
        expect(t.padLeft, t.x == 0 ? 0 : 64);
        expect(t.padTop, t.y == 0 ? 0 : 64);
        expect(t.padRight, t.x + t.width == 4096 ? 0 : 64);
        expect(t.padBottom, t.y + t.height == 4096 ? 0 : 64);
      }
    });

    test('cores tile any image exactly once, pads stay inside the image', () {
      for (final (w, h) in [(5000, 3000), (1, 1), (2048, 2048), (2049, 2047), (97, 8191)]) {
        final tiles = planTiles(w, h);
        // Full area, pairwise disjoint cores.
        final area = tiles.fold<int>(0, (a, t) => a + t.width * t.height);
        expect(area, w * h, reason: '$w x $h: core areas must sum to the image');
        for (var i = 0; i < tiles.length; i++) {
          for (var j = i + 1; j < tiles.length; j++) {
            final a = tiles[i];
            final b = tiles[j];
            final overlapX = a.x < b.x + b.width && b.x < a.x + a.width;
            final overlapY = a.y < b.y + b.height && b.y < a.y + a.height;
            expect(overlapX && overlapY, isFalse, reason: '$w x $h: tiles $i and $j overlap');
          }
        }
        for (final t in tiles) {
          expect(t.paddedX, greaterThanOrEqualTo(0), reason: '$w x $h');
          expect(t.paddedY, greaterThanOrEqualTo(0), reason: '$w x $h');
          expect(t.paddedX + t.paddedWidth, lessThanOrEqualTo(w), reason: '$w x $h');
          expect(t.paddedY + t.paddedHeight, lessThanOrEqualTo(h), reason: '$w x $h');
          // The padded tile is what hits the GPU: bounded by tile + 2*pad.
          expect(t.paddedWidth, lessThanOrEqualTo(2048 + 128), reason: '$w x $h');
          expect(t.paddedHeight, lessThanOrEqualTo(2048 + 128), reason: '$w x $h');
        }
      }
    });
  });

  group('blitTile', () {
    test('copies the core, drops the padding', () {
      // 4x3 image, one tile at (1,1) 2x2 with 1px padding on every side.
      const t = Tile(x: 1, y: 1, width: 2, height: 2, padLeft: 1, padTop: 1, padRight: 1, padBottom: 1);
      final tile = Uint8List(t.paddedWidth * t.paddedHeight * 4);
      for (var i = 0; i < tile.length; i += 4) {
        tile[i] = i ~/ 4; // r = pixel index in the padded tile
        tile[i + 3] = 255;
      }
      final dest = Uint8List(4 * 3 * 4);
      blitTile(dest, 4, tile, t);
      for (var row = 0; row < 2; row++) {
        for (var col = 0; col < 2; col++) {
          final dstPx = ((1 + row) * 4 + 1 + col) * 4;
          final srcPx = ((row + 1) * t.paddedWidth + col + 1) * 4;
          expect(dest[dstPx], tile[srcPx], reason: 'core pixel ($col,$row)');
          expect(dest[dstPx + 3], 255);
        }
      }
      // Outside the core stays zero (padding not blitted).
      expect(dest[0], 0);
      expect(dest[((2 * 4) + 3) * 4], 0);
    });
  });

  group('warpTileCpu', () {
    Uint8List gradient(int w, int h) {
      final src = Uint8List(w * h * 4);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final i = (y * w + x) * 4;
          src[i] = (x * 10) & 0xFF;
          src[i + 1] = (y * 20) & 0xFF;
          src[i + 2] = 7;
          src[i + 3] = 255;
        }
      }
      return src;
    }

    test('identity homography copies the source pixel for pixel', () {
      const sw = 16;
      const sh = 16;
      final src = gradient(sw, sh);
      final out = warpTileCpu(
        WarpTileRequest(
          src: src,
          srcWidth: sw,
          srcHeight: sh,
          inverse: [1 / sw, 0, 0, 0, 1 / sh, 0, 0, 0, 1],
          tileX: 0,
          tileY: 0,
          tileWidth: sw,
          tileHeight: sh,
        ),
      );
      expect(out, src);
    });

    test('translation samples the shifted source; outside is transparent', () {
      const sw = 16;
      const sh = 16;
      final src = gradient(sw, sh);
      // Sample (x+2, y-1): px -> (px+2)/sw, py -> (py-1)/sh.
      final out = warpTileCpu(
        WarpTileRequest(
          src: src,
          srcWidth: sw,
          srcHeight: sh,
          inverse: [1 / sw, 0, 2 / sw, 0, 1 / sh, -1 / sh, 0, 0, 1],
          tileX: 0,
          tileY: 0,
          tileWidth: sw,
          tileHeight: sh,
        ),
      );
      // Interior pixel (4, 4) reads source (6, 3).
      const o = (4 * sw + 4) * 4;
      const s = (3 * sw + 6) * 4;
      expect(out[o], src[s]);
      expect(out[o + 1], src[s + 1]);
      expect(out[o + 2], src[s + 2]);
      // Row 0 samples source row -1: out of range, transparent black.
      expect(out.sublist(0, 4), [0, 0, 0, 0]);
    });
  });
}
