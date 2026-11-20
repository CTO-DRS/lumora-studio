import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/ai/pipelines/tensor_utils.dart';
import 'package:lumora/features/photo_editor/engine/tiling.dart';

RgbaImage _solid(int w, int h, List<int> rgba) {
  final img = RgbaImage(w, h);
  for (var i = 0; i < w * h; i++) {
    img.pixels.setRange(i * 4, i * 4 + 4, rgba);
  }
  return img;
}

void main() {
  test('rgbaToNchw normalizes into planar layout and back', () {
    final img = _solid(2, 1, [255, 0, 128, 255]);
    final t = rgbaToNchw(img, mean: const [0.5, 0.5, 0.5], std: const [0.5, 0.5, 0.5]);
    expect(t.length, 6);
    expect(t[0], closeTo(1, 1e-6)); // R plane
    expect(t[2], closeTo(-1, 1e-6)); // G plane
    final back = nchwToRgba(rgbaToNchw(img), 2, 1);
    expect(back.pixels.sublist(0, 4), [255, 0, 128, 255]);
  });

  test('uint8 NCHW layout', () {
    final t = rgbaToNchwUint8(_solid(1, 2, [1, 2, 3, 255]));
    expect(t, [1, 1, 2, 2, 3, 3]);
  });

  test('normalizeMinMax', () {
    expect(normalizeMinMax([2, 4, 6]), [0, 0.5, 1]);
    expect(normalizeMinMax([3, 3]), [0, 0]);
  });

  test('matte to mask and alpha application', () {
    final mask = matteToMask(Float32List.fromList([0, 1, 1, 0]), 2, 2, 4, 4);
    expect(mask.width, 4);
    final cut = applyMaskAsAlpha(_solid(4, 4, [10, 20, 30, 255]), mask);
    expect(cut.pixels[3], lessThan(128)); // top-left mostly transparent
    expect(cut.pixels[(0 * 4 + 3) * 4 + 3], greaterThan(127));
  });

  test('resize keeps solid colours', () {
    final r = _solid(3, 3, [50, 100, 150, 255]).resize(7, 5);
    expect(r.pixels.sublist(4 * 17, 4 * 17 + 4), [50, 100, 150, 255]);
  });

  test('fitForModel rounds to multiples', () {
    final (w, h) = fitForModel(4000, 3000, maxSide: 512);
    expect(w % 32, 0);
    expect(h % 32, 0);
    expect(w, 512);
    expect(h, 384);
  });

  test('mask bounds and dilation', () {
    final m = _solid(10, 10, [0, 0, 0, 255]);
    const o = (5 * 10 + 5) * 4;
    m.pixels[o] = 255;
    expect(maskBounds(m), (5, 5, 1, 1));
    final d = dilateMask(m, 2);
    expect(maskBounds(d), (3, 3, 5, 5));
    expect(maskBounds(_solid(3, 3, [0, 0, 0, 255])), isNull);
  });

  test('SR tiles cover the image fully with full-size tiles', () {
    final tiles = planSrTiles(300, 130);
    final covered = List.generate(130, (_) => List.filled(300, false));
    for (final t in tiles) {
      expect(t.x + t.size, lessThanOrEqualTo(300));
      expect(t.y + t.size, lessThanOrEqualTo(130));
      for (var y = t.y; y < t.y + t.size; y++) {
        for (var x = t.x; x < t.x + t.size; x++) {
          covered[y][x] = true;
        }
      }
    }
    expect(covered.every((r) => r.every((c) => c)), isTrue);
  });

  test('export tiling covers output exactly once', () {
    final tiles = planTiles(5000, 3000);
    var area = 0;
    for (final t in tiles) {
      area += t.width * t.height;
      expect(t.paddedX, greaterThanOrEqualTo(0));
      expect(t.paddedX + t.paddedWidth, lessThanOrEqualTo(5000));
    }
    expect(area, 5000 * 3000);
  });

  test('CPU warp with identity copies pixels', () {
    final src = Uint8List.fromList(List.generate(4 * 4 * 4, (i) => i % 256));
    final out = warpTileCpu(
      WarpTileRequest(
        src: src,
        srcWidth: 4,
        srcHeight: 4,
        inverse: const [0.25, 0, 0, 0, 0.25, 0, 0, 0, 1],
        tileX: 0,
        tileY: 0,
        tileWidth: 4,
        tileHeight: 4,
      ),
    );
    expect(out, src);
  });
}
