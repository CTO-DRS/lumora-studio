import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumora/features/ai/data/onnx_engine.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:lumora/features/ai/pipelines/face_pipeline.dart';
import 'package:lumora/features/ai/pipelines/tensor_utils.dart';


/// Gradient raster with distinct values per pixel (for sampling tests).
RgbaImage _gradient(int w, int h) {
  final px = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      px[i] = (x * 7) % 256;
      px[i + 1] = (y * 5) % 256;
      px[i + 2] = (x + y) % 256;
      px[i + 3] = 255;
    }
  }
  return RgbaImage(w, h, px);
}

/// Synthetic 478-point mesh: every landmark at the origin except the sets
/// the mask builder uses, which are laid out as small squares.
Float32List _syntheticMesh({
  required (double, double) ovalTopLeft,
  required double ovalSide,
  required (double, double) eyeTopLeft,
  required double eyeSide,
  required (double, double) lipsTopLeft,
  required double lipsSide,
  required (double, double) innerTopLeft,
  required double innerSide,
}) {
  final pts = Float32List(478 * 2);
  void place(List<int> indices, double x0, double y0, double side) {
    final n = indices.length;
    for (var k = 0; k < n; k++) {
      // spread the ring points around the square perimeter
      final t = k / n;
      final edge = (t * 4).floor();
      final f = (t * 4) - edge;
      final (dx, dy) = switch (edge) {
        0 => (f * side, 0.0),
        1 => (side, f * side),
        2 => (side - f * side, side),
        _ => (0.0, side - f * side),
      };
      pts[indices[k] * 2] = x0 + dx;
      pts[indices[k] * 2 + 1] = y0 + dy;
    }
  }

  place(kFaceOval, ovalTopLeft.$1, ovalTopLeft.$2, ovalSide);
  place(kEyeA, eyeTopLeft.$1, eyeTopLeft.$2, eyeSide);
  place(kEyeB, eyeTopLeft.$1 + eyeSide + 4, eyeTopLeft.$2, eyeSide);
  place(kLipsOuter, lipsTopLeft.$1, lipsTopLeft.$2, lipsSide);
  place(kLipsInner, innerTopLeft.$1, innerTopLeft.$2, innerSide);
  return pts;
}

FaceAnalysis _analysis(Float32List pts) {
  final det = FaceDetection(0, 0, 90, 90, 0.9, Float32List(10));
  return FaceAnalysis([FaceGeometry(pts, 0.95, det)], 100, 100);
}

void main() {
  late File photo;
  setUp(() {
    // A real 100×100 PNG: loadRgba decodes from disk.
    final im = img.Image(width: 100, height: 100);
    for (var y = 0; y < 100; y++) {
      for (var x = 0; x < 100; x++) {
        im.setPixelRgba(x, y, (x * 7) % 256, (y * 5) % 256, (x + y) % 256, 255);
      }
    }
    photo = File('${Directory.systemTemp.path}/lumora_face_test.png')
      ..writeAsBytesSync(img.encodePng(im));
  });
  group('YuNet decode', () {
    Map<String, List<num>> syntheticOutputs({
      required int cell,
      required int cols,
      required double score,
      required List<double> bbox,
      required List<double> kps,
      double? secondScore,
    }) {
      Map<String, List<num>> zero(String name, int n, int c) => {name: List<num>.filled(n * c, 0)};
      final out = <String, List<num>>{};
      for (final s in const [8, 16, 32]) {
        final n = s == 8 ? 6400 : (s == 16 ? 1600 : 400);
        out.addAll(zero('cls_$s', n, 1));
        out.addAll(zero('obj_$s', n, 1));
        out.addAll(zero('bbox_$s', n, 4));
        out.addAll(zero('kps_$s', n, 10));
      }
      out['cls_8']![cell] = score;
      out['obj_8']![cell] = score;
      for (var k = 0; k < 4; k++) {
        out['bbox_8']![cell * 4 + k] = bbox[k];
      }
      for (var k = 0; k < 10; k++) {
        out['kps_8']![cell * 10 + k] = kps[k];
      }
      if (secondScore != null) {
        final c2 = cell + 1; // neighbour → suppressed by NMS
        out['cls_8']![c2] = secondScore;
        out['obj_8']![c2] = secondScore;
        for (var k = 0; k < 4; k++) {
          out['bbox_8']![c2 * 4 + k] = bbox[k];
        }
        for (var k = 0; k < 10; k++) {
          out['kps_8']![c2 * 10 + k] = kps[k];
        }
      }
      return out;
    }

    test('decodes anchor, bbox and keypoints at stride 8', () {
      // 640/8 = 80 cols; cell 40*80 + 50 → anchor (400, 320).
      const cell = 40 * 80 + 50;
      final out = syntheticOutputs(
        cell: cell,
        cols: 80,
        score: 0.9,
        bbox: [0.5, 0.25, math.log(4), math.log(2)],
        kps: [0.5, 0.5, 1.5, 0.5, 1.0, 1.0, 1.0, 2.0, 2.0, 2.0],
      );
      final faces = decodeYunet(out, 640, 640);
      expect(faces, hasLength(1));
      final f = faces.single;
      expect(f.score, closeTo(0.9, 1e-6));
      // centre = anchor + bbox[:2] * 8 = (404, 322); w/h = exp(log 4)*8=32, exp(log 2)*8=16.
      expect(f.x, closeTo(404 - 16, 1e-3));
      expect(f.y, closeTo(322 - 8, 1e-3));
      expect(f.w, closeTo(32, 1e-3));
      expect(f.h, closeTo(16, 1e-3));
      // keypoints: anchor + kps * stride
      expect(f.kps[0], closeTo(400 + 0.5 * 8, 1e-3));
      expect(f.kps[1], closeTo(320 + 0.5 * 8, 1e-3));
      expect(f.kps[4], closeTo(400 + 1.0 * 8, 1e-3));
      expect(f.kps[5], closeTo(320 + 1.0 * 8, 1e-3));
    });

    test('NMS suppresses overlapping candidates', () {
      const cell = 40 * 80 + 50;
      final out = syntheticOutputs(
        cell: cell,
        cols: 80,
        score: 0.9,
        bbox: [0.5, 0.25, math.log(4), math.log(2)],
        kps: List<double>.filled(10, 0.5),
        secondScore: 0.8,
      );
      final faces = decodeYunet(out, 640, 640);
      expect(faces, hasLength(1));
      expect(faces.single.score, closeTo(0.9, 1e-6));
    });

    test('below-threshold scores are dropped', () {
      final out = syntheticOutputs(cell: 100, cols: 80, score: 0.1, bbox: [0, 0, 0, 0], kps: List<double>.filled(10, 0));
      expect(decodeYunet(out, 640, 640), isEmpty);
    });
  });

  group('aligned crop', () {
    test('identity framing samples pixel-centre bilinear', () {
      final src = _gradient(64, 64);
      final crop = alignedCrop(src, 32, 32, 64, 0);
      // k = 64/256 = 0.25 → crop pixel 0 samples source x = 0.125.
      expect(crop.pixels[0], closeTo(src.pixels[0] * 0.875 + src.pixels[4] * 0.125, 1.5));
      expect(crop.width, 256);
      expect(crop.height, 256);
    });

    test('cropToSource inverts the sampling coordinates', () {
      const cx = 40.0;
      const cy = 25.0;
      const size = 50.0;
      // Continuous mesh coordinate 128 is the exact crop centre.
      final (x, y) = cropToSource(128, 128, cx, cy, size, 0);
      expect(x, closeTo(cx, 1e-6));
      expect(y, closeTo(cy, 1e-6));
      final (rx, ry) = cropToSource(0, 0, cx, cy, size, 90);
      // (0,0) → local (-25, -25); rotated 90°: (25, -25).
      expect(rx, closeTo(cx + 25, 1e-6));
      expect(ry, closeTo(cy - 25, 1e-6));
    });
  });

  group('tensor helpers', () {
    test('rgbaToNchwBgr255 lays out BGR planes of 0..255', () {
      final img = RgbaImage(2, 1, Uint8List.fromList([1, 2, 3, 255, 4, 5, 6, 255]));
      final t = rgbaToNchwBgr255(img);
      expect(t, [3, 6, 2, 5, 1, 4]); // B plane, G plane, R plane
    });

    test('rgbaToNhwc01 lays out RGB 0..1 per pixel', () {
      final img = RgbaImage(1, 2, Uint8List.fromList([255, 0, 0, 255, 0, 255, 0, 255]));
      final t = rgbaToNhwc01(img);
      expect(t[0], closeTo(1, 1e-6)); // first pixel red
      expect(t[1], closeTo(0, 1e-6));
      expect(t[4], closeTo(1, 1e-6)); // second pixel green
      expect(t[3], closeTo(0, 1e-6));
    });
  });

  group('face masks', () {
    late FaceAnalysis analysis;
    setUp(() {
      analysis = _analysis(_syntheticMesh(
        ovalTopLeft: (10, 10),
        ovalSide: 80,
        eyeTopLeft: (20, 20),
        eyeSide: 10,
        lipsTopLeft: (20, 60),
        lipsSide: 20,
        innerTopLeft: (23, 63),
        innerSide: 8,
      ));
    });

    test('skin mask covers the oval, minus eyes, brows and lips', () {
      final mask = buildFaceMask(analysis, FaceRegion.skin, 100, 100);
      double at(int x, int y) => mask.pixels[(y * 100 + x) * 4] / 255;
      expect(at(50, 12), closeTo(1, 0.05)); // inside the oval, above the eyes
      expect(at(25, 25), closeTo(0, 0.05)); // eye hole
      expect(at(30, 70), closeTo(0, 0.05)); // outer lips hole
      expect(at(50, 95), closeTo(0, 0.05)); // outside the oval
    });

    test('eye mask dilates the eye rings only', () {
      final mask = buildFaceMask(analysis, FaceRegion.eyes, 100, 100);
      double at(int x, int y) => mask.pixels[(y * 100 + x) * 4] / 255;
      expect(at(25, 25), closeTo(1, 0.05)); // inside eye A
      expect(at(37, 25), closeTo(1, 0.05)); // inside eye B
      expect(at(50, 12), closeTo(0, 0.05)); // not skin
      expect(at(30, 70), closeTo(0, 0.05)); // not lips
    });

    test('teeth mask is the eroded inner lip ring', () {
      final mask = buildFaceMask(analysis, FaceRegion.teeth, 100, 100);
      double at(int x, int y) => mask.pixels[(y * 100 + x) * 4] / 255;
      expect(at(27, 67), closeTo(1, 0.05)); // inside inner lips
      expect(at(21, 61), closeTo(0, 0.05)); // between inner and outer lips
      expect(at(50, 12), closeTo(0, 0.05)); // not skin
    });

    test('mask is stretched to the requested size', () {
      final mask = buildFaceMask(analysis, FaceRegion.skin, 200, 100);
      expect(mask.width, 200);
      expect(mask.height, 100);
    });
  });

  group('registry', () {
    test('the two v1.4 face models are registered within budget', () {
      final detect = ModelRegistry.byId('yunet_face_detect');
      final mesh = ModelRegistry.byId('face_landmarks_478');
      expect(detect.sizeBytes + mesh.sizeBytes, lessThanOrEqualTo(15 * 1024 * 1024));
      expect(detect.license, contains('MIT'));
      expect(mesh.license, contains('Apache-2.0'));
      expect(detect.sha256, hasLength(64));
      expect(mesh.sha256, hasLength(64));
    });

    test('face tools need exactly the two face models', () {
      for (final tool in [AiTool.faceRetouch, AiTool.eyeBrighten, AiTool.teethWhiten]) {
        expect(aiToolModels(tool).map((m) => m.id).toSet(), {'yunet_face_detect', 'face_landmarks_478'});
      }
    });

    test('landmark index sets keep their canonical sizes', () {
      expect(kFaceOval, hasLength(36));
      expect(kEyeA, hasLength(16));
      expect(kEyeB, hasLength(16));
      expect(kLipsOuter, hasLength(20));
      expect(kLipsInner, hasLength(20));
      expect(kFaceOval.toSet(), hasLength(kFaceOval.length));
    });
  });

  group('FacePipeline tensor contracts', () {
    test('runs the detector at 640² and the mesh at 256² NHWC', () async {
      // The zeroed fake engine → presence 0 → no faces.
      final engine = _DetectingFake(detectFace: false);
      final pipeline = FacePipeline(engine);
      final analysis = await pipeline.analyze(photo.path);
      expect(analysis.faces, isEmpty);
      final calls = engine.calls;
      expect(calls, hasLength(1)); // detector ran, mesh skipped (no faces)
      final (model, shapes) = calls.single;
      expect(model, 'yunet_face_detect');
      expect(shapes['input'], [1, 3, 640, 640]);
    });

    test('mesh pass uses the documented input name and shape', () async {
      // A fake engine that "finds" a face so the mesh runs once.
      final engine = _DetectingFake();
      final pipeline = FacePipeline(engine);
      final analysis = await pipeline.analyze(photo.path);
      expect(analysis.faces, hasLength(1));
      expect(analysis.faces.single.presence, closeTo(1, 0.001));
      final meshCall = engine.calls.singleWhere((c) => c.$1 == 'face_landmarks_478');
      expect(meshCall.$2['input_12'], [1, 256, 256, 3]);
    });
  });
}

/// Fake engine whose detector reports one strong face at the centre (or
/// nothing when [detectFace] is false) and whose mesh returns 478 identity
/// landmarks with presence 1.
///
/// Unlike the shared FakeEngine it produces every raw YuNet output, since
/// [decodeYunet] reads all twelve by name.
class _DetectingFake implements InferenceEngine {
  _DetectingFake({this.detectFace = true});

  final bool detectFace;

  final calls = <(String, Map<String, List<int>>)>[];

  @override
  Future<List<num>> run(ModelSpec model, Map<String, (TypedData, List<int>)> inputs) async {
    final out = await runAll(model, inputs);
    return out[model.outputName] ?? out.values.first;
  }

  @override
  Future<Map<String, List<num>>> runAll(ModelSpec model, Map<String, (TypedData, List<int>)> inputs) async {
    calls.add((model.id, {for (final e in inputs.entries) e.key: e.value.$2}));
    if (model.id == 'yunet_face_detect') {
      return detectFace ? _detectorOutputs() : _detectorOutputs(zeroed: true);
    }
    final mesh = Float32List(478 * 3);
    for (var i = 0; i < 478; i++) {
      mesh[i * 3] = 128;
      mesh[i * 3 + 1] = 128;
      mesh[i * 3 + 2] = 0;
    }
    return {
      'Identity': mesh,
      'Identity_1': [10.0], // logit → presence ≈ 1
      'Identity_2': [0.0],
    };
  }

  static Map<String, List<num>> _detectorOutputs({bool zeroed = false}) {
    Map<String, List<num>> zero(String name, int n, int c) => {name: List<num>.filled(n * c, 0)};
    final out = <String, List<num>>{};
    for (final s in const [8, 16, 32]) {
      final n = s == 8 ? 6400 : (s == 16 ? 1600 : 400);
      out.addAll(zero('cls_$s', n, 1));
      out.addAll(zero('obj_$s', n, 1));
      out.addAll(zero('bbox_$s', n, 4));
      out.addAll(zero('kps_$s', n, 10));
    }
    // stride-32 cell (10, 10) → anchor (320, 320); face 320×320.
    if (zeroed) return out;
    const cell = 10 * 20 + 10;
    out['cls_32']![cell] = 0.9;
    out['obj_32']![cell] = 0.9;
    out['bbox_32']![cell * 4] = 0.0;
    out['bbox_32']![cell * 4 + 1] = 0.0;
    out['bbox_32']![cell * 4 + 2] = math.log(10);
    out['bbox_32']![cell * 4 + 3] = math.log(10);
    for (var k = 0; k < 10; k++) {
      out['kps_32']![cell * 10 + k] = 0.0;
    }
    return out;
  }

  @override
  Future<void> release() async {}
}
