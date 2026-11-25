/// LiteRT (TensorFlow Lite) inference engine — Wave 2 W1 "LiteRT/NPU
/// runtime".
///
/// Implements the same `InferenceEngine` contract as [OnnxInferenceEngine]
/// so pipelines stay unchanged:
///
/// * **Delegate ladder** — NPU (Android NNAPI, allow-listed SoCs only) →
///   GPU (OpenGL / Metal) → CPU kernels, ordered by [DelegatePolicy] and
///   filtered through a per-session [DelegateBlacklist]: a delegate that
///   fails once for a model is never retried while the app lives.
/// * **UI never blocks** — the interpreter lives in a worker isolate
///   ([LiteRtIsolateBridge]); tensors travel as raw byte buffers
///   ([TensorWire]).
/// * **One session at a time** — like the ONNX engine, models load on
///   demand and the previous session is closed first, so peak memory keeps
///   its budget.
/// * Every step leaves a breadcrumb in [CrashLog] so a native crash can be
///   attributed on-device.
library;

import 'dart:async';
import 'dart:io' show File, Platform;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumora/core/diagnostics/crash_log.dart';
import 'package:lumora/features/ai/data/model_manager.dart';
import 'package:lumora/features/ai/data/onnx_engine.dart'
    show AiErrorKind, AiException, InferenceEngine, describeNativeError;
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:lumora/features/ai/engine/delegate_policy.dart';
import 'package:lumora/features/ai/engine/lite_rt_protocol.dart';
import 'package:lumora/features/ai/engine/lite_rt_worker.dart';

class LiteRtInferenceEngine implements InferenceEngine {
  LiteRtInferenceEngine(
    this._models, {
    this.policy = const DelegatePolicy(),
    DelegateBlacklist? blacklist,
    this.bridgeFactory = LiteRtIsolateBridge.new,
    bool Function()? accelerated,
    String? Function()? socHint,
  }) : _blacklist = blacklist ?? DelegateBlacklist(),
       _accelerated = accelerated ?? _noAcceleration,
       _socHint = socHint ?? _defaultSocHint;

  final ModelManager _models;
  final DelegatePolicy policy;
  final DelegateBlacklist _blacklist;
  final LiteRtWorkerBridge Function() bridgeFactory;
  final bool Function() _accelerated;
  final String? Function() _socHint;

  LiteRtWorkerBridge? _bridge;
  WorkerSessionInfo? _session;
  String? _sessionModelId;
  Future<void> _queue = Future.value();

  static bool _noAcceleration() => false;

  /// Best-effort SoC hint (null off Android or when the kernel does not
  /// expose the hardware line).
  static String? _defaultSocHint() {
    if (!Platform.isAndroid) return null;
    try {
      return socFromCpuinfo(File('/proc/cpuinfo').readAsStringSync());
    } on Object {
      return null;
    }
  }

  /// Delegates blocked this session (for diagnostics).
  DelegateBlacklist get blacklist => _blacklist;

  Future<WorkerSessionInfo> _sessionFor(ModelSpec spec) async {
    final existing = _session;
    if (existing != null && _sessionModelId == spec.id) return existing;
    await _closeSession();

    final file = await _ensureFile(spec);

    final soc = _socHint();
    final order = policy
        .orderFor(
          accelerated: _accelerated(),
          android: Platform.isAndroid,
          apple: Platform.isIOS || Platform.isMacOS,
          soc: soc,
        )
        .where((a) => !_blacklist.isBlocked(spec.id, a))
        .toList();
    if (order.isEmpty) {
      throw AiException(
        AiErrorKind.session,
        model: spec,
        detail: 'all LiteRT delegates blocked for ${spec.id} this session',
      );
    }

    final threads = math.max(1, math.min(4, Platform.numberOfProcessors ~/ 2));
    Object? lastError;
    for (final accelerator in order) {
      CrashLog.instance.breadcrumb(
        'AI: LiteRT loading ${spec.id} (${spec.sizeMb.toStringAsFixed(1)} MB, '
        '${accelerator.label}${soc == null ? '' : ', SoC $soc'}, threads $threads)',
      );
      try {
        final bridge = _bridge ??= bridgeFactory();
        final info = await bridge.open(
          LiteRtOpenRequest(path: file.path, accelerator: accelerator.name, threads: threads),
        );
        CrashLog.instance.breadcrumb('AI: LiteRT session ${spec.id} ready on ${info.accelerator}');
        _sessionModelId = spec.id;
        return _session = info;
      } on Object catch (e) {
        lastError = e;
        _blacklist.block(spec.id, accelerator);
        CrashLog.instance.breadcrumb(
          'AI: LiteRT ${accelerator.label} failed for ${spec.id} '
          '(${describeNativeError(e)}) — blacklisted for this session',
        );
      }
    }
    throw AiException(
      AiErrorKind.session,
      model: spec,
      detail: describeNativeError(lastError ?? StateError('no accelerator tried')),
    );
  }

  Future<File> _ensureFile(ModelSpec spec) async {
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
    return file;
  }

  Future<T> _serialized<T>(Future<T> Function() job) {
    final result = _queue.then((_) => job());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  @override
  Future<List<num>> run(ModelSpec model, Map<String, (TypedData, List<int>)> inputs) async {
    final outputs = await runAll(model, inputs);
    final out = outputs[model.outputName] ?? outputs.values.first;
    return out;
  }

  @override
  Future<Map<String, List<num>>> runAll(ModelSpec model, Map<String, (TypedData, List<int>)> inputs) =>
      _serialized(() => _runAll(model, inputs));

  Future<Map<String, List<num>>> _runAll(ModelSpec model, Map<String, (TypedData, List<int>)> inputs) async {
    final session = await _sessionFor(model);
    final bridge = _bridge!;
    CrashLog.instance.breadcrumb('AI: LiteRT run ${model.id} inputs ${inputs.keys.toList()}');

    final wires = <String, TensorWire>{};
    try {
      for (final e in inputs.entries) {
        final name = e.key;
        if (!session.inputNames.contains(name)) {
          throw AiException(
            AiErrorKind.input,
            model: model,
            detail: 'LiteRT graph has no input "$name" (has ${session.inputNames})',
          );
        }
        final (data, shape) = e.value;
        wires[name] = _toWire(data, shape);
      }
      final result = await bridge.run(WorkerRunRequest(inputs: wires));
      if (result.hasError) {
        throw StateError(result.error!);
      }
      final flat = <String, List<num>>{};
      for (final e in result.outputs.entries) {
        flat[e.key] = e.value.decode();
      }
      final main = flat[model.outputName] ?? flat.values.first;
      CrashLog.instance.breadcrumb('AI: LiteRT run ${model.id} done (${main.length} values)');
      return flat;
    } on AiException {
      rethrow;
    } on Object catch (e) {
      final detail = describeNativeError(e);
      final oom = e is OutOfMemoryError || detail.contains('OutOfMemory') || detail.toLowerCase().contains('bad_alloc');
      throw AiException(oom ? AiErrorKind.memory : AiErrorKind.inference, model: model, detail: detail);
    }
  }

  TensorWire _toWire(TypedData data, List<int> shape) {
    final bytes = _bytesOf(data);
    final dtype = switch (data) {
      Float32List() => TensorDtype.float32,
      Int32List() => TensorDtype.int32,
      Int8List() => TensorDtype.int8,
      Uint8List() => TensorDtype.uint8,
      Int64List() => TensorDtype.int64,
      _ => TensorDtype.unknown,
    };
    return TensorWire.fromBytes(bytes, shape, dtype);
  }

  static Uint8List _bytesOf(TypedData t) {
    if (t is Uint8List) return t;
    final b = ByteData.sublistView(t);
    return b.buffer.asUint8List(b.offsetInBytes, b.lengthInBytes);
  }

  Future<void> _closeSession() async {
    _session = null;
    _sessionModelId = null;
    final b = _bridge;
    if (b == null) return;
    try {
      await b.close();
    } on Object catch (e) {
      CrashLog.instance.breadcrumb('AI: LiteRT bridge close failed: ${describeNativeError(e)}');
    }
    _bridge = null;
  }

  @override
  Future<void> release() => _serialized(_closeSession);
}
