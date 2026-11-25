import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/ai/data/onnx_engine.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:lumora/features/ai/pipelines/sky_pipeline.dart';
import 'package:lumora/features/ai/pipelines/tensor_utils.dart';

/// Fake engine returning a synthetic sky map: the top half is sky with a
/// linear 1.0 → 0.55 gradient, the bottom half is ground (0.0).
class _SkyFake implements InferenceEngine {
  final calls = <Map<String, List<int>>>[];

  @override
  Future<List<num>> run(ModelSpec model, Map<String, (TypedData, List<int>)> inputs) async {
    expect(model.id, 'skyseg_q8');
    calls.add({for (final e in inputs.entries) e.key: e.value.$2});
    final out = Float32List(320 * 320);
    for (var y = 0; y < 320; y++) {
      for (var x = 0; x < 320; x++) {
        out[y * 320 + x] = y < 160 ? 1 - (y / 160) * 0.45 : 0;
      }
    }
    return out;
  }

  @override
  Future<Map<String, List<num>>> runAll(ModelSpec model, Map<String, (TypedData, List<int>)> inputs) =>
      throw UnimplementedError();

  @override
  Future<void> release() async {}
}

RgbaImage _gradientRaster(int w, int h) {
  final px = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final o = (y * w + x) * 4;
      px[o] = 100;
      px[o + 1] = 120;
      px[o + 2] = 140;
      px[o + 3] = 255;
    }
  }
  return RgbaImage(w, h, px);
}

/// Synthetic matte: rows 0–1 fully sky, row 2 half sky, row 3 ground.
SkyResult _syntheticResult() {
  final matte = Float32List(4 * 4)..fillRange(0, 8, 1);
  matte[8] = matte[9] = matte[10] = matte[11] = 0.5;
  return SkyResult(matte, 4, 9 / 16);
}

void main() {
  test('analyze decodes the reference contract (ImageNet norm, min-max, 0.5 gate)', () async {
    final fake = _SkyFake();
    final sky = await SkyPipeline(fake).analyze(_gradientRaster(64, 64));

    // Model input shape: static [1, 3, 320, 320].
    expect(fake.calls.single['input.1'], [1, 3, 320, 320]);

    // Top half classified as sky → fraction ≈ 0.5.
    expect(sky.side, 320);
    expect(sky.fraction, closeTo(0.5, 0.01));

    // Matte is min-max normalised: max 1 at the very top.
    expect(sky.matte.reduce(math.max), closeTo(1.0, 1e-6));
    expect(sky.matte.reduce(math.min), closeTo(0.0, 1e-6));
  });

  test('sample interpolates the matte bilinearly', () {
    final sky = _syntheticResult();
    expect(sky.sample(0, 0), 1);
    expect(sky.sample(0.9, 0.9), 0);
    expect(sky.sample(0.5, 0.5), closeTo(0.75, 0.01));
    // Out-of-range coordinates clamp.
    expect(sky.sample(-1, -1), 1);
    expect(sky.sample(2, 2), 0);
  });

  test('skySpan finds the horizon row', () {
    final sky = _syntheticResult();
    // Rows 0–1 are full sky (4/4 px > 0.5); row 2 is 4/4 at 0.5 — the gate
    // is strict, so the span ends at row 1.
    final (top, bottom) = sky.skySpan()!;
    expect(top, 0.0);
    expect(bottom, closeTo(0.25, 0.01));
  });

  test('compositeSky replaces the sky with the preset gradient, ground untouched', () {
    final raster = _gradientRaster(4, 4);
    final out = compositeSky(raster, _syntheticResult(), SkyPreset.sunset);

    final (topRGB, bottomRGB) = SkyPreset.sunset.stops;
    // Row 0 (alpha 1, gradient top): exact preset top colour.
    expect(out.pixels.sublist(0, 3), [topRGB[0], topRGB[1], topRGB[2]]);
    // Row 1 (alpha 1, t = 1): exact preset horizon colour.
    expect(out.pixels.sublist(4 * 4, 4 * 4 + 3), [bottomRGB[0], bottomRGB[1], bottomRGB[2]]);
    // Row 3 (alpha 0): untouched.
    expect(out.pixels.sublist(12 * 4, 12 * 4 + 3), [100, 120, 140]);
    // Row 2: bilinear matte sample between row 1 (0.5 → ground 0) gives
    // alpha 0.5 · (1 − 1/6) — blend of horizon colour and the original.
    const a = 0.5 * (1 - 1 / 6);
    final expectedR = (100 * (1 - a) + bottomRGB[0] * a).round();
    expect(out.pixels.sublist(8 * 4, 8 * 4 + 1), [expectedR]);
    // Alpha stays opaque (mask compositing is value-only).
    expect(out.pixels[3], 255);
    expect(out.pixels[12 * 4 + 3], 255);
  });

  test('every preset has distinct, sane gradient stops', () {
    final presets = SkyPreset.values.map((p) => (p, p.stops)).toList();
    for (final (_, (top, bottom)) in presets) {
      expect(top.length, 3);
      expect(bottom.length, 3);
      for (final c in [...top, ...bottom]) {
        expect(c, inInclusiveRange(0, 255));
      }
    }
    expect(presets.map((e) => e.$2).toSet().length, SkyPreset.values.length);
  });
}
