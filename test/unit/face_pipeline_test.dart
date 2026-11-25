import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/ai/data/onnx_engine.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:lumora/features/ai/pipelines/face_pipeline.dart';
import 'package:lumora/features/ai/pipelines/tensor_utils.dart';

/// Fake engine that answers each model with caller-provided named outputs,
/// recording the input shapes it was called with.
class ScriptedEngine implements InferenceEngine {
  ScriptedEngine(this.responses);

  final Map<String, Map<String, List<num>>> responses;
  final calls = <(String, Map<String, List<int>>)>[];

  @override
  Future<List<num>> run(ModelSpec model, Map<String, (TypedData, List<int>)> inputs) async {
    final out = await runNamed(model, inputs);
    return out.values.first;
  }

  @override
  Future<Map<String, List<num>>> runNamed(
    ModelSpec model,
    Map<String, (TypedData, List<int>)> inputs, {
    Set<String> outputs = const {},
  }) async {
    calls.add((model.id, {for (final e in inputs.entries) e.key: e.value.$2}));
    return responses[model.id] ?? {};
  }

  @override
  Future<void> release() async {}
}

RgbaImage _solid(int w, int h, [int v = 128]) {
  final px = Uint8List(w * h * 4);
  for (var i = 0; i < w * h; i++) {
    px[i * 4] = v;
    px[i * 4 + 1] = v;
    px[i * 4 + 2] = v;
    px[i * 4 + 3] = 255;
  }
  return RgbaImage(w, h, px);
}

void main() {
  group('YuNet decode', () {
    test('decodes one synthetic detection at stride 32', () {
      const cols = 20; // 640 / 32
      List<num> zeros(int n) => List<num>.filled(n, 0);
      final out = <String, List<num>>{};
      for (final s in [8, 16, 32]) {
        final n = (640 ~/ s) * (640 ~/ s);
        out['cls_$s'] = zeros(n);
        out['obj_$s'] = zeros(n);
        out['bbox_$s'] = zeros(n * 4);
        out['kps_$s'] = zeros(n * 10);
      }
      // Detection at grid cell (col 5, row 10): anchor (160, 320).
      const i = 10 * cols + 5;
      out['cls_32']![i] = 0.9;
      out['obj_32']![i] = 0.81; // score = sqrt(0.9*0.81) = 0.855…
      out['bbox_32']![i * 4] = 0.1;
      out['bbox_32']![i * 4 + 1] = 0.2;
      out['bbox_32']![i * 4 + 2] = math.log(2);
      out['bbox_32']![i * 4 + 3] = math.log(2);
      // First keypoint on the anchor, second offset by one stride.
      out['kps_32']![i * 10] = 0;
      out['kps_32']![i * 10 + 1] = 0;
      out['kps_32']![i * 10 + 2] = 1;
      out['kps_32']![i * 10 + 3] = 1;

      final faces = FaceDetectionPipeline.decodeYunet(out, inputSize: 640);
      expect(faces, hasLength(1));
      final f = faces.single;
      expect(f.score, closeTo(math.sqrt(0.9 * 0.81), 1e-9));
      expect(f.x, closeTo(160 + 0.1 * 32 - 64 / 2, 1e-6));
      expect(f.y, closeTo(320 + 0.2 * 32 - 64 / 2, 1e-6));
      expect(f.width, 64);
      expect(f.height, 64);
      expect(f.landmarks[0], (160.0, 320.0));
      expect(f.landmarks[1], (192.0, 352.0));
    });

    test('NMS keeps the best of overlapping faces', () {
      DetectedFace face(double x, double y, double score) => DetectedFace(
            x: x,
            y: y,
            width: 64,
            height: 64,
            score: score,
            landmarks: List.generate(5, (_) => (x + 32, y + 32)),
          );
      final kept = FaceDetectionPipeline.nmsFaces(
        [face(0, 0, 0.7), face(8, 8, 0.9), face(200, 200, 0.6)],
        iouThreshold: 0.3,
      );
      expect(kept, hasLength(2));
      expect(kept[0].score, 0.9);
      expect(kept[1].x, 200);
    });

    test('letterbox scales and zero-pads', () {
      final src = _solid(320, 160, 200);
      final out = FaceDetectionPipeline.letterbox(src, 640, 640);
      expect(out.width, 640);
      expect(out.height, 640);
      expect(out.pixels[0], 200); // top-left scaled pixel
      expect(out.pixels[(639 * 640 + 639) * 4], 0); // bottom-right padding
      expect(out.pixels[(100 * 640 + 100) * 4], 200); // inside scaled area
      expect(out.pixels[(500 * 640 + 100) * 4], 0); // below scaled area
    });

    test('BGR/255 tensor contract', () {
      final img = RgbaImage(1, 1, Uint8List.fromList([10, 20, 30, 255]));
      final t = rgbaToNchwBgr255(img);
      expect(t, [30.0, 20.0, 10.0]);
      final nhwc = rgbaToNhwc01(img);
      expect(nhwc[0], closeTo(10 / 255, 1e-7));
      expect(nhwc[1], closeTo(20 / 255, 1e-7));
      expect(nhwc[2], closeTo(30 / 255, 1e-7));
    });
  });

  group('Face Mesh', () {
    test('two-pass landmarks: presence sigmoid + 478 points', () async {
      final src = _solid(512, 512);
      final face = DetectedFace(
        x: 180,
        y: 180,
        width: 150,
        height: 170,
        score: 0.95,
        landmarks: const [(210, 250), (300, 250), (255, 300), (225, 330), (285, 330)],
      );
      List<num> meshResponse() {
        final identity = List<num>.filled(1434, 127.5);
        // Eye corners at ±30 px so the refine pass triggers.
        identity[33 * 3] = 157.5;
        identity[263 * 3] = 97.5;
        return identity;
      }

      final engine = ScriptedEngine({
        'facemesh': {'Identity': meshResponse(), 'Identity_1': [2.0]},
      });
      final mesh = FaceMeshPipeline(engine);
      final result = await mesh.landmarks(src, face);
      expect(result, isNotNull);
      expect(result!.points, hasLength(478));
      expect(result.presence, closeTo(1 / (1 + math.exp(-2)), 1e-6));
      // The mesh ran exactly twice (initial + refine) on a 256² NHWC crop.
      expect(engine.calls, hasLength(2));
      expect(engine.calls.first.$2['input_12'], [1, 256, 256, 3]);
    });

    test('low presence returns null', () async {
      final engine = ScriptedEngine({
        'facemesh': {
          'Identity': List<num>.filled(1434, 127.5),
          'Identity_1': [-10.0], // sigmoid ≈ 0.00005
        },
      });
      final face = DetectedFace(
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        score: 0.9,
        landmarks: const [(20, 20), (80, 20), (50, 50), (30, 80), (70, 80)],
      );
      final mesh = FaceMeshPipeline(engine);
      final result = await mesh.landmarks(_solid(256, 256), face);
      expect(result, isNull);
    });

    test('rotated crop sampler matches its mapper', () {
      // Vertical gradient: R = row index.
      const w = 256;
      const h = 256;
      final px = Uint8List(w * h * 4);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final o = (y * w + x) * 4;
          px[o] = y;
          px[o + 3] = 255;
        }
      }
      final src = RgbaImage(w, h, px);
      const size = 255.0; // 1 crop px == 1 source px
      final crop = rotatedCrop01(src, 128, 128, size, 0);
      // Crop pixel (64, 128) → offset ((64-127.5), (0.5)) → source (64.5, 128.5)
      // → bilinear R = 128.5 (row 128/129 average).
      const idx = (128 * 256 + 64) * 3;
      expect(crop.tensor[idx] * 255, closeTo(128.5, 0.01));
      // roll of 90° swaps axes.
      final rotated = rotatedCrop01(src, 128, 128, size, math.pi / 2);
      const idx2 = (128 * 256 + 64) * 3;
      // offset x = -63.5, y = 0.5 → rotated: sx = 128 - 0.5, sy = 128 - 63.5
      expect(rotated.tensor[idx2] * 255, closeTo(64.5, 0.01));
    });
  });

  group('Region masks', () {
    test('buildRegionMasks: skin excludes eyes, includes cheeks', () {
      const w = 300;
      const h = 300;
      // Synthetic face: oval ring + eye/lip/brow clusters.
      final pts = List<(double, double)>.filled(478, (150, 150));
      for (var k = 0; k < FaceContours.faceOval.length; k++) {
        final a = 2 * math.pi * k / FaceContours.faceOval.length;
        pts[FaceContours.faceOval[k]] = (150 + 110 * math.cos(a), 150 + 130 * math.sin(a));
      }
      for (var k = 0; k < FaceContours.leftEye.length; k++) {
        final a = 2 * math.pi * k / FaceContours.leftEye.length;
        pts[FaceContours.leftEye[k]] = (195 + 12 * math.cos(a), 120 + 8 * math.sin(a));
      }
      for (var k = 0; k < FaceContours.rightEye.length; k++) {
        final a = 2 * math.pi * k / FaceContours.rightEye.length;
        pts[FaceContours.rightEye[k]] = (105 + 12 * math.cos(a), 120 + 8 * math.sin(a));
      }
      for (var k = 0; k < FaceContours.outerLips.length; k++) {
        final a = 2 * math.pi * k / FaceContours.outerLips.length;
        pts[FaceContours.outerLips[k]] = (150 + 25 * math.cos(a), 210 + 15 * math.sin(a));
      }
      for (var k = 0; k < FaceContours.innerLips.length; k++) {
        final a = 2 * math.pi * k / FaceContours.innerLips.length;
        pts[FaceContours.innerLips[k]] = (150 + 15 * math.cos(a), 210 + 9 * math.sin(a));
      }

      final (skin, eyes, teeth) = FaceAnalysisPipeline.buildRegionMasks([pts], w, h);
      int at(RgbaImage m, int x, int y) => m.pixels[(y * w + x) * 4];

      // Cheek (between eye and mouth) is skin.
      expect(at(skin, 150, 165), greaterThan(200));
      // Eye centres are NOT skin.
      expect(at(skin, 195, 120), lessThan(60));
      expect(at(skin, 105, 120), lessThan(60));
      // Eye mask covers the eye centres.
      expect(at(eyes, 195, 120), greaterThan(100));
      // Teeth mask sits inside the lips, below the nose.
      expect(at(teeth, 150, 210), greaterThan(100));
      // Teeth mask does not bleed to the cheek.
      expect(at(teeth, 150, 165), lessThan(10));
    });

    test('polygonMask + scalePolygon + blur + boolean ops', () {
      final square = scalePolygon([(0, 0), (10, 0), (10, 10), (0, 10)], 2);
      expect(square.first, (-5.0, -5.0));
      expect(square[2], (15.0, 15.0));

      final mask = polygonMask([(2, 3), (6, 3), (6, 6), (2, 6)], 10, 10);
      int at(int x, int y) => mask.pixels[(y * 10 + x) * 4];
      expect(at(3, 4), 255);
      expect(at(5, 5), 255);
      expect(at(0, 0), 0);
      expect(at(7, 4), 0);

      final cut = subtractMask(mask, polygonMask([(4, 4), (5, 4), (5, 5), (4, 5)], 10, 10));
      expect(cut.pixels[(4 * 10 + 4) * 4], 0);
      expect(cut.pixels[(3 * 10 + 3) * 4], 255);

      final merged = unionMask(cut, polygonMask([(8, 8), (9, 8), (9, 9), (8, 9)], 10, 10));
      expect(merged.pixels[(8 * 10 + 8) * 4], 255);

      final blurred = blurMask(mask, 1);
      expect(blurred.pixels[(4 * 10 + 4) * 4], 255);
      expect(blurred.pixels[(3 * 10 + 7) * 4], greaterThan(0));
      expect(blurred.pixels[(3 * 10 + 7) * 4], lessThan(255));
    });
  });
}
