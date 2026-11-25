/// Real LiteRT end-to-end test: loads the actual uint8 MobileNetV2 graph
/// through [LiteRtIsolateBridge] — worker isolate, CPU kernels, byte-wire
/// protocol, quantised output — and runs one inference on a solid image.
///
/// The model bytes are NOT committed (nothing is bundled in the app).
/// Point `LUMORA_TFLITE_TEST_MODEL` at a local `mobilenet_v2_1.0_224_quant.tflite`
/// (SHA-256 7aad0c74…) to enable; without it the suite skips itself, so CI
/// stays green and the check stays reproducible on any machine with the file.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/ai/data/model_manager.dart';
import 'package:lumora/features/ai/data/onnx_engine.dart' show AiException;
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:lumora/features/ai/engine/lite_rt_engine.dart';

void main() {
  final modelPath = Platform.environment['LUMORA_TFLITE_TEST_MODEL'];
  final source = modelPath == null ? null : File(modelPath);
  final available = source != null && source.existsSync();

  test('real LiteRT run: uint8 MobileNetV2 through the worker isolate', () async {
    if (!available) {
      // ignore: avoid_print — test diagnostics must reach the console.
      print(
        'SKIP: LUMORA_TFLITE_TEST_MODEL not set — set it to '
        'mobilenet_v2_1.0_224_quant.tflite (sha256 7aad0c74…) to enable.',
      );
      return;
    }

    const spec = ModelRegistry.mobilenetSceneLite;
    final dir = await Directory.systemTemp.createTemp('lumora-litert-real');
    final staged = File('${dir.path}/models/${spec.fileName}');
    await staged.parent.create(recursive: true);
    await source.copy(staged.path);
    expect(await staged.length(), spec.sizeBytes, reason: 'fixture must match the registry size');

    final manager = ModelManager(baseDir: () async => dir);
    final engine = LiteRtInferenceEngine(manager, accelerated: () => false);

    // Solid green 224² image in the uint8 NHWC contract.
    const side = 224;
    final input = Uint8List(side * side * 3);
    for (var i = 0; i < side * side; i++) {
      input[i * 3] = 34;
      input[i * 3 + 1] = 177;
      input[i * 3 + 2] = 76;
    }

    try {
      final out = await engine.run(spec, {
        spec.inputNames.first: (input, <int>[1, side, side, 3]),
      });

      expect(out.length, 1001, reason: 'uint8 MobileNetV2 emits 1001 classes');
      expect(out.every((v) => v >= 0 && v <= 255), isTrue, reason: 'raw uint8 range');
      // A solid-colour image must produce a confident, finite distribution.
      final maxVal = out.reduce((a, b) => a > b ? a : b);
      expect(maxVal, greaterThan(200), reason: 'quantised confidence for a trivial input');
    } on AiException catch (e) {
      if (e.detail?.contains('libtensorflowlite_c') ?? false) {
        // The host has no provisioned LiteRT C library (flutter test on a
        // bare Linux box). Skip — real-device runs cover the delegate paths.
        // ignore: avoid_print
        print(
          'SKIP: LiteRT C library not provisioned on this host '
          '(place libtensorflowlite_c-linux.so next to the flutter_tester '
          'binary, or run on macOS/iOS/Android where the plugin bundles it).',
        );
        return;
      }
      rethrow;
    } finally {
      await engine.release();
      if (dir.existsSync()) await dir.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
