import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'package:lumora/core/diagnostics/crash_log.dart';
import 'package:lumora/features/ai/data/model_manager.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';

/// Abstraction over the inference runtime so pipelines can be unit tested
/// with a fake and the runtime can be swapped (e.g. LiteRT) later.
abstract class InferenceEngine {
  /// Runs [model] with named inputs. Each input is a typed list
  /// ([Float32List] or [Uint8List]) and its shape. Returns the flat values of
  /// [ModelSpec.outputName].
  Future<List<num>> run(ModelSpec model, Map<String, (TypedData, List<int>)> inputs);

  /// Runs [model] and returns the flat values of the named outputs (the
  /// spec's own output when [outputs] is omitted). Used by graphs that emit
  /// several tensors (e.g. the SAM decoder's masks + IoU predictions).
  Future<Map<String, List<num>>> runNamed(
    ModelSpec model,
    Map<String, (TypedData, List<int>)> inputs, {
    Set<String> outputs = const {},
  });

  Future<void> release();
}

/// Which step of an AI tool failed.
enum AiErrorKind {
  /// The model could not be downloaded (network, HTTP error, disk).
  download,

  /// The downloaded file does not match its SHA-256.
  checksum,

  /// The model is not on the device yet (and was not downloaded).
  notDownloaded,

  /// ONNX Runtime could not load the model.
  session,

  /// Inference itself failed.
  inference,

  /// Not enough memory for this image/model.
  memory,

  /// The photo could not be read.
  input,
}

/// A failure of an AI tool with a kind the UI can explain in plain words.
class AiException implements Exception {
  const AiException(this.kind, {this.model, this.detail});

  final AiErrorKind kind;
  final ModelSpec? model;

  /// Technical detail (kept for the error log / "details" text).
  final String? detail;

  @override
  String toString() => 'AiException(${kind.name}${model == null ? '' : ', ${model!.id}'}): ${detail ?? ''}';
}

/// Converts any error thrown by a platform channel / runtime into a short
/// technical string.
String describeNativeError(Object e) {
  if (e is PlatformException) {
    return '${e.code}: ${e.message ?? ''}';
  }
  return '$e';
}

/// Session options used for every model.
///
/// The safe default is **CPU only** with KleidiAI disabled: the XNNPACK
/// execution provider and KleidiAI kernels are faster on many phones but have
/// caused native crashes / unbounded memory growth on some devices and
/// graphs, and a native abort cannot be caught from Dart. [accelerated]
/// (Settings → "AI acceleration") opts back in.
OrtSessionOptions sessionOptionsFor({
  required bool accelerated,
  required bool android,
  required bool apple,
  required int cores,
}) {
  // Leave cores for the UI and the OS; ORT's default (all cores) makes
  // low-end phones stutter and some vendors' thermal governors kill the app.
  final threads = math.max(1, math.min(4, cores ~/ 2));
  if (!accelerated) {
    return OrtSessionOptions(
      providers: const [OrtProvider.CPU],
      intraOpNumThreads: threads,
      interOpNumThreads: 1,
      sessionConfigs: const {'mlas.disable_kleidiai': '1'},
    );
  }
  return OrtSessionOptions(
    providers: [if (apple) OrtProvider.CORE_ML, if (android) OrtProvider.XNNPACK, OrtProvider.CPU],
    // XNNPACK uses its own thread pool; ORT recommends 1 intra-op thread with it.
    intraOpNumThreads: android ? 1 : threads,
    interOpNumThreads: 1,
  );
}

/// ONNX Runtime implementation (flutter_onnxruntime).
///
/// * CPU by default; XNNPACK / Core ML only when [accelerated] returns true.
/// * Only **one** session is kept in memory: models are loaded on demand and
///   the previous one is closed first, so a photo session never holds the
///   segmentation, matting, eraser and upscaler graphs at the same time.
/// * Runs are serialized (the plugin is not re-entrant per session).
/// * Every step leaves a breadcrumb in [CrashLog], so a native crash can be
///   attributed on-device.
class OnnxInferenceEngine implements InferenceEngine {
  OnnxInferenceEngine(this._models, {bool Function()? accelerated}) : _accelerated = accelerated ?? (() => false);

  final ModelManager _models;
  final bool Function() _accelerated;
  OnnxRuntime? _ort;
  String? _sessionModelId;
  OrtSession? _session;
  Future<void> _queue = Future.value();

  OnnxRuntime get _runtime => _ort ??= OnnxRuntime();

  Future<OrtSession> _sessionFor(ModelSpec spec) async {
    final existing = _session;
    if (existing != null && _sessionModelId == spec.id) return existing;
    await _closeSession();

    if (!await _models.isInstalled(spec)) {
      throw AiException(AiErrorKind.notDownloaded, model: spec);
    }
    final File file;
    try {
      file = await _models.ensure(spec);
    } on ModelChecksumException catch (e) {
      throw AiException(AiErrorKind.checksum, model: spec, detail: '$e');
    } on Object catch (e) {
      throw AiException(AiErrorKind.download, model: spec, detail: describeNativeError(e));
    }

    final accelerated = _accelerated();
    final options = sessionOptionsFor(
      accelerated: accelerated,
      android: Platform.isAndroid,
      apple: Platform.isIOS || Platform.isMacOS,
      cores: Platform.numberOfProcessors,
    );
    CrashLog.instance.breadcrumb(
      'AI: loading ${spec.id} (${spec.sizeMb.toStringAsFixed(1)} MB, '
      '${accelerated ? 'accelerated' : 'cpu'}, threads ${options.intraOpNumThreads})',
    );
    OrtSession session;
    try {
      session = await _runtime.createSession(file.path, options: options);
    } on Object catch (e) {
      if (!accelerated) {
        throw AiException(AiErrorKind.session, model: spec, detail: describeNativeError(e));
      }
      // Some graphs are not supported by accelerated providers; use CPU.
      CrashLog.instance.breadcrumb('AI: accelerated session failed (${describeNativeError(e)}), retrying on CPU');
      try {
        session = await _runtime.createSession(
          file.path,
          options: sessionOptionsFor(
            accelerated: false,
            android: false,
            apple: false,
            cores: Platform.numberOfProcessors,
          ),
        );
      } on Object catch (e2) {
        throw AiException(AiErrorKind.session, model: spec, detail: describeNativeError(e2));
      }
    }
    _sessionModelId = spec.id;
    return _session = session;
  }

  Future<T> _serialized<T>(Future<T> Function() job) {
    final result = _queue.then((_) => job());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  @override
  Future<List<num>> run(ModelSpec model, Map<String, (TypedData, List<int>)> inputs) async {
    final out = await runNamed(model, inputs);
    return out[model.outputName] ?? out.values.first;
  }

  @override
  Future<Map<String, List<num>>> runNamed(
    ModelSpec model,
    Map<String, (TypedData, List<int>)> inputs, {
    Set<String> outputs = const {},
  }) => _serialized(() => _run(model, inputs, outputs));

  Future<Map<String, List<num>>> _run(
    ModelSpec model,
    Map<String, (TypedData, List<int>)> inputs,
    Set<String> outputs,
  ) async {
    final session = await _sessionFor(model);
    final shapes = {for (final e in inputs.entries) e.key: e.value.$2};
    CrashLog.instance.breadcrumb('AI: run ${model.id} inputs $shapes');
    final wanted = outputs.isEmpty ? {model.outputName} : outputs;
    final values = <String, OrtValue>{};
    Map<String, OrtValue>? runOutputs;
    try {
      for (final e in inputs.entries) {
        values[e.key] = await OrtValue.fromList(e.value.$1, e.value.$2);
      }
      runOutputs = await session.run(values);
      final result = <String, List<num>>{};
      for (final name in wanted) {
        final out = runOutputs[name] ?? (name == model.outputName ? runOutputs.values.firstOrNull : null);
        if (out == null) {
          throw AiException(AiErrorKind.inference, model: model, detail: 'missing output $name');
        }
        final flat = await out.asFlattenedList();
        result[name] = flat.cast<num>();
      }
      CrashLog.instance.breadcrumb('AI: run ${model.id} done (${result.values.first.length} values)');
      return result;
    } on AiException {
      rethrow;
    } on Object catch (e) {
      final detail = describeNativeError(e);
      final oom = e is OutOfMemoryError || detail.contains('OutOfMemory') || detail.toLowerCase().contains('bad_alloc');
      throw AiException(oom ? AiErrorKind.memory : AiErrorKind.inference, model: model, detail: detail);
    } finally {
      // Outputs first (they may reference session memory), then inputs.
      for (final o in runOutputs?.values ?? const <OrtValue>[]) {
        await _safeDispose(o);
      }
      for (final v in values.values) {
        await _safeDispose(v);
      }
    }
  }

  static Future<void> _safeDispose(OrtValue v) async {
    try {
      await v.dispose();
    } on Object catch (_) {
      // Already released.
    }
  }

  Future<void> _closeSession() async {
    final s = _session;
    _session = null;
    _sessionModelId = null;
    if (s == null) return;
    try {
      await s.close();
    } on Object catch (e) {
      CrashLog.instance.breadcrumb('AI: closing session failed: ${describeNativeError(e)}');
    }
  }

  @override
  Future<void> release() => _serialized(_closeSession);
}
