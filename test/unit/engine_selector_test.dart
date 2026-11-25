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
  Future<ModelSpec> specFor(ModelSpec model) async => model;

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

  EngineSelector selector(
    FakeEngine onnx,
    FakeEngine lite, {
    bool accelerated = true,
    bool accelerators = true,
    bool liteInstalled = true,
  }) => EngineSelector(
    onnx: onnx,
    liteRt: lite,
    accelerated: () => accelerated,
    hasAccelerators: () => accelerators,
    liteInstalled: (_) async => liteInstalled,
  );

  test('acceleration off → ONNX directly', () async {
    final onnx = FakeEngine('onnx');
    final lite = FakeEngine('lite');
    final s = selector(onnx, lite, accelerated: false);
    final spec = _onnxSpec(lite: _liteSpec());

    final out = await s.run(spec, inputs);
    expect(out, [1]);
    expect(onnx.calls, ['m']);
    expect(lite.calls, isEmpty);
    expect(await s.specFor(spec), same(spec));
  });

  test('no lite variant → ONNX even when accelerated', () async {
    final onnx = FakeEngine('onnx');
    final lite = FakeEngine('lite');
    final s = selector(onnx, lite);
    final spec = _onnxSpec();

    await s.run(spec, inputs);
    expect(onnx.calls, ['m']);
    expect(lite.calls, isEmpty);
  });

  test('no accelerators on device → ONNX', () async {
    final onnx = FakeEngine('onnx');
    final lite = FakeEngine('lite');
    final s = selector(onnx, lite, accelerators: false);
    final spec = _onnxSpec(lite: _liteSpec());

    await s.run(spec, inputs);
    expect(onnx.calls, ['m']);
    expect(lite.calls, isEmpty);
  });

  test('lite variant not installed → ONNX, and it never counts as a failure', () async {
    final onnx = FakeEngine('onnx');
    final lite = FakeEngine('lite');
    final s = selector(onnx, lite, liteInstalled: false);
    final spec = _onnxSpec(lite: _liteSpec());

    expect(await s.specFor(spec), same(spec), reason: 'installed gate keeps the ONNX spec');
    await s.run(spec, inputs);
    await s.run(spec, inputs);
    expect(onnx.calls, ['m', 'm']);
    expect(lite.calls, isEmpty);
    expect(s.pinnedToOnnx, isEmpty, reason: 'missing file is not a LiteRT failure');
  });

  test('accelerated + installed lite variant → LiteRT runs the tflite spec', () async {
    final onnx = FakeEngine('onnx');
    final lite = FakeEngine('lite', result: [42]);
    final s = selector(onnx, lite);
    final liteSpec = _liteSpec();
    final spec = _onnxSpec(lite: liteSpec);

    expect(s.prefersLiteRt(spec), isTrue);
    expect(await s.specFor(spec), same(liteSpec));
    final out = await s.run(spec, inputs);
    expect(out, [42]);
    expect(lite.calls, ['m']);
    expect(onnx.calls, isEmpty);
  });

  test('LiteRT failure transparently falls back to ONNX', () async {
    final onnx = FakeEngine('onnx', result: [3]);
    final lite = FakeEngine('lite', throwOnCall: true);
    final s = selector(onnx, lite);
    final spec = _onnxSpec(lite: _liteSpec());

    final out = await s.run(spec, inputs);
    expect(out, [3]);
    expect(lite.calls, ['m']);
    expect(onnx.calls, ['m']);
    expect(s.prefersLiteRt(spec), isTrue, reason: 'one failure is not a pin yet');
  });

  test('two consecutive LiteRT failures pin ONNX for the session', () async {
    final onnx = FakeEngine('onnx', result: [5]);
    final lite = FakeEngine('lite', throwOnCall: true);
    final s = selector(onnx, lite);
    final spec = _onnxSpec(lite: _liteSpec());

    await s.run(spec, inputs);
    await s.run(spec, inputs);
    expect(lite.calls, ['m', 'm'], reason: 'exactly two LiteRT attempts');
    expect(onnx.calls, ['m', 'm']);
    expect(s.pinnedToOnnx, {'m'});
    expect(s.prefersLiteRt(spec), isFalse);
    expect(await s.specFor(spec), same(spec), reason: 'pinned — specFor returns the ONNX spec');

    await s.run(spec, inputs);
    expect(lite.calls, ['m', 'm'], reason: 'pinned — no more LiteRT attempts');
    expect(onnx.calls, ['m', 'm', 'm']);
  });

  test('a LiteRT success resets the failure counter', () async {
    final onnx = FakeEngine('onnx', result: [1]);
    final lite = FakeEngine('lite', result: [2]);
    final s = selector(onnx, lite);
    final spec = _onnxSpec(lite: _liteSpec());

    await s.run(spec, inputs); // success
    expect(s.pinnedToOnnx, isEmpty);
    expect(s.prefersLiteRt(spec), isTrue);
  });
}
