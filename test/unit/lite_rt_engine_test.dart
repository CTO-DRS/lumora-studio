import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/ai/data/model_manager.dart';
import 'package:lumora/features/ai/data/onnx_engine.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:lumora/features/ai/engine/delegate_policy.dart';
import 'package:lumora/features/ai/engine/lite_rt_engine.dart';
import 'package:lumora/features/ai/engine/lite_rt_protocol.dart';
import 'package:lumora/features/ai/engine/lite_rt_worker.dart';

/// A fake worker bridge: configurable open failures per accelerator, fixed
/// run outputs. Records what the engine asked for.
class FakeBridge implements LiteRtWorkerBridge {
  FakeBridge({this.failOpensFor = const {}, this.outputs = const {}});

  final Set<String> failOpensFor;
  final Map<String, TensorWire> outputs;
  final List<String> opens = [];
  final List<String> runs = [];

  @override
  Future<WorkerSessionInfo> open(LiteRtOpenRequest request) async {
    opens.add(request.accelerator);
    if (failOpensFor.contains(request.accelerator)) {
      throw StateError('delegate ${request.accelerator} failed (fake)');
    }
    return WorkerSessionInfo(
      accelerator: request.accelerator,
      inputNames: ['input'],
      inputShapes: [
        [1, 4],
      ],
      outputNames: [...outputs.keys],
      outputShapes: [for (final o in outputs.values) o.shape],
      outputDtypes: [for (final o in outputs.values) o.dtype],
    );
  }

  @override
  Future<WorkerRunResult> run(WorkerRunRequest request) async {
    runs.add(request.inputs.keys.join(','));
    return WorkerRunResult(outputs: outputs);
  }

  @override
  Future<void> close() async {}
}

bool _alwaysNpu(String? soc) => true;

class _FakeBlacklistPolicy extends DelegatePolicy {
  const _FakeBlacklistPolicy() : super(socHasNpu: _alwaysNpu);

  @override
  List<Accelerator> orderFor({required bool accelerated, required bool android, required bool apple, String? soc}) =>
      accelerated ? const [Accelerator.npu, Accelerator.gpu, Accelerator.cpu] : const [Accelerator.cpu];
}

Future<ModelManager> _managerWith(ModelSpec spec) async {
  final dir = await Directory.systemTemp.createTemp('lumora-litert-test');
  final file = File('${dir.path}/models/${spec.fileName}');
  await file.create(recursive: true);
  await file.writeAsBytes(List<int>.filled(spec.sizeBytes, 0x9A));
  return ModelManager(baseDir: () async => dir);
}

ModelSpec _spec({String format = 'onnx'}) => ModelSpec(
  id: 'fake_model',
  task: AiTask.sceneClassification,
  displayName: 'Fake model',
  url: 'https://example.invalid/$format/fake_model.$format',
  sha256: '0' * 64,
  sizeBytes: 16,
  license: 'MIT',
  source: 'https://example.invalid',
  inputNames: ['input'],
  outputName: 'Identity',
  format: format,
);

Future<void> _pump(Future<void> Function() body) async => body();

void main() {
  final input = (Float32List.fromList([0.1, 0.2, 0.3, 0.4]), <int>[1, 4]);

  test('runs through the first healthy accelerator', () async {
    final spec = _spec();
    final manager = await _managerWith(spec);
    final bridge = FakeBridge(
      outputs: {
        'Identity': TensorWire.fromFloats([1, 2, 3, 4], [4]),
      },
    );
    final engine = LiteRtInferenceEngine(
      manager,
      policy: const _FakeBlacklistPolicy(),
      accelerated: () => true,
      bridgeFactory: () => bridge,
      socHint: () => 'sm8550',
    );

    final out = await engine.run(spec, {'input': input});
    expect(out, [1, 2, 3, 4]);
    // NPU first, opened successfully.
    expect(bridge.opens, ['npu']);
    expect(bridge.runs, ['input']);
    await engine.release();
  });

  test('a failing delegate is blacklisted and the next one is used', () async {
    final spec = _spec();
    final manager = await _managerWith(spec);
    final bridge = FakeBridge(
      failOpensFor: {'npu'},
      outputs: {
        'Identity': TensorWire.fromFloats([7], [1]),
      },
    );
    final engine = LiteRtInferenceEngine(
      manager,
      policy: const _FakeBlacklistPolicy(),
      accelerated: () => true,
      bridgeFactory: () => bridge,
      socHint: () => 'sm8550',
    );

    final out = await engine.run(spec, {'input': input});
    expect(out, [7]);
    expect(bridge.opens, ['npu', 'gpu'], reason: 'NPU failed once and was skipped, GPU won');
    expect(engine.blacklist.isBlocked('fake_model', Accelerator.npu), isTrue);
    await engine.release();
  });

  test('all delegates blocked → session AiException', () async {
    final spec = _spec();
    final manager = await _managerWith(spec);
    final bridge = FakeBridge(failOpensFor: {'npu', 'gpu', 'cpu'});
    final engine = LiteRtInferenceEngine(
      manager,
      policy: const _FakeBlacklistPolicy(),
      accelerated: () => true,
      bridgeFactory: () => bridge,
      socHint: () => 'sm8550',
    );

    await _pump(() async {
      await expectLater(
        engine.run(spec, {'input': input}),
        throwsA(isA<AiException>().having((e) => e.kind, 'kind', AiErrorKind.session)),
      );
    });
    expect(bridge.opens, ['npu', 'gpu', 'cpu']);
    // A second run refuses without even trying: everything is blocked.
    await _pump(() async {
      await expectLater(
        engine.run(spec, {'input': input}),
        throwsA(isA<AiException>().having((e) => e.kind, 'kind', AiErrorKind.session)),
      );
    });
    expect(bridge.opens, ['npu', 'gpu', 'cpu'], reason: 'no second open attempt after full blacklist');
    await engine.release();
  });

  test('acceleration off → CPU only', () async {
    final spec = _spec();
    final manager = await _managerWith(spec);
    final bridge = FakeBridge(
      outputs: {
        'Identity': TensorWire.fromFloats([9], [1]),
      },
    );
    final engine = LiteRtInferenceEngine(
      manager,
      accelerated: () => false,
      bridgeFactory: () => bridge,
      socHint: () => 'sm8550',
    );

    await engine.run(spec, {'input': input});
    expect(bridge.opens, ['cpu']);
    await engine.release();
  });

  test('unknown input name → input AiException', () async {
    final spec = _spec();
    final manager = await _managerWith(spec);
    final bridge = FakeBridge(
      outputs: {
        'Identity': TensorWire.fromFloats([1], [1]),
      },
    );
    final engine = LiteRtInferenceEngine(
      manager,
      accelerated: () => false,
      bridgeFactory: () => bridge,
      socHint: () => null,
    );

    await _pump(() async {
      await expectLater(
        engine.run(spec, {'wrong_name': input}),
        throwsA(isA<AiException>().having((e) => e.kind, 'kind', AiErrorKind.input)),
      );
    });
    await engine.release();
  });

  test('uint8 input travels as raw bytes (quantised graphs)', () async {
    final spec = _spec();
    final manager = await _managerWith(spec);
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    final bridge = FakeBridge(
      outputs: {
        'Identity': TensorWire.fromBytes(Uint8List.fromList([5, 6, 7, 8]), [4], TensorDtype.uint8),
      },
    );
    final engine = LiteRtInferenceEngine(
      manager,
      accelerated: () => false,
      bridgeFactory: () => bridge,
      socHint: () => null,
    );

    final out = await engine.run(spec, {
      'input': (bytes, <int>[4]),
    });
    expect(out, [5, 6, 7, 8]);
    await engine.release();
  });
}
