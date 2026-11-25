/// Wire types exchanged between the LiteRT engine (main isolate) and the
/// inference worker isolate. Pure Dart on purpose: the engine must never
/// import the native plugin, so it stays unit-testable with a fake bridge.
library;

import 'dart:typed_data';

/// Data type of a tensor byte buffer on the wire.
enum TensorDtype {
  float32,
  int32,
  int8,
  uint8,
  int64,
  bool_,

  /// Unknown dtype — the engine falls back to zeroed values.
  unknown;

  static TensorDtype fromName(String name) =>
      TensorDtype.values.firstWhere((d) => d.name == name, orElse: () => TensorDtype.unknown);
}

/// A raw tensor travelling between isolates: bytes + shape + dtype, plus
/// the quantisation parameters the graph declares for it (1/0 for float
/// tensors — the identity dequantisation).
class TensorWire {
  const TensorWire({
    required this.bytes,
    required this.shape,
    required this.dtype,
    this.scale = 1.0,
    this.zeroPoint = 0,
  });

  final Uint8List bytes;
  final List<int> shape;
  final TensorDtype dtype;

  /// Quantisation scale (quantised graphs only; float tensors ship 1.0).
  final double scale;

  /// Quantisation zero point (quantised graphs only; float tensors ship 0).
  final int zeroPoint;

  bool get quantised => scale > 0 && (scale != 1.0 || zeroPoint != 0);

  int get numElements => shape.fold(1, (a, b) => a * b);

  /// Flattens the buffer into a `List<num>` (the `InferenceEngine` contract).
  List<num> decode() {
    final n = numElements;
    switch (dtype) {
      case TensorDtype.float32:
        _checkSize(n, 4);
        return bytes.buffer.asFloat32List(bytes.offsetInBytes, n).toList();
      case TensorDtype.int32:
        _checkSize(n, 4);
        return bytes.buffer.asInt32List(bytes.offsetInBytes, n).toList();
      case TensorDtype.int8:
        _checkSize(n, 1);
        return bytes.buffer.asInt8List(bytes.offsetInBytes, n).toList();
      case TensorDtype.uint8:
        _checkSize(n, 1);
        return bytes.sublist(0, n).toList();
      case TensorDtype.int64:
        _checkSize(n, 8);
        return bytes.buffer.asInt64List(bytes.offsetInBytes, n).toList();
      case TensorDtype.bool_:
        _checkSize(n, 1);
        return bytes.sublist(0, n).map((b) => b != 0 ? 1 : 0).toList();
      case TensorDtype.unknown:
        return List<num>.filled(n, 0);
    }
  }

  /// Dequantised view: `value * scale + zeroPoint`. Identity for float
  /// tensors (scale 1, zero point 0).
  List<double> dequantized() => [for (final v in decode()) v * scale + zeroPoint];

  /// Encodes a flat list of numbers as float32 bytes (the common input case
  /// for our graphs; int/uint inputs are passed as typed lists by the
  /// pipelines and never need re-encoding).
  static TensorWire fromFloats(List<num> values, List<int> shape) {
    final f = Float32List(values.length);
    for (var i = 0; i < values.length; i++) {
      f[i] = values[i].toDouble();
    }
    return TensorWire(bytes: _bytesOf(f), shape: shape, dtype: TensorDtype.float32);
  }

  static TensorWire fromBytes(
    Uint8List bytes,
    List<int> shape,
    TensorDtype dtype, {
    double scale = 1.0,
    int zeroPoint = 0,
  }) => TensorWire(bytes: bytes, shape: shape, dtype: dtype, scale: scale, zeroPoint: zeroPoint);

  /// Verifies the raw bytes hold at least [n] elements of [elementSize] bytes.
  void _checkSize(int n, int elementSize) {
    if (bytes.length < n * elementSize) {
      throw ArgumentError('Buffer ${bytes.length} B too small for $n elements');
    }
  }
}

Uint8List _bytesOf(TypedData t) {
  if (t is Uint8List) return t;
  final b = ByteData.sublistView(t);
  return b.buffer.asUint8List(b.offsetInBytes, b.lengthInBytes);
}

/// `open` request for the worker isolate.
class LiteRtOpenRequest {
  const LiteRtOpenRequest({required this.path, required this.accelerator, required this.threads});

  final String path;

  /// `Accelerator.name` (npu / gpu / cpu) — a String so the protocol stays
  /// dependency-free.
  final String accelerator;
  final int threads;
}

/// `open` reply: session metadata the engine needs to map names to indices.
class WorkerSessionInfo {
  const WorkerSessionInfo({
    required this.accelerator,
    required this.inputNames,
    required this.inputShapes,
    required this.outputNames,
    required this.outputShapes,
    required this.outputDtypes,
  });

  final String accelerator;
  final List<String> inputNames;
  final List<List<int>> inputShapes;
  final List<String> outputNames;
  final List<List<int>> outputShapes;
  final List<TensorDtype> outputDtypes;
}

/// `run` request: one raw buffer per named input.
class WorkerRunRequest {
  const WorkerRunRequest({required this.inputs});

  /// name → (bytes, shape); dtype is validated against the graph by the
  /// worker.
  final Map<String, TensorWire> inputs;
}

/// `run` reply: one raw buffer per named output.
class WorkerRunResult {
  const WorkerRunResult({required this.outputs, this.error});

  final Map<String, TensorWire> outputs;

  /// Worker-side failure (invoke failed, shape mismatch, …).
  final String? error;

  bool get hasError => error != null && error!.isNotEmpty;
}

/// Map → wire helpers (isolates send plain objects; explicit encode/decode
/// pairs keep the protocol debuggable and versioned in one place).
Map<String, Object?> encodeOpenRequest(LiteRtOpenRequest r) => <String, Object?>{
  'type': 'open',
  'path': r.path,
  'accelerator': r.accelerator,
  'threads': r.threads,
};

LiteRtOpenRequest decodeOpenRequest(Map<Object?, Object?> m) => LiteRtOpenRequest(
  path: m['path']! as String,
  accelerator: m['accelerator']! as String,
  threads: m['threads']! as int,
);

Map<String, Object?> encodeRunRequest(WorkerRunRequest r) => <String, Object?>{
  'type': 'run',
  'inputs': <String, Map<String, Object?>>{
    for (final e in r.inputs.entries)
      e.key: <String, Object?>{
        'bytes': e.value.bytes,
        'shape': e.value.shape,
        'dtype': e.value.dtype.name,
        'scale': e.value.scale,
        'zeroPoint': e.value.zeroPoint,
      },
  },
};

WorkerRunRequest decodeRunRequest(Map<Object?, Object?> m) => WorkerRunRequest(
  inputs: <String, TensorWire>{
    for (final e in (m['inputs']! as Map<Object?, Object?>).entries)
      e.key! as String: _decodeTensor(e.value! as Map<Object?, Object?>),
  },
);

Map<String, Object?> encodeRunResult(WorkerRunResult r) => <String, Object?>{
  'type': 'run-result',
  'error': r.error,
  'outputs': <String, Map<String, Object?>>{
    for (final e in r.outputs.entries)
      e.key: <String, Object?>{
        'bytes': e.value.bytes,
        'shape': e.value.shape,
        'dtype': e.value.dtype.name,
        'scale': e.value.scale,
        'zeroPoint': e.value.zeroPoint,
      },
  },
};

WorkerRunResult decodeRunResult(Map<Object?, Object?> m) {
  final outputs = <String, TensorWire>{};
  final raw = m['outputs'] as Map<Object?, Object?>? ?? const {};
  for (final e in raw.entries) {
    outputs[e.key! as String] = _decodeTensor(e.value! as Map<Object?, Object?>);
  }
  return WorkerRunResult(outputs: outputs, error: m['error'] as String?);
}

WorkerSessionInfo decodeSessionInfo(Map<Object?, Object?> m) {
  final inputNames = (m['inputNames']! as List<Object?>).cast<String>();
  final inputShapes = (m['inputShapes']! as List<Object?>).cast<List<Object?>>();
  final outputNames = (m['outputNames']! as List<Object?>).cast<String>();
  final outputShapes = (m['outputShapes']! as List<Object?>).cast<List<Object?>>();
  final outputDtypes = (m['outputDtypes']! as List<Object?>).cast<String>();
  return WorkerSessionInfo(
    accelerator: m['accelerator']! as String,
    inputNames: List<String>.from(inputNames),
    inputShapes: [for (final s in inputShapes) List<int>.from(s)],
    outputNames: List<String>.from(outputNames),
    outputShapes: [for (final s in outputShapes) List<int>.from(s)],
    outputDtypes: [for (final d in outputDtypes) TensorDtype.fromName(d)],
  );
}

Map<String, Object?> encodeSessionInfo(WorkerSessionInfo i) => <String, Object?>{
  'accelerator': i.accelerator,
  'inputNames': i.inputNames,
  'inputShapes': i.inputShapes,
  'outputNames': i.outputNames,
  'outputShapes': i.outputShapes,
  'outputDtypes': [for (final d in i.outputDtypes) d.name],
};

TensorWire _decodeTensor(Map<Object?, Object?> m) => TensorWire(
  bytes: m['bytes']! as Uint8List,
  shape: List<int>.from(m['shape']! as List<Object?>),
  dtype: TensorDtype.fromName(m['dtype']! as String),
  scale: (m['scale'] as num?)?.toDouble() ?? 1.0,
  zeroPoint: (m['zeroPoint'] as num?)?.toInt() ?? 0,
);
