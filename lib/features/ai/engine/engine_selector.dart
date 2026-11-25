/// Chooses between the ONNX Runtime engine and the LiteRT engine per model
/// (Wave 2 W1 — LiteRT/NPU runtime).
///
/// Policy, best first:
/// 1. Acceleration **off** → ONNX on CPU (today's shipped behaviour, bit
///    for bit).
/// 2. Model has no `.tflite` variant, the device offers no NPU/GPU delegate,
///    or the variant's file is not installed → ONNX. LiteRT variants are
///    **never downloaded on demand** — the optional-model policy carries
///    over: install the variant (Settings › AI models) and it is used from
///    the next session load on.
/// 3. Otherwise LiteRT runs the `spec.lite` variant; any failure
///    transparently retries the request on ONNX with the original spec, and
///    after two consecutive LiteRT failures the model is pinned to ONNX for
///    the rest of the session (no thrash between engines).
///
/// [specFor] exposes the resolved spec so contract-aware pipelines can build
/// inputs that match the graph that will actually run (uint8 NHWC for the
/// quantised LiteRT graphs vs float NCHW for the ONNX zoo exports).
///
/// The selector is itself an [InferenceEngine], so pipelines and providers
/// stay untouched.
library;

import 'dart:typed_data';

import 'package:lumora/core/diagnostics/crash_log.dart';
import 'package:lumora/features/ai/data/onnx_engine.dart' show InferenceEngine;
import 'package:lumora/features/ai/domain/model_registry.dart';

class EngineSelector implements InferenceEngine {
  EngineSelector({
    required this.onnx,
    required this.liteRt,
    required this.accelerated,
    required this.hasAccelerators,
    Future<bool> Function(ModelSpec spec)? liteInstalled,
  }) : _liteInstalled = liteInstalled ?? ((spec) async => false);

  final InferenceEngine onnx;
  final InferenceEngine liteRt;
  final bool Function() accelerated;
  final bool Function() hasAccelerators;

  /// Whether a `.tflite` variant is already on the device (no auto-download).
  final Future<bool> Function(ModelSpec spec) _liteInstalled;

  /// Models that failed on LiteRT twice → ONNX for the rest of the session.
  final Set<String> _pinnedToOnnx = {};

  /// Consecutive LiteRT failures per model id.
  final Map<String, int> _liteRtFailures = {};

  /// Whether [model] would prefer the LiteRT path when its variant is
  /// installed (diagnostics; the installed check happens in [specFor]).
  bool prefersLiteRt(ModelSpec model) =>
      accelerated() && hasAccelerators() && model.lite != null && !_pinnedToOnnx.contains(model.id);

  /// The spec that will actually run: the installed LiteRT variant or the
  /// original ONNX model.
  @override
  Future<ModelSpec> specFor(ModelSpec model) async {
    final lite = model.lite;
    if (lite == null || !prefersLiteRt(model)) return model;
    if (await _liteInstalled(lite)) return lite;
    return model;
  }

  @override
  Future<List<num>> run(ModelSpec model, Map<String, (TypedData, List<int>)> inputs) async {
    final outputs = await runAll(model, inputs);
    final out = outputs[model.outputName] ?? outputs.values.first;
    return out;
  }

  @override
  Future<Map<String, List<num>>> runAll(ModelSpec model, Map<String, (TypedData, List<int>)> inputs) async {
    final spec = await specFor(model);
    if (identical(spec, model)) {
      return onnx.runAll(model, inputs);
    }
    try {
      final out = await liteRt.runAll(spec, inputs);
      _liteRtFailures.remove(model.id);
      return out;
    } on Object catch (e) {
      final fails = (_liteRtFailures[model.id] ?? 0) + 1;
      _liteRtFailures[model.id] = fails;
      if (fails >= 2) {
        _pinnedToOnnx.add(model.id);
        CrashLog.instance.breadcrumb('AI: ${model.id} pinned to ONNX after $fails LiteRT failures');
      }
      CrashLog.instance.breadcrumb('AI: LiteRT failed for ${model.id} ($fails) — retrying on ONNX: $e');
      return onnx.runAll(model, inputs);
    }
  }

  @override
  Future<void> release() async {
    await Future.wait<void>([onnx.release(), liteRt.release()]);
  }

  /// Diagnostics: models pinned to ONNX this session.
  Set<String> get pinnedToOnnx => Set.unmodifiable(_pinnedToOnnx);
}
