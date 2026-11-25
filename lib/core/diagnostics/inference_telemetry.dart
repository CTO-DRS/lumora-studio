/// Local-only inference latency and memory telemetry (Wave 2 W1).
///
/// Every model run is timed and recorded in a bounded in-memory ring; the
/// summary is appended to the error-log export (Settings), so the user can
/// see and share which engine ran which model and how fast. Nothing is
/// uploaded, nothing is written to disk.
library;

import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:lumora/features/ai/data/onnx_engine.dart' show InferenceEngine;
import 'package:lumora/features/ai/domain/model_registry.dart';

/// One timed model run.
class InferenceRecord {
  const InferenceRecord({
    required this.modelId,
    required this.format,
    required this.latencyMs,
    required this.ok,
    required this.at,
    this.rssMb,
  });

  final String modelId;

  /// `onnx` or `tflite`: the format of the graph that actually ran.
  final String format;
  final int latencyMs;
  final bool ok;
  final DateTime at;

  /// Process resident memory after the run, MB (null where unavailable).
  final int? rssMb;
}

class InferenceTelemetry {
  InferenceTelemetry({this.capacity = 200});

  static final InferenceTelemetry instance = InferenceTelemetry();

  final int capacity;
  final ListQueue<InferenceRecord> _records = ListQueue();

  List<InferenceRecord> get records => List.unmodifiable(_records);

  void record(InferenceRecord r) {
    _records.addLast(r);
    while (_records.length > capacity) {
      _records.removeFirst();
    }
  }

  void clear() => _records.clear();

  /// Plain-text summary grouped by model and format: runs, failures, mean,
  /// median, worst latency and peak resident memory. Empty when nothing ran.
  String report() {
    if (_records.isEmpty) return '';
    final groups = <String, List<InferenceRecord>>{};
    for (final r in _records) {
      (groups['${r.modelId} [${r.format}]'] ??= []).add(r);
    }
    final keys = groups.keys.toList()..sort();
    final b = StringBuffer('--- Inference telemetry (this session, local only) ---\n');
    for (final k in keys) {
      final rs = groups[k]!;
      final lat = [for (final r in rs.where((r) => r.ok)) r.latencyMs]..sort();
      final fails = rs.where((r) => !r.ok).length;
      final mean = lat.isEmpty ? 0 : (lat.reduce((a, c) => a + c) / lat.length).round();
      final median = lat.isEmpty ? 0 : lat[lat.length ~/ 2];
      final worst = lat.isEmpty ? 0 : lat.last;
      final rss = rs.map((r) => r.rssMb ?? 0).fold<int>(0, (a, c) => c > a ? c : a);
      b.writeln(
        '$k  runs=${rs.length} fail=$fails mean=${mean}ms median=${median}ms max=${worst}ms'
        '${rss > 0 ? ' peakRSS=${rss}MB' : ''}',
      );
    }
    return b.toString();
  }
}

/// Wraps an engine and records every run. Behaviour is otherwise unchanged:
/// results and errors pass straight through.
class TelemetryInferenceEngine implements InferenceEngine {
  TelemetryInferenceEngine(this.inner, {InferenceTelemetry? telemetry, int? Function()? rss})
    : _telemetry = telemetry ?? InferenceTelemetry.instance,
      _rss = rss ?? _processRssMb;

  final InferenceEngine inner;
  final InferenceTelemetry _telemetry;
  final int? Function() _rss;

  static int? _processRssMb() {
    try {
      return ProcessInfo.currentRss ~/ (1024 * 1024);
    } on Object {
      return null;
    }
  }

  Future<T> _timed<T>(ModelSpec model, Future<T> Function() body) async {
    final spec = await inner.specFor(model);
    final sw = Stopwatch()..start();
    var ok = false;
    try {
      final out = await body();
      ok = true;
      return out;
    } finally {
      sw.stop();
      _telemetry.record(
        InferenceRecord(
          modelId: model.id,
          format: spec.format,
          latencyMs: sw.elapsedMilliseconds,
          ok: ok,
          at: DateTime.now(),
          rssMb: _rss(),
        ),
      );
    }
  }

  @override
  Future<List<num>> run(ModelSpec model, Map<String, (TypedData, List<int>)> inputs) =>
      _timed(model, () => inner.run(model, inputs));

  @override
  Future<Map<String, List<num>>> runAll(ModelSpec model, Map<String, (TypedData, List<int>)> inputs) =>
      _timed(model, () => inner.runAll(model, inputs));

  @override
  Future<ModelSpec> specFor(ModelSpec model) => inner.specFor(model);

  @override
  Future<void> release() => inner.release();
}
