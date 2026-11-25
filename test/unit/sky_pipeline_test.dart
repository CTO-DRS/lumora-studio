import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/ai/data/onnx_engine.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:lumora/features/ai/pipelines/sky_pipeline.dart';
import 'package:lumora/features/ai/pipelines/tensor_utils.dart';

/// Fake engine returning a caller-defined flat output for a model id.
class ScriptedEngine implements InferenceEngine {
  ScriptedEngine(this.responses);
  final Map<String, List<num>> responses;
  final calls = <(String, Map<String, List<int>>)>[];

  @override
  Future<List<num>> run(ModelSpec model, Map<String, (TypedData, List<int>)> inputs) async {
    calls.add((model.id, {for (final e in inputs.entries) e.key: e.value.$2}));
    return responses[model.id] ?? List<num>.filled(320 * 320, 0);
  }

  @override
  Future<Map<String, List<num>>> runNamed(
    ModelSpec model,
    Map<String, (TypedData, List<int>)> inputs, {
    Set<String> outputs = const {},
  }) async => {model.outputName: await run(model, inputs)};

  @override
  Future<void> release() async {}
}

RgbaImage _gradient(int w, int h) {
  final px = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final o = (y * w + x) * 4;
      px[o] = x * 255 ~/ w;
      px[o + 1] = y * 255 ~/ h;
      px[o + 3] = 255;
    }
  }
  return RgbaImage(w, h, px);
}

void main() {
  group('SkySeg matte', () {
    test('top half sky → soft mask and fraction', () async {
      // Raw U²-Net-style output: top rows 2.0, bottom rows -1.0 → after
      // min–max normalisation 1 / 0.
      final out = Float32List(320 * 320);
      for (var y = 0; y < 320; y++) {
        for (var x = 0; x < 320; x++) {
          out[y * 320 + x] = y < 160 ? 2.0 : -1.0;
        }
      }
      final engine = ScriptedEngine({'skyseg_int8': out});
      final pipeline = SkyPipeline(engine);
      final (mask, fraction) = await pipeline.matte(_gradient(200, 200));

      expect(fraction, closeTo(0.5, 0.01));
      expect(engine.calls.single.$1, 'skyseg_int8');
      expect(engine.calls.single.$2['input.1'], [1, 3, 320, 320]);
      int at(int x, int y) => mask.pixels[(y * 200 + x) * 4];
      expect(at(100, 20), greaterThan(240)); // sky
      expect(at(100, 180), lessThan(15)); // ground
    });

    test('no sky (flat output) → fraction 0', () async {
      final engine = ScriptedEngine({'skyseg_int8': List<num>.filled(320 * 320, 0.5)});
      final (mask, fraction) = await SkyPipeline(engine).matte(_gradient(64, 64));
      expect(fraction, 0);
      // min–max normalisation of a constant plane is 0 everywhere.
      expect(mask.pixels[0], 0);
      expect(mask.pixels[(64 * 64 - 1) * 4], 0);
    });
  });

  test('coverFit scales to cover and centre-crops', () {
    final src = _gradient(100, 50);
    final fitted = SkyPipeline.coverFit(src, 100, 100);
    expect(fitted.width, 100);
    expect(fitted.height, 100);
    // The source was scaled ×2 (200×100) then cropped to x∈[50,150).
    // Column 50 of the crop = source column 25 → R ≈ 25*255/100 = 63.75.
    expect(fitted.pixels[0], closeTo(63.75, 1.5));
  });

  test('compositeSkyReplacement blends by the matte', () {
    final src = _solid(4, 2, 100);
    final replacement = _solid(4, 2, 200);
    final mask = RgbaImage(4, 2);
    void setMask(int x, int y, int v) {
      final o = (y * 4 + x) * 4;
      mask.pixels[o] = v;
      mask.pixels[o + 1] = v;
      mask.pixels[o + 2] = v;
      mask.pixels[o + 3] = 255;
    }

    setMask(0, 0, 255); // full sky
    setMask(1, 0, 128); // half
    setMask(2, 0, 0); // no sky

    final out = SkyPipeline.compositeSkyReplacement(src, replacement, mask);
    expect(out.pixels[0], 200);
    expect(out.pixels[4], 150); // 100*(0.5) + 200*(0.5)
    expect(out.pixels[8], 100);
    expect(out.pixels[(0 * 4 + 3) * 4 + 3], 255); // row 1 untouched
    expect(out.pixels[(1 * 4 + 0) * 4], 100);
  });
}

RgbaImage _solid(int w, int h, [int v = 128]) {
  final px = Uint8List(w * h * 4);
  for (var i = 0; i < w * h; i++) {
    px[i * 4] = v;
    px[i * 4 + 1] = v;
    px[i * 4 + 2] = v;
    px[i * 4 + 3] = 255;
  }
  return RgbaImage(w, h, px);
}
