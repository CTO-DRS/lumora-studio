import 'dart:isolate';
import 'dart:math' as math;

import 'package:lumora/features/ai/data/onnx_engine.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:lumora/features/ai/domain/scene_tags.dart';
import 'package:lumora/features/ai/pipelines/tensor_utils.dart';

/// Scene-aware suggestions: classifies the preview proxy with the small
/// MobileNetV2 model (~3.5 MB, 2.4 ms per frame on a 2-core x86 sandbox)
/// and aggregates the 1000 ImageNet logits into [SceneTag] scores. The
/// caller must only run this when the model is already on the device
/// (`ModelManager.isInstalled`) — suggestions never download it.
///
/// Two graph contracts, chosen by [InferenceEngine.specFor]:
/// * ONNX zoo int8 export: float NCHW 224², ImageNet mean/std, 1000 logits.
/// * LiteRT uint8 sibling (installed-gated): uint8 NHWC 224², RGB 0..255,
///   1001 probabilities (class 0 = background, dropped; scale 1/256).
///   Probabilities are mapped through log() so [SceneResult.fromLogits]'s
///   softmax recovers the exact probability distribution.
class SceneClassifierPipeline {
  SceneClassifierPipeline(this.engine);

  final InferenceEngine engine;

  static const ModelSpec _spec = ModelRegistry.mobilenetScene;

  Future<SceneResult> run(RgbaImage proxy) async {
    final spec = await engine.specFor(_spec);
    final side = spec.fixedInputSize!;
    final logits = switch (spec.format) {
      'tflite' => await _runLiteRt(spec, proxy, side),
      _ => await _runOnnx(spec, proxy, side),
    };
    return await Isolate.run(() => SceneResult.fromLogits(logits));
  }

  Future<List<num>> _runOnnx(ModelSpec spec, RgbaImage proxy, int side) async {
    final (tensor, shape) = await Isolate.run(() {
      final t = rgbaToNchw(
        proxy.resize(side, side),
        mean: const [0.485, 0.456, 0.406],
        std: const [0.229, 0.224, 0.225],
      );
      return (t, <int>[1, 3, side, side]);
    });
    final logits = await engine.run(spec, {spec.inputNames.first: (tensor, shape)});
    if (logits.length != 1000) {
      throw AiException(AiErrorKind.inference, model: spec, detail: 'unexpected logits length ${logits.length}');
    }
    return logits;
  }

  Future<List<num>> _runLiteRt(ModelSpec spec, RgbaImage proxy, int side) async {
    final (tensor, shape) = await Isolate.run(() {
      final t = rgbaToNhwcUint8(proxy.resize(side, side));
      return (t, <int>[1, side, side, 3]);
    });
    final raw = await engine.run(spec, {spec.inputNames.first: (tensor, shape)});
    if (raw.length != 1001) {
      throw AiException(AiErrorKind.inference, model: spec, detail: 'unexpected class length ${raw.length}');
    }
    // Dequantised probabilities (scale 1/256, zero point 0) → log-probabilities;
    // softmax(ln p) = p/Σp, so the tag aggregation sees the true distribution.
    return await Isolate.run(() {
      final out = List<num>.filled(1000, 0);
      for (var i = 0; i < 1000; i++) {
        final p = raw[i + 1].toDouble() / 256; // +1 skips the background class.
        out[i] = math.log(math.max(p, 1e-6));
      }
      return out;
    });
  }
}
