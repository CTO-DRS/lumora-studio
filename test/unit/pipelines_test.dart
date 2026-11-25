import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/ai/data/onnx_engine.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';

/// Fake engine proving the pipelines' tensor contracts without native code.
class FakeEngine implements InferenceEngine {
  final calls = <(String, Map<String, List<int>>)>[];

  @override
  Future<List<num>> run(ModelSpec model, Map<String, (TypedData, List<int>)> inputs) async {
    final outputs = await runAll(model, inputs);
    return outputs[model.outputName] ?? outputs.values.first;
  }

  @override
  Future<Map<String, List<num>>> runAll(ModelSpec model, Map<String, (TypedData, List<int>)> inputs) async {
    calls.add((model.id, {for (final e in inputs.entries) e.key: e.value.$2}));
    final shape = inputs.values.first.$2;
    final n = shape.reduce((a, b) => a * b);
    return {model.outputName: Float32List(n)};
  }

  @override
  Future<ModelSpec> specFor(ModelSpec model) async => model;

  @override
  Future<void> release() async {}
}

void main() {
  test('fake engine records shapes', () async {
    final e = FakeEngine();
    await e.run(ModelRegistry.u2netp, {
      'input.1': (Float32List(3 * 320 * 320), [1, 3, 320, 320]),
    });
    expect(e.calls.single.$2['input.1'], [1, 3, 320, 320]);
  });
}
