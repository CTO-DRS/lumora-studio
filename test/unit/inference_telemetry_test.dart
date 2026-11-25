import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/core/diagnostics/inference_telemetry.dart';
import 'package:lumora/features/ai/data/onnx_engine.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';

class _Engine implements InferenceEngine {
  _Engine({this.fail = false});
  final bool fail;

  @override
  Future<List<num>> run(ModelSpec model, Map<String, (TypedData, List<int>)> inputs) async {
    if (fail) throw StateError('boom');
    return const [1, 2];
  }

  @override
  Future<Map<String, List<num>>> runAll(ModelSpec model, Map<String, (TypedData, List<int>)> inputs) async => {
    model.outputName: const [1],
  };

  @override
  Future<ModelSpec> specFor(ModelSpec model) async => model;

  @override
  Future<void> release() async {}
}

void main() {
  final model = ModelRegistry.all.first;

  test('records a run with format and memory, results pass through', () async {
    final t = InferenceTelemetry();
    final e = TelemetryInferenceEngine(_Engine(), telemetry: t, rss: () => 321);
    expect(await e.run(model, const {}), [1, 2]);
    expect(t.records.single.modelId, model.id);
    expect(t.records.single.ok, isTrue);
    expect(t.records.single.rssMb, 321);
    expect(t.report(), contains(model.id));
    expect(t.report(), contains('peakRSS=321MB'));
  });

  test('failures are recorded and rethrown', () async {
    final t = InferenceTelemetry();
    final e = TelemetryInferenceEngine(_Engine(fail: true), telemetry: t, rss: () => null);
    await expectLater(e.run(model, const {}), throwsStateError);
    expect(t.records.single.ok, isFalse);
    expect(t.report(), contains('fail=1'));
  });

  test('ring is bounded and report is empty with no runs', () {
    final t = InferenceTelemetry(capacity: 3);
    expect(t.report(), isEmpty);
    for (var i = 0; i < 10; i++) {
      t.record(InferenceRecord(modelId: 'm', format: 'onnx', latencyMs: i, ok: true, at: DateTime(2026)));
    }
    expect(t.records.length, 3);
    expect(t.records.first.latencyMs, 7);
    expect(t.report(), contains('median=8ms'));
    t.clear();
    expect(t.records, isEmpty);
  });
}
