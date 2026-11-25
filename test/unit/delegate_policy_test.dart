import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/ai/engine/delegate_policy.dart';

bool _alwaysNpu(String? _) => true;

bool _neverNpu(String? _) => false;

void main() {
  group('normaliseSoc', () {
    test('strips vendor noise and normalises separators', () {
      expect(normaliseSoc('Qualcomm Technologies, Inc SM8550'), 'sm8550');
      expect(normaliseSoc('SM8550'), 'sm8550');
      expect(normaliseSoc('MediaTek MT6983'), 'mt6983');
      expect(normaliseSoc('Tensor G3'), 'tensor_g3');
      expect(normaliseSoc(' gs201 '), 'gs201');
    });

    test('empty or null input yields null', () {
      expect(normaliseSoc(null), isNull);
      expect(normaliseSoc(''), isNull);
      expect(normaliseSoc('   '), isNull);
    });
  });

  group('socFromCpuinfo', () {
    test('reads the Hardware line', () {
      const cpuinfo = '''
Processor       : AArch64 Processor rev 1 (aarch64)
Hardware        : Qualcomm Technologies, Inc SM8550
''';
      expect(socFromCpuinfo(cpuinfo), 'sm8550');
    });

    test('returns null without a Hardware line (newer kernels)', () {
      const cpuinfo = '''
Processor       : AArch64 Processor rev 1 (aarch64)
CPU part        : 0xc0d
''';
      expect(socFromCpuinfo(cpuinfo), isNull);
    });
  });

  group('DelegatePolicy.orderFor', () {
    const policy = DelegatePolicy();

    test('acceleration off → CPU only, always', () {
      expect(policy.orderFor(accelerated: false, android: true, apple: false, soc: 'sm8550'), [Accelerator.cpu]);
      expect(policy.orderFor(accelerated: false, android: false, apple: true), [Accelerator.cpu]);
    });

    test('allow-listed Android SoC → NPU, GPU, CPU', () {
      expect(policy.orderFor(accelerated: true, android: true, apple: false, soc: 'sm8550'), [
        Accelerator.npu,
        Accelerator.gpu,
        Accelerator.cpu,
      ]);
    });

    test('unknown Android SoC → GPU, CPU (no NPU)', () {
      expect(policy.orderFor(accelerated: true, android: true, apple: false, soc: 'mt6762'), [
        Accelerator.gpu,
        Accelerator.cpu,
      ]);
      expect(policy.orderFor(accelerated: true, android: true, apple: false), [Accelerator.gpu, Accelerator.cpu]);
    });

    test('Apple → GPU (Metal), CPU', () {
      expect(policy.orderFor(accelerated: true, android: false, apple: true), [Accelerator.gpu, Accelerator.cpu]);
    });

    test('desktop → CPU only', () {
      expect(policy.orderFor(accelerated: true, android: false, apple: false), [Accelerator.cpu]);
    });

    test('injected allow-list decision is honoured', () {
      const custom = DelegatePolicy(socHasNpu: _alwaysNpu);
      expect(custom.orderFor(accelerated: true, android: true, apple: false, soc: 'whatever'), [
        Accelerator.npu,
        Accelerator.gpu,
        Accelerator.cpu,
      ]);
      const never = DelegatePolicy(socHasNpu: _neverNpu);
      expect(never.orderFor(accelerated: true, android: true, apple: false, soc: 'sm8550'), [
        Accelerator.gpu,
        Accelerator.cpu,
      ]);
    });
  });

  group('DelegateBlacklist', () {
    test('blocks per model+accelerator, not globally', () {
      final b = DelegateBlacklist();
      expect(b.isEmpty, isTrue);
      b.block('mobilenetv2_224_q8', Accelerator.npu);
      expect(b.isBlocked('mobilenetv2_224_q8', Accelerator.npu), isTrue);
      expect(b.isBlocked('mobilenetv2_224_q8', Accelerator.gpu), isFalse);
      expect(b.isBlocked('skyseg_q8', Accelerator.npu), isFalse);
      expect(b.length, 1);
    });
  });
}
