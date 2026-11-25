import 'dart:isolate';

import 'package:lumora/features/ai/data/onnx_engine.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:lumora/features/ai/domain/scene_tags.dart';
import 'package:lumora/features/ai/pipelines/tensor_utils.dart';

/// Scene-aware suggestions: classifies the preview proxy with the small
/// MobileNetV2 int8 model (~3.5 MB, 2.4 ms per frame on a 2-core x86
/// sandbox) and aggregates the 1000 ImageNet logits into [SceneTag]
/// scores. The caller must only run this when the model is already on the
/// device (`ModelManager.isInstalled`) — suggestions never download it.
///
/// Preprocessing is the zoo contract: RGB 0..1, ImageNet mean/std
/// normalisation, static 224×224 input (see docs/SMART_EDIT.md).
class SceneClassifierPipeline {
  SceneClassifierPipeline(this.engine);

  final InferenceEngine engine;

  static const ModelSpec _spec = ModelRegistry.mobilenetScene;

  Future<SceneResult> run(RgbaImage proxy) async {
    final side = _spec.fixedInputSize!;
    final (tensor, shape) = await Isolate.run(() {
      final t = rgbaToNchw(
        proxy.resize(side, side),
        mean: const [0.485, 0.456, 0.406],
        std: const [0.229, 0.224, 0.225],
      );
      return (t, <int>[1, 3, side, side]);
    });
    final logits = await engine.run(_spec, {_spec.inputNames.first: (tensor, shape)});
    if (logits.length != 1000) {
      throw AiException(AiErrorKind.inference, model: _spec, detail: 'unexpected logits length ${logits.length}');
    }
    return await Isolate.run(() => SceneResult.fromLogits(logits));
  }
}
