import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumora/features/ai/data/onnx_engine.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:lumora/features/ai/pipelines/ai_pipelines.dart';
import 'package:lumora/features/ai/pipelines/tensor_utils.dart';

/// One face found by YuNet, in **source image** pixels.
class DetectedFace {
  DetectedFace({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.score,
    required this.landmarks,
  });

  /// Top-left corner of the axis-aligned box.
  final double x;
  final double y;
  final double width;
  final double height;
  final double score;

  /// The 5 YuNet keypoints, ordered `[right eye, left eye, nose,
  /// right mouth corner, left mouth corner]` – each `(x, y)` in source px.
  final List<(double, double)> landmarks;

  /// Faces are ranked by score; the first is the "main" subject.
  static DetectedFace? largest(List<DetectedFace> faces) {
    if (faces.isEmpty) return null;
    var best = faces.first;
    for (final f in faces.skip(1)) {
      if (f.width * f.height > best.width * best.height) best = f;
    }
    return best;
  }
}

/// 478 landmark points of one face in **source image** pixels, plus the
/// Face Mesh presence confidence (0..1).
class FaceLandmarks {
  const FaceLandmarks(this.points, this.presence);

  /// 478 × (x, y) in image pixels. Indices follow MediaPipe Face Mesh,
  /// including the 10 iris points (468–477).
  final List<(double, double)> points;
  final double presence;
}

// ---------------------------------------------------------------------------
// YuNet face detection (raw 12-output decode, verified against OpenCV)

/// Face detection with OpenCV Zoo **YuNet**.
///
/// The registry ships the raw 12-output export with a static 640×640 input,
/// so this pipeline letterboxes the photo into the graph, decodes the three
/// stride heads in Dart (anchors at grid corners, score = √(cls·obj),
/// `w/h = exp(bbox)·stride`) and applies NMS – exactly the scheme verified
/// against `cv2.FaceDetectorYN` (see docs/SMART_EDIT.md).
class FaceDetectionPipeline {
  FaceDetectionPipeline(this.engine);

  final InferenceEngine engine;

  /// Static graph size.
  static const inputSize = 640;
  static const scoreThreshold = 0.6;
  static const nmsIouThreshold = 0.3;

  Future<List<DetectedFace>> run(String imagePath, {int maxSide = 1280}) async {
    final src = await loadRgba(imagePath, maxSide: maxSide);
    return detect(src);
  }

  Future<List<DetectedFace>> detect(RgbaImage src) async {
    // Letterbox scale: source → 640 frame (uniform, zero padding).
    final scale = math.min(inputSize / src.width, inputSize / src.height);
    final canvas = await Isolate.run(() => letterbox(src, inputSize, inputSize));
    final input = await Isolate.run(() => rgbaToNchwBgr255(canvas));

    const spec = ModelRegistry.yunet;
    final out = await engine.runNamed(spec, {
      spec.inputNames.first: (input, [1, 3, inputSize, inputSize]),
    }, outputs: _outputNames.toSet());

    final faces = decodeYunet(out, inputSize: inputSize);
    // Map the 640-frame boxes back to source pixels (letterbox = uniform
    // scale + bottom-right zero padding).
    return [
      for (final f in faces)
        DetectedFace(
          x: f.x / scale,
          y: f.y / scale,
          width: f.width / scale,
          height: f.height / scale,
          score: f.score,
          landmarks: [
            for (final (lx, ly) in f.landmarks) (lx / scale, ly / scale),
          ],
        ),
    ];
  }

  static const _outputNames = [
    'cls_8', 'cls_16', 'cls_32',
    'obj_8', 'obj_16', 'obj_32',
    'bbox_8', 'bbox_16', 'bbox_32',
    'kps_8', 'kps_16', 'kps_32',
  ];

  /// Letterboxes [src] into a [size]×[size] canvas (uniform scale, zero
  /// padding at the bottom/right).
  static RgbaImage letterbox(RgbaImage src, int size, int size2) {
    final scale = math.min(size / src.width, size2 / src.height);
    final sw = math.max(1, (src.width * scale).round());
    final sh = math.max(1, (src.height * scale).round());
    final scaled = src.resize(sw, sh);
    final canvas = RgbaImage(size, size2);
    for (var y = 0; y < sh; y++) {
      canvas.pixels.setRange(y * size * 4, (y * size + sw) * 4, scaled.pixels, y * sw * 4);
    }
    return canvas;
  }

  /// Pure decode of the 12 raw YuNet outputs for the 640 frame – unit tested
  /// against the reference implementation (verify_yunet_decode.py).
  static List<DetectedFace> decodeYunet(Map<String, List<num>> out, {required int inputSize}) {
    final cands = <DetectedFace>[];
    for (final stride in const [8, 16, 32]) {
      final cols = (inputSize / stride).round();
      final n = cols * cols;
      final cls = out['cls_$stride']!;
      final obj = out['obj_$stride']!;
      final bbox = out['bbox_$stride']!;
      final kps = out['kps_$stride']!;
      for (var i = 0; i < n; i++) {
        final score = math.sqrt((cls[i] * obj[i]).clamp(0.0, 1.0).toDouble());
        if (score <= scoreThreshold) continue;
        final ax = (i % cols) * stride.toDouble();
        final ay = (i ~/ cols) * stride.toDouble();
        final cx = ax + bbox[i * 4] * stride;
        final cy = ay + bbox[i * 4 + 1] * stride;
        final bw = math.exp(bbox[i * 4 + 2].toDouble()) * stride;
        final bh = math.exp(bbox[i * 4 + 3].toDouble()) * stride;
        final lm = <(double, double)>[];
        for (var k = 0; k < 5; k++) {
          lm.add((
            ax + kps[i * 10 + k * 2] * stride,
            ay + kps[i * 10 + k * 2 + 1] * stride,
          ));
        }
        cands.add(DetectedFace(
          x: cx - bw / 2,
          y: cy - bh / 2,
          width: bw,
          height: bh,
          score: score,
          landmarks: lm,
        ));
      }
    }
    return nmsFaces(cands, iouThreshold: nmsIouThreshold);
  }

  /// Greedy NMS over detection candidates (highest score first).
  static List<DetectedFace> nmsFaces(List<DetectedFace> faces, {required double iouThreshold}) {
    final sorted = [...faces]..sort((a, b) => b.score.compareTo(a.score));
    final kept = <DetectedFace>[];
    for (final f in sorted) {
      var ok = true;
      for (final k in kept) {
        if (_iou(f, k) > iouThreshold) {
          ok = false;
          break;
        }
      }
      if (ok) kept.add(f);
    }
    return kept;
  }

  static double _iou(DetectedFace a, DetectedFace b) {
    final x1 = math.max(a.x, b.x);
    final y1 = math.max(a.y, b.y);
    final x2 = math.min(a.x + a.width, b.x + b.width);
    final y2 = math.min(a.y + a.height, b.y + b.height);
    final inter = math.max(0, x2 - x1) * math.max(0, y2 - y1);
    final union = a.width * a.height + b.width * b.height - inter;
    return union > 0 ? inter / union : 0;
  }
}

// ---------------------------------------------------------------------------
// MediaPipe Face Mesh (478 landmarks, two-pass alignment)

/// Face landmarks with the MediaPipe two-pass alignment scheme verified in
/// `scripts/verify_face_models.py`:
///
/// 1. eyes-level square crop centred between the YuNet eye keypoints
///    (side = 3× eye distance, centre raised 0.35× eye distance);
/// 2. refine crop from the mesh's own bounding box (size ×1.35, roll from
///    the mesh eye corners).
class FaceMeshPipeline {
  FaceMeshPipeline(this.engine);

  final InferenceEngine engine;

  /// Sampler/mapper resolution.
  static const cropSize = 256;

  static const ModelSpec spec = ModelRegistry.faceMesh;

  Future<FaceLandmarks?> run(String imagePath, DetectedFace face, {int maxSide = 1280}) async {
    final src = await loadRgba(imagePath, maxSide: maxSide);
    return landmarks(src, face);
  }

  Future<FaceLandmarks?> landmarks(RgbaImage src, DetectedFace face) async {
    final (re, le) = (face.landmarks[0], face.landmarks[1]);
    final eyeDist = math.sqrt(math.pow(le.$1 - re.$1, 2) + math.pow(le.$2 - re.$2, 2));
    if (eyeDist < 4) return null;
    final roll1 = math.atan2(le.$2 - re.$2, le.$1 - re.$1);
    final cx1 = (re.$1 + le.$1) / 2;
    final cy1 = (re.$2 + le.$2) / 2 - eyeDist * 0.35;
    final size1 = eyeDist * 3.0;

    final mesh = await _runMesh(src, cx1, cy1, size1, roll1);
    if (mesh == null) return null;

    // Refine pass: re-crop from the mesh's own bounding box.
    final pts = _toImage(mesh.points, cx1, cy1, size1, roll1);
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final (px, py) in pts) {
      if (px < minX) minX = px;
      if (py < minY) minY = py;
      if (px > maxX) maxX = px;
      if (py > maxY) maxY = py;
    }
    final rSize = math.max(maxX - minX, maxY - minY) * 1.35;
    if (rSize < 16) return mesh;
    final rcx = (minX + maxX) / 2;
    final rcy = (minY + maxY) / 2;
    final (lEye, rEye) = (pts[33], pts[263]);
    final rRoll = math.atan2(lEye.$2 - rEye.$2, lEye.$1 - rEye.$1);
    final refined = await _runMesh(src, rcx, rcy, rSize, rRoll);
    if (refined == null) return mesh;
    return FaceLandmarks(
      _toImage(refined.points, rcx, rcy, rSize, rRoll),
      refined.presence,
    );
  }

  Future<FaceLandmarks?> _runMesh(RgbaImage src, double cx, double cy, double size, double roll) async {
    final crop = await Isolate.run(() => rotatedCrop01(src, cx, cy, size, roll));
    final out = await engine.runNamed(spec, {
      spec.inputNames.first: (crop.tensor, [1, cropSize, cropSize, 3]),
    }, outputs: {'Identity', 'Identity_1'});
    final flat = out['Identity'];
    final logit = out['Identity_1'];
    if (flat == null || flat.length < 1434 || logit == null || logit.isEmpty) return null;
    final points = <(double, double)>[];
    for (var i = 0; i < 478; i++) {
      points.add((flat[i * 3].toDouble(), flat[i * 3 + 1].toDouble()));
    }
    final l = logit.first.toDouble();
    final presence = 1 / (1 + math.exp(-l));
    if (presence < 0.35) return null;
    return FaceLandmarks(points, presence);
  }

  /// Maps crop-space landmark coordinates (0..255) into image pixels for a
  /// crop taken with centre ([cx], [cy]), side [size] and roll [roll].
  static List<(double, double)> _toImage(List<(double, double)> pts, double cx, double cy, double size, double roll) {
    final k = size / 255;
    final ca = math.cos(roll);
    final sa = math.sin(roll);
    return [
      for (final (px, py) in pts)
        (
          cx + (px - 127.5) * k * ca - (py - 127.5) * k * sa,
          cy + (px - 127.5) * k * sa + (py - 127.5) * k * ca,
        ),
    ];
  }
}

/// Samples a rotated square crop as the Face Mesh input tensor.
///
/// Crop pixel (u, v) samples the source at
/// `(cx, cy) + R(roll) · ((u - 127.5), (v - 127.5)) · size/255` with bilinear
/// interpolation and edge clamping (same convention as the reference
/// implementation, so the mapping in [FaceMeshPipeline] is its exact
/// inverse).
class MeshCrop {
  const MeshCrop(this.tensor);
  final Float32List tensor;
}

MeshCrop rotatedCrop01(RgbaImage src, double cx, double cy, double size, double roll) {
  const n = FaceMeshPipeline.cropSize;
  final k = size / 255;
  final ca = math.cos(roll);
  final sa = math.sin(roll);
  final out = Float32List(n * n * 3);
  final px = src.pixels;
  final w = src.width;
  final h = src.height;
  for (var v = 0; v < n; v++) {
    final oy = (v - 127.5) * k;
    for (var u = 0; u < n; u++) {
      final ox = (u - 127.5) * k;
      final sx = (cx + ox * ca - oy * sa).clamp(0.0, w - 1.0);
      final sy = (cy + ox * sa + oy * ca).clamp(0.0, h - 1.0);
      final x0 = sx.floor();
      final y0 = sy.floor();
      final x1 = math.min(x0 + 1, w - 1);
      final y1 = math.min(y0 + 1, h - 1);
      final fx = sx - x0;
      final fy = sy - y0;
      final i00 = (y0 * w + x0) * 4;
      final i10 = (y0 * w + x1) * 4;
      final i01 = (y1 * w + x0) * 4;
      final i11 = (y1 * w + x1) * 4;
      final o = (v * n + u) * 3;
      for (var c = 0; c < 3; c++) {
        final top = px[i00 + c] * (1 - fx) + px[i10 + c] * fx;
        final bot = px[i01 + c] * (1 - fx) + px[i11 + c] * fx;
        out[o + c] = (top * (1 - fy) + bot * fy) / 255;
      }
    }
  }
  return MeshCrop(out);
}

// ---------------------------------------------------------------------------
// Face region masks (skin / eyes / teeth)

/// MediaPipe Face Mesh contour indices (ordered rings, closed implicitly).
abstract final class FaceContours {
  static const faceOval = [
    10, 338, 297, 332, 284, 251, 389, 356, 454, 323, 361, 288, 397, 365, 379,
    378, 400, 377, 152, 148, 176, 149, 150, 136, 172, 58, 132, 93, 234, 127,
    162, 21, 54, 103, 67, 109,
  ];
  static const leftEye = [362, 382, 381, 380, 374, 373, 390, 249, 263, 466, 388, 387, 386, 385, 384, 398];
  static const rightEye = [33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246];
  static const leftBrow = [276, 283, 282, 295, 285, 300, 293, 334, 296, 336];
  static const rightBrow = [46, 53, 52, 65, 55, 70, 63, 105, 66, 107];
  static const outerLips = [61, 146, 91, 181, 84, 17, 314, 405, 321, 375, 291, 409, 270, 269, 267, 0, 37, 39, 40, 185];
  static const innerLips = [78, 95, 88, 178, 87, 179, 185, 40, 74, 191, 80, 81, 82, 13, 312, 308, 317, 314, 405, 321, 375, 291, 409, 267, 269, 270];
  static const leftIris = [468, 469, 470, 471, 472];
  static const rightIris = [473, 474, 475, 476, 477];
}

/// Face-aware retouch masks built from the 478 landmarks:
///
/// * **skin** – face oval minus (eyes ∪ brows ∪ lips), feathered;
/// * **eyes** – eye rings grown 1.6× (eye brighten);
/// * **teeth** – inner-lip polygon shrunk 0.9× (teeth whiten; the editor
///   applies it luminance-selectively so lips stay untouched).
class FaceRetouchResult {
  const FaceRetouchResult({
    required this.skinMaskPath,
    required this.eyesMaskPath,
    required this.teethMaskPath,
    required this.faceCount,
  });

  final String skinMaskPath;
  final String eyesMaskPath;
  final String teethMaskPath;
  final int faceCount;
}

/// End-to-end face analysis: detect → landmarks per face (up to [maxFaces])
/// → combined region masks.
class FaceAnalysisPipeline {
  FaceAnalysisPipeline(this.engine);

  final InferenceEngine engine;

  Future<FaceRetouchResult?> run(String imagePath, {int maxFaces = 4, int maxSide = 1280}) async {
    final src = await loadRgba(imagePath, maxSide: maxSide);
    final faces = await FaceDetectionPipeline(engine).detect(src);
    if (faces.isEmpty) return null;

    final mesh = FaceMeshPipeline(engine);
    final all = <List<(double, double)>>[];
    var count = 0;
    for (final f in faces.take(maxFaces)) {
      final lm = await mesh.landmarks(src, f);
      if (lm != null) {
        all.add(lm.points);
        count++;
      }
    }
    if (all.isEmpty) return null;

    final (skin, eyes, teeth) = await Isolate.run(() => buildRegionMasks(all, src.width, src.height));
    return FaceRetouchResult(
      skinMaskPath: await savePng(skin, 'face_skin'),
      eyesMaskPath: await savePng(eyes, 'face_eyes'),
      teethMaskPath: await savePng(teeth, 'face_teeth'),
      faceCount: count,
    );
  }

  /// Pure mask construction – unit tested in isolation.
  static (RgbaImage, RgbaImage, RgbaImage) buildRegionMasks(
    List<List<(double, double)>> faces,
    int width,
    int height,
  ) {
    var skin = RgbaImage(width, height);
    var eyes = RgbaImage(width, height);
    var teeth = RgbaImage(width, height);
    final feather = math.max(1, math.min(width, height) ~/ 320);
    for (final pts in faces) {
      if (pts.length < 478) continue;
      List<(double, double)> ring(List<int> idx, [double scale = 1]) =>
          scalePolygon([for (final i in idx) pts[i]], scale);
      final oval = polygonMask(ring(FaceContours.faceOval), width, height);
      final eyeRegions = unionMask(
        polygonMask(ring(FaceContours.leftEye, 1.45), width, height),
        polygonMask(ring(FaceContours.rightEye, 1.45), width, height),
      );
      final brows = unionMask(
        polygonMask(ring(FaceContours.leftBrow, 1.3), width, height),
        polygonMask(ring(FaceContours.rightBrow, 1.3), width, height),
      );
      final lips = polygonMask(ring(FaceContours.outerLips, 1.12), width, height);

      var faceSkin = subtractMask(oval, eyeRegions);
      faceSkin = subtractMask(faceSkin, brows);
      faceSkin = subtractMask(faceSkin, lips);
      skin = unionMask(skin, blurMask(faceSkin, feather));

      eyes = unionMask(
        eyes,
        blurMask(
          unionMask(
            polygonMask(ring(FaceContours.leftEye, 1.6), width, height),
            polygonMask(ring(FaceContours.rightEye, 1.6), width, height),
          ),
          feather,
        ),
      );
      teeth = unionMask(teeth, blurMask(polygonMask(ring(FaceContours.innerLips, 0.9), width, height), feather));
    }
    return (skin, eyes, teeth);
  }
}
