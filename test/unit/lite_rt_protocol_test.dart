import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/ai/engine/lite_rt_protocol.dart';

void main() {
  group('TensorWire', () {
    test('decodes float32 bytes to a flat num list', () {
      final floats = Float32List.fromList([0.25, 0.5, 1.0, -2.0]);
      final wire = TensorWire.fromBytes(floats.buffer.asUint8List(), [2, 2], TensorDtype.float32);
      expect(wire.numElements, 4);
      expect(wire.decode(), [0.25, 0.5, 1.0, -2.0]);
    });

    test('decodes uint8 and int8', () {
      final u = TensorWire.fromBytes(Uint8List.fromList([0, 128, 255]), [3], TensorDtype.uint8);
      expect(u.decode(), [0, 128, 255]);
      final s = TensorWire.fromBytes(Int8List.fromList([-1, 0, 127]).buffer.asUint8List(), [3], TensorDtype.int8);
      expect(s.decode(), [-1, 0, 127]);
    });

    test('decodes int64 (ImageNet class ids)', () {
      final v = Int64List.fromList([385, 101]);
      final wire = TensorWire.fromBytes(v.buffer.asUint8List(), [2], TensorDtype.int64);
      expect(wire.decode(), [385, 101]);
    });

    test('rejects a buffer too small for its shape', () {
      final wire = TensorWire.fromBytes(Uint8List.fromList([1, 2, 3, 4]), [4, 4], TensorDtype.float32);
      expect(wire.decode, throwsArgumentError);
    });

    test('bool tensors decode to booleans', () {
      final wire = TensorWire.fromBytes(Uint8List.fromList([0, 1]), [2], TensorDtype.bool_);
      expect(wire.decode(), [0, 1]);
    });

    test('fromFloats round-trips', () {
      final wire = TensorWire.fromFloats([1.5, -0.5], [2]);
      expect(wire.dtype, TensorDtype.float32);
      expect(wire.decode(), [1.5, -0.5]);
    });
  });

  group('protocol encode/decode', () {
    test('open request round-trips', () {
      const req = LiteRtOpenRequest(path: '/models/a.tflite', accelerator: 'npu', threads: 2);
      final decoded = decodeOpenRequest(encodeOpenRequest(req));
      expect(decoded.path, req.path);
      expect(decoded.accelerator, 'npu');
      expect(decoded.threads, 2);
    });

    test('run request round-trips tensors', () {
      final req = WorkerRunRequest(
        inputs: {
          'input': TensorWire.fromFloats([0.25, 0.75], [1, 2]),
        },
      );
      final decoded = decodeRunRequest(encodeRunRequest(req));
      expect(decoded.inputs['input']!.decode(), [0.25, 0.75]);
      expect(decoded.inputs['input']!.shape, [1, 2]);
    });

    test('run result round-trips outputs and error', () {
      final result = WorkerRunResult(
        outputs: {
          'Identity': TensorWire.fromBytes(Uint8List.fromList([1, 2, 3, 4]), [1, 4], TensorDtype.uint8),
        },
        error: 'boom',
      );
      final decoded = decodeRunResult(encodeRunResult(result));
      expect(decoded.hasError, isTrue);
      expect(decoded.error, 'boom');
      expect(decoded.outputs['Identity']!.decode(), [1, 2, 3, 4]);
    });

    test('session info round-trips', () {
      const info = WorkerSessionInfo(
        accelerator: 'gpu',
        inputNames: ['serving_default_input:0'],
        inputShapes: [
          [1, 224, 224, 3],
        ],
        outputNames: ['Identity'],
        outputShapes: [
          [1, 1000],
        ],
        outputDtypes: [TensorDtype.float32],
      );
      final decoded = decodeSessionInfo(encodeSessionInfo(info));
      expect(decoded.accelerator, 'gpu');
      expect(decoded.inputNames, info.inputNames);
      expect(decoded.inputShapes, info.inputShapes);
      expect(decoded.outputNames, info.outputNames);
      expect(decoded.outputShapes, info.outputShapes);
      expect(decoded.outputDtypes, [TensorDtype.float32]);
    });

    test('unknown dtype name falls back safely', () {
      expect(TensorDtype.fromName('float16'), TensorDtype.unknown);
      expect(TensorDtype.fromName('float32'), TensorDtype.float32);
    });
  });

  group('quantisation parameters on the wire', () {
    test('uint8 probs round-trip with scale and zero point', () {
      final raw = Uint8List.fromList(List.generate(8, (i) => i * 31));
      final wire = TensorWire.fromBytes(raw, [1, 8], TensorDtype.uint8, scale: 1 / 256);
      final encoded = encodeRunResult(WorkerRunResult(outputs: {'out': wire}));
      final decoded = decodeRunResult(encoded);
      final out = decoded.outputs['out']!;
      expect(out.scale, closeTo(1 / 256, 1e-9));
      expect(out.zeroPoint, 0);
      expect(out.quantised, isTrue);
      final probs = out.dequantized();
      expect(probs.length, 8);
      expect(probs[4], closeTo((4 * 31) / 256, 1e-9));
    });

    test('float tensors are not quantised and dequantize identically', () {
      final wire = TensorWire.fromFloats([1.5, -0.5], [2]);
      expect(wire.quantised, isFalse);
      expect(wire.dequantized(), [1.5, -0.5]);
    });
  });
}
