import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'package:lumora/features/ai/data/model_manager.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';

/// Abstraction over the inference runtime so pipelines can be unit tested
/// with a fake and the runtime can be swapped (e.g. LiteRT) later.
abstract class InferenceEngine {
  /// Runs [model] with named inputs. Each input is a typed list
  /// ([Float32List] or [Uint8List]) and its shape.
  Future<List<num>> run(ModelSpec model, Map<String, (TypedData, List<int>)> inputs);

  Future<void> release();
}

/// ONNX Runtime implementation (flutter_onnxruntime). Uses the platform's
/// accelerated execution providers when available (CoreML on iOS, NNAPI /
/// XNNPACK on Android) and falls back to CPU.
class OnnxInferenceEngine implements InferenceEngine {
  OnnxInferenceEngine(this._models);

  final ModelManager _models;
  final OnnxRuntime _ort = OnnxRuntime();
  final Map<String, OrtSession> _sessions = {};

  Future<OrtSession> _session(ModelSpec spec) async {
    final existing = _sessions[spec.id];
    if (existing != null) return existing;
    final file = await _models.ensure(spec);
    final providers = <OrtProvider>[
      if (Platform.isIOS || Platform.isMacOS) OrtProvider.CORE_ML,
      if (Platform.isAndroid) OrtProvider.XNNPACK,
      OrtProvider.CPU,
    ];
    OrtSession session;
    try {
      session = await _ort.createSession(
        file.path,
        options: OrtSessionOptions(providers: providers, intraOpNumThreads: 4),
      );
    } on Object {
      // Some graphs are not supported by accelerated providers; use CPU.
      session = await _ort.createSession(file.path, options: OrtSessionOptions(providers: [OrtProvider.CPU]));
    }
    return _sessions[spec.id] = session;
  }

  @override
  Future<List<num>> run(ModelSpec model, Map<String, (TypedData, List<int>)> inputs) async {
    final session = await _session(model);
    final values = <String, OrtValue>{};
    try {
      for (final e in inputs.entries) {
        values[e.key] = await OrtValue.fromList(e.value.$1, e.value.$2);
      }
      final outputs = await session.run(values);
      final out = outputs[model.outputName] ?? outputs.values.first;
      final flat = await out.asFlattenedList();
      for (final o in outputs.values) {
        await o.dispose();
      }
      return flat.cast<num>();
    } finally {
      for (final v in values.values) {
        await v.dispose();
      }
    }
  }

  @override
  Future<void> release() async {
    for (final s in _sessions.values) {
      await s.close();
    }
    _sessions.clear();
  }
}
