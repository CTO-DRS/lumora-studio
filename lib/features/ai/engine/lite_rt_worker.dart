/// LiteRT inference worker: a long-lived isolate that owns the tflite
/// interpreter so heavy `invoke()` calls never block the UI thread
/// (Wave 2 W1 — LiteRT/NPU runtime).
///
/// The plugin (tflite_flutter) is imported **only here**. The engine talks
/// to the worker through [LiteRtWorkerBridge], which is fakeable in tests.
/// Delegates are created inside the worker isolate: NPU = NNAPI (Android,
/// allow-listed SoCs only — see delegate_policy.dart), GPU = OpenGL delegate
/// (Android) or Metal delegate (iOS), CPU = default kernels + threads.
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:lumora/features/ai/engine/lite_rt_protocol.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Bridge used by the engine. Implementations: the isolate-based worker and
/// test fakes.
abstract class LiteRtWorkerBridge {
  Future<WorkerSessionInfo> open(LiteRtOpenRequest request);

  /// Throws on worker-side errors (or returns a result with [WorkerRunResult.error]).
  Future<WorkerRunResult> run(WorkerRunRequest request);

  Future<void> close();
}

/// The real bridge: spawns a worker isolate and speaks the protocol.
class LiteRtIsolateBridge implements LiteRtWorkerBridge {
  Isolate? _isolate;
  ReceivePort? _replyPort;
  SendPort? _workerPort;
  Completer<Map<Object?, Object?>>? _pending;

  Future<SendPort> _ensureWorker() async {
    final port = _workerPort;
    if (port != null) return port;
    final reply = _replyPort ??= ReceivePort();
    final isolate = await Isolate.spawn(_workerMain, reply.sendPort, debugName: 'lumora-lite-rt-worker');
    _isolate = isolate;
    final handshook = Completer<SendPort>();
    reply.listen((m) {
      if (!handshook.isCompleted && m is SendPort) {
        handshook.complete(m);
        return;
      }
      // Replies route to the outstanding call. The engine serialises its
      // queue, so at most one call is pending at a time.
      if (m is Map<Object?, Object?> && _pending != null && !_pending!.isCompleted) {
        _pending!.complete(m);
      }
    });
    return _workerPort = await handshook.future;
  }

  Future<Map<Object?, Object?>> _call(Map<String, Object?> message) async {
    final worker = await _ensureWorker();
    _pending = Completer<Map<Object?, Object?>>();
    worker.send(message);
    return _pending!.future;
  }

  @override
  Future<WorkerSessionInfo> open(LiteRtOpenRequest request) async {
    final reply = await _call({...encodeOpenRequest(request), 'reply': 'session'});
    if (reply['error'] != null) {
      throw StateError(reply['error']! as String);
    }
    return decodeSessionInfo(reply);
  }

  @override
  Future<WorkerRunResult> run(WorkerRunRequest request) async {
    final reply = await _call({...encodeRunRequest(request), 'reply': 'run'});
    return decodeRunResult(reply);
  }

  @override
  Future<void> close() async {
    final worker = _workerPort;
    _workerPort = null;
    if (worker != null) {
      try {
        worker.send(<String, Object?>{'type': 'close'});
      } on Object {
        // Worker may already be gone.
      }
    }
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _replyPort?.close();
    _replyPort = null;
    _pending = null;
  }
}

/// Worker isolate entrypoint. One interpreter at a time; the engine never
/// sends a second `open` without closing the session first.
Future<void> _workerMain(SendPort reply) async {
  final port = ReceivePort();
  reply.send(port.sendPort);

  Interpreter? interpreter;
  WorkerSessionInfo? session;

  await for (final raw in port) {
    final m = raw as Map<Object?, Object?>;
    final type = m['type'] as String?;
    switch (type) {
      case 'open':
        try {
          final req = decodeOpenRequest(m);
          interpreter?.close();
          interpreter = null;
          final options = _optionsFor(req.accelerator, req.threads);
          final file = File(req.path);
          interpreter = Interpreter.fromFile(file, options: options);
          interpreter.allocateTensors();
          session = _sessionInfo(interpreter, req.accelerator);
          reply.send(<String, Object?>{...encodeSessionInfo(session), 'error': null});
        } on Object catch (e) {
          interpreter = null;
          session = null;
          reply.send(<String, Object?>{'error': 'LiteRT open failed: $e'});
        }
      case 'run':
        if (interpreter == null || session == null) {
          reply.send(<String, Object?>{'error': 'No open LiteRT session', 'outputs': const {}});
          continue;
        }
        try {
          final req = decodeRunRequest(m);
          _writeInputs(interpreter, session, req);
          interpreter.invoke();
          reply.send(<String, Object?>{...encodeRunResult(_readOutputs(interpreter)), 'error': null});
        } on Object catch (e) {
          reply.send(<String, Object?>{'error': 'LiteRT run failed: $e', 'outputs': const {}});
        }
      case 'close':
        interpreter?.close();
        interpreter = null;
        session = null;
    }
  }
}

InterpreterOptions _optionsFor(String accelerator, int threads) {
  final options = InterpreterOptions()..threads = threads;
  switch (accelerator) {
    case 'npu':
      // Android NNAPI — the engine only asks for it on allow-listed SoCs.
      options.useNnApiForAndroid = true;
    case 'gpu':
      if (Platform.isIOS || Platform.isMacOS) {
        // Metal delegate (iOS).
        options.addDelegate(GpuDelegate());
      } else {
        // OpenGL delegate (Android).
        options.addDelegate(GpuDelegateV2());
      }
    case 'cpu':
      break; // Default kernels; threads set above.
  }
  return options;
}

WorkerSessionInfo _sessionInfo(Interpreter interpreter, String accelerator) {
  final inputs = interpreter.getInputTensors();
  final outputs = interpreter.getOutputTensors();
  return WorkerSessionInfo(
    accelerator: accelerator,
    inputNames: [for (final t in inputs) t.name],
    inputShapes: [for (final t in inputs) t.shape],
    outputNames: [for (final t in outputs) t.name],
    outputShapes: [for (final t in outputs) t.shape],
    outputDtypes: [for (final t in outputs) _dtypeOf(t)],
  );
}

void _writeInputs(Interpreter interpreter, WorkerSessionInfo session, WorkerRunRequest request) {
  final tensors = interpreter.getInputTensors();
  for (var i = 0; i < tensors.length; i++) {
    final name = session.inputNames[i];
    final wire = request.inputs[name];
    if (wire == null) {
      throw ArgumentError('Missing input "$name" for LiteRT run');
    }
    final t = tensors[i];
    if (t.numBytes() != wire.bytes.length) {
      throw ArgumentError('Input "$name": ${wire.bytes.length} bytes, graph expects ${t.numBytes()}');
    }
    t.data = wire.bytes;
  }
}

WorkerRunResult _readOutputs(Interpreter interpreter) {
  final outputs = <String, TensorWire>{};
  final tensors = interpreter.getOutputTensors();
  for (final t in tensors) {
    outputs[t.name] = TensorWire(bytes: Uint8List.fromList(t.data), shape: t.shape, dtype: _dtypeOf(t));
  }
  return WorkerRunResult(outputs: outputs);
}

TensorDtype _dtypeOf(Tensor t) {
  final type = t.type;
  switch (type) {
    case TensorType.float32:
      return TensorDtype.float32;
    case TensorType.int32:
      return TensorDtype.int32;
    case TensorType.int8:
      return TensorDtype.int8;
    case TensorType.uint8:
      return TensorDtype.uint8;
    case TensorType.int64:
      return TensorDtype.int64;
    case TensorType.boolean:
      return TensorDtype.bool_;
    default:
      return TensorDtype.unknown;
  }
}
