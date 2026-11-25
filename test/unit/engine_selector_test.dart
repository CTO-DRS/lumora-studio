import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/ai/data/onnx_engine.dart' show InferenceEngine;
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:lumora/features/ai/engine/engine_selector.dart';

/// Fake engines that record which path each request took.
class FakeEngine implements InferenceEngine {
  FakeEngine(this.tag, {this.result = const [1], this.throwOnCall = false});

  final String tag;
  final List<num> result;
  final bool throwOnCall;
  final List<String> calls = [];

  @override
  Future<List<num>> run(ModelSpec model, Map<String, (TypedData, List<int>)> inputs) async {
    calls.add(model.id);
    if (throwOnCall) throw StateError('$tag failed');
    return result;
  }

  @override
  Future<Map<String, List<num>>> runAll(ModelSpec model, Map<String, (TypedData, List<int>)> inputs) async {
    calls.add(model.id);
    if (throwOnCall) throw StateError('$tag failed');
    return {model.outputName: result};
  }

  @override
  Future<void> release() async {}
}

ModelSpec _onnxSpec({ModelSpec? lite}) => ModelSpec(
  id: 'm',
  task: AiTask.sceneClassification,
  displayName: 'M',
  url: 'https://example.invalid/m.onnx',
  sha256: '0' * 64,
  sizeBytes: 8,
  license: 'MIT',
  source: 'https://example.invalid',
  inputNames: ['input'],
  outputName: 'Identity',
  lite: lite,
);

ModelSpec _liteSpec() => ModelSpec(
  id: 'm',
  task: AiTask.sceneClassification,
  displayName: 'M lite',
  url: 'https://example.invalid/m.tflite',
  sha256: '0' * 64,
  sizeBytes: 6,
  license: 'MIT',
  source: 'https://example.invalid',
  inputNames: ['input'],
  outputName: 'Identity',
  format: 'tflite',
);

void main() {
  final inputs = <String, (TypedData, List<int>)>{
    'input': (Float32List.fromList([1]), [1]),
  };

  test('acceleration off → ONNX directly', () async {
    final onnx = FakeEngine('onnx');
    final lite = FakeEngine('lite');
    final selector = EngineSelector(onnx: onnx, liteRt: lite, accelerated: () => false, hasAccelerators: () => true);
    final spec = _onnxSpec(lite: _liteSpec());

    final out = await selector.run(spec, inputs);
    expect(out, [1]);
    expect(onnx.calls, ['m']);
    expect(lite.calls, isEmpty);
  });

  test('no lite variant → ONNX even when accelerated', () async {
    final onnx = FakeEngine('onnx');
    final lite = FakeEngine('lite');
    final selector = EngineSelector(onnx: onnx, liteRt: lite, accelerated: () => true, hasAccelerators: () => true);
    final spec = _onnxSpec();

    await selector.run(spec, inputs);
    expect(onnx.calls, ['m']);
    expect(lite.calls, isEmpty);
  });

  test('no accelerators on device → ONNX', () async {
    final onnx = FakeEngine('onnx');
    final lite = FakeEngine('lite');
    final selector = EngineSelector(onnx: onnx, liteRt: lite, accelerated: () => true, hasAccelerators: () => false);
    final spec = _onnxSpec(lite: _liteSpec());

    await selector.run(spec, inputs);
    expect(onnx.calls, ['m']);
    expect(lite.calls, isEmpty);
  });

  test('accelerated + lite variant → LiteRT runs the tflite spec', () async {
    final onnx = FakeEngine('onnx');
    final lite = FakeEngine('lite', result: [42]);
    final selector = EngineSelector(onnx: onnx, liteRt: lite, accelerated: () => true, hasAccelerators: () => true);
    final liteSpec = _liteSpec();
    final spec = _onnxSpec(lite: liteSpec);

    expect(selector.prefersLiteRt(spec), isTrue);
    final out = await selector.run(spec, inputs);
    expect(out, [42]);
    expect(lite.calls, ['m']);
    expect(onnx.calls, isEmpty);
  });

  test('LiteRT failure transparently falls back to ONNX', () async {
    final onnx = FakeEngine('onnx', result: [3]);
    final lite = FakeEngine('lite', throwOnCall: true);
    final selector = EngineSelector(onnx: onnx, liteRt: lite, accelerated: () => true, hasAccelerators: () => true);
    final spec = _onnxSpec(lite: _liteSpec());

    final out = await selector.run(spec, inputs);
    expect(out, [3]);
    expect(lite.calls, ['m']);
    expect(onnx.calls, ['m']);
    expect(selector.prefersLiteRt(spec), isTrue, reason: 'one failure is not a pin yet');
  });

  test('two consecutive LiteRT failures pin ONNX for the session', () async {
    final onnx = FakeEngine('onnx', result: [5]);
    final lite = FakeEngine('lite', throwOnCall: true);
    final selector = EngineSelector(onnx: onnx, liteRt: lite, accelerated: () => true, hasAccelerators: () => true);
    final spec = _onnxSpec(lite: _liteSpec());

    await selector.run(spec, inputs);
    await selector.run(spec, inputs);
    expect(lite.calls, ['m', 'm'], reason: 'exactly two LiteRT attempts');
    expect(onnx.calls, ['m', 'm']);
    expect(selector.pinnedToOnnx, {'m'});
    expect(selector.prefersLiteRt(spec), isFalse);

    await selector.run(spec, inputs);
    expect(lite.calls, ['m', 'm'], reason: 'pinned — no more LiteRT attempts');
    expect(onnx.calls, ['m', 'm', 'm']);
  });

  test('a LiteRT success resets the failure counter', () async {
    final onnx = FakeEngine('onnx', result: [1]);
    final lite = FakeEngine('lite', result: [2]);
    final selector = EngineSelector(onnx: onnx, liteRt: lite, accelerated: () => true, hasAccelerators: () => true);
    final spec = _onnxSpec(lite: _liteSpec());

    await selector.run(spec, inputs); // success
    expect(selector.pinnedToOnnx, isEmpty);
    expect(selector.prefersLiteRt(spec), isTrue);
  });
}
