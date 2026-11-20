import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumora/features/photo_editor/domain/geometry.dart';

/// A rectangular region of the output image processed independently.
class Tile {
  const Tile({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.padLeft,
    required this.padTop,
    required this.padRight,
    required this.padBottom,
  });

  /// Core region (without padding) in output pixels.
  final int x;
  final int y;
  final int width;
  final int height;

  /// Extra context rendered around the core so neighbourhood filters
  /// (sharpen, clarity, blur) have no seams.
  final int padLeft;
  final int padTop;
  final int padRight;
  final int padBottom;

  int get paddedX => x - padLeft;
  int get paddedY => y - padTop;
  int get paddedWidth => width + padLeft + padRight;
  int get paddedHeight => height + padTop + padBottom;
}

/// Splits a [width]x[height] image into tiles of at most [tileSize] with
/// [padding] pixels of overlap (clamped at the image borders).
List<Tile> planTiles(int width, int height, {int tileSize = 2048, int padding = 64}) {
  final tiles = <Tile>[];
  for (var y = 0; y < height; y += tileSize) {
    for (var x = 0; x < width; x += tileSize) {
      final w = math.min(tileSize, width - x);
      final h = math.min(tileSize, height - y);
      tiles.add(
        Tile(
          x: x,
          y: y,
          width: w,
          height: h,
          padLeft: math.min(padding, x),
          padTop: math.min(padding, y),
          padRight: math.min(padding, width - (x + w)),
          padBottom: math.min(padding, height - (y + h)),
        ),
      );
    }
  }
  return tiles;
}

/// Arguments for [warpTileCpu], sendable to an isolate.
class WarpTileRequest {
  const WarpTileRequest({
    required this.src,
    required this.srcWidth,
    required this.srcHeight,
    required this.inverse,
    required this.tileX,
    required this.tileY,
    required this.tileWidth,
    required this.tileHeight,
  });

  final Uint8List src;
  final int srcWidth;
  final int srcHeight;
  final List<double> inverse;
  final int tileX;
  final int tileY;
  final int tileWidth;
  final int tileHeight;
}

/// CPU implementation of `warp.frag` for one tile: bilinear sampling of the
/// RGBA source through the inverse homography. Used for images larger than
/// the GPU texture limit.
Uint8List warpTileCpu(WarpTileRequest r) {
  final m = Mat3(r.inverse);
  final out = Uint8List(r.tileWidth * r.tileHeight * 4);
  final sw = r.srcWidth;
  final sh = r.srcHeight;
  final src = r.src;
  var o = 0;
  for (var ty = 0; ty < r.tileHeight; ty++) {
    for (var tx = 0; tx < r.tileWidth; tx++) {
      final (u, v) = m.apply(r.tileX + tx + 0.5, r.tileY + ty + 0.5);
      if (u < 0 || v < 0 || u > 1 || v > 1) {
        o += 4;
        continue;
      }
      final fx = (u * sw - 0.5).clamp(0.0, sw - 1.0);
      final fy = (v * sh - 0.5).clamp(0.0, sh - 1.0);
      final x0 = fx.floor();
      final y0 = fy.floor();
      final x1 = math.min(x0 + 1, sw - 1);
      final y1 = math.min(y0 + 1, sh - 1);
      final ax = fx - x0;
      final ay = fy - y0;
      final i00 = (y0 * sw + x0) * 4;
      final i10 = (y0 * sw + x1) * 4;
      final i01 = (y1 * sw + x0) * 4;
      final i11 = (y1 * sw + x1) * 4;
      for (var c = 0; c < 4; c++) {
        final top = src[i00 + c] * (1 - ax) + src[i10 + c] * ax;
        final bot = src[i01 + c] * (1 - ax) + src[i11 + c] * ax;
        out[o + c] = (top * (1 - ay) + bot * ay).round();
      }
      o += 4;
    }
  }
  return out;
}

/// Copies the core region of a rendered padded tile into [dest].
void blitTile(Uint8List dest, int destWidth, Uint8List tileRgba, Tile t) {
  for (var row = 0; row < t.height; row++) {
    final srcStart = ((row + t.padTop) * t.paddedWidth + t.padLeft) * 4;
    final dstStart = ((t.y + row) * destWidth + t.x) * 4;
    dest.setRange(dstStart, dstStart + t.width * 4, tileRgba, srcStart);
  }
}
