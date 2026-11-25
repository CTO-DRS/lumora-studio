import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show immutable;
import 'package:lumora/features/ai/data/onnx_engine.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:lumora/features/ai/pipelines/ai_pipelines.dart';
import 'package:lumora/features/ai/pipelines/tensor_utils.dart';

// ---------------------------------------------------------------------------
// MediaPipe FaceMesh landmark index sets (canonical constants)

/// The face contour, in order ([FACEMESH_FACE_OVAL]).
const List<int> kFaceOval = [
  10, 338, 297, 332, 284, 251, 389, 356, 454, 323, 361, 288, 397, 365, 379, 378, 400, 377, 152, 148, 176, 149, 150,
  136, 172, 58, 132, 93, 234, 127, 162, 21, 54, 103, 67, 109,
];

/// One eye ring ([FACEMESH_LEFT_EYE], 16 points).
const List<int> kEyeA = [33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246];

/// The other eye ring ([FACEMESH_RIGHT_EYE], 16 points).
const List<int> kEyeB = [362, 382, 381, 380, 374, 373, 390, 249, 263, 466, 388, 387, 386, 385, 384, 398];

/// Eyebrow rings ([FACEMESH_LEFT_EYEBROW] / [FACEMESH_RIGHT_EYEBROW]).
const List<int> kBrowA = [70, 63, 105, 66, 107, 55, 65, 52, 53, 46];
const List<int> kBrowB = [300, 293, 334, 296, 336, 285, 295, 282, 283, 276];

/// Outer lip ring ([FACEMESH_LIPS], outer loop).
const List<int> kLipsOuter = [61, 146, 91, 181, 84, 17, 314, 405, 321, 375, 291, 409, 270, 269, 267, 0, 37, 39, 40, 185];

/// Inner lip ring — the mouth opening (teeth region).
const List<int> kLipsInner = [78, 95, 88, 178, 87, 14, 317, 402, 318, 324, 308, 415, 310, 311, 312, 13, 82, 81, 80, 191];

/// What a face mask covers.
enum FaceRegion { skin, eyes, teeth }

// ---------------------------------------------------------------------------
// Results

/// One face found by YuNet: axis-aligned box, five keypoints
/// (right eye, left eye, nose tip, right mouth, left mouth) and the
/// confidence, all in the *analysed raster's* pixel space.
@immutable
class FaceDetection {
  const FaceDetection(this.x, this.y, this.width, this.height, this.score, this.keypoints);

  final double x;
  final double y;
  final double width;
  final double height;
  final double score;

  /// 5 × (x, y), flattened.
  final Float32List keypoints;
}

/// One analysed face: the 478-point mesh mapped back to raster pixels.
@immutable
class FaceGeometry {
  const FaceGeometry(this.points, this.presence, this.detection);

  /// 478 × (x, y) in raster pixels (z is dropped — masks are 2-D).
  final Float32List points;

  /// Face-presence confidence (sigmoid of the mesh's presence logit).
  final double presence;

  final FaceDetection detection;
}

/// Every face in one photo.
@immutable
class FaceAnalysis {
  const FaceAnalysis(this.faces, this.width, this.height);

  final List<FaceGeometry> faces;

  /// Size of the analysed raster.
  final int width;
  final int height;
}

// ---------------------------------------------------------------------------
// YuNet decoding (pure, testable)

/// One raw detection in the 640×640 detector frame.
@immutable
class RawFace {
  const RawFace(this.score, this.x, this.y, this.w, this.h, this.kps);

  final double score;
  final double x;
  final double y;
  final double w;
  final double h;

  /// 5 × (x, y), flattened.
  final Float32List kps;
}

/// Decodes the 12 raw YuNet outputs (cls/obj/bbox/kps at strides 8/16/32)
/// into detections in the [w]×[h] detector frame. The graph applies the
/// sigmoids itself, so the confidence is sqrt(cls · obj). Anchors sit on
/// grid corners (no 0.5 offset), the box centre is anchor + bbox[:2] ·
/// stride, w/h = exp(bbox[2:]) · stride and each keypoint is
/// anchor + kps · stride — the layout the upstream reference verified
/// against cv2.FaceDetectorYN. NMS with [nmsIou], strongest first.
List<RawFace> decodeYunet(
  Map<String, List<num>> out,
  int w,
  int h, {
  double scoreThreshold = 0.5,
  double nmsIou = 0.3,
  int maxFaces = 8,
}) {
  final cands = <RawFace>[];
  for (final stride in const [8, 16, 32]) {
    final cols = (w / stride).ceil();
    final rows = (h / stride).ceil();
    final n = rows * cols;
    final cls = out['cls_$stride']!;
    final obj = out['obj_$stride']!;
    final bbox = out['bbox_$stride']!;
    final kps = out['kps_$stride']!;
    for (var j = 0; j < n; j++) {
      final score = math.sqrt((cls[j] * obj[j]).clamp(0.0, 1.0).toDouble());
      if (score <= scoreThreshold) continue;
      final cx0 = (j % cols) * stride;
      final cy0 = (j ~/ cols) * stride;
      final cx = cx0 + bbox[j * 4].toDouble() * stride;
      final cy = cy0 + bbox[j * 4 + 1].toDouble() * stride;
      final bw = math.exp(bbox[j * 4 + 2].toDouble()) * stride;
      final bh = math.exp(bbox[j * 4 + 3].toDouble()) * stride;
      final kp = Float32List(10);
      for (var k = 0; k < 10; k++) {
        kp[k] = (k.isEven ? cx0 : cy0) + kps[j * 10 + k].toDouble() * stride;
      }
      cands.add(RawFace(score, cx - bw / 2, cy - bh / 2, bw, bh, kp));
    }
  }
  cands.sort((a, b) => b.score.compareTo(a.score));
  final picked = <RawFace>[];
  for (final c in cands) {
    var ok = true;
    for (final p in picked) {
      if (_iou(c.x, c.y, c.w, c.h, p.x, p.y, p.w, p.h) > nmsIou) {
        ok = false;
        break;
      }
    }
    if (ok) picked.add(c);
    if (picked.length >= maxFaces) break;
  }
  return picked;
}

double _iou(double ax, double ay, double aw, double ah, double bx, double by, double bw, double bh) {
  final x1 = math.max(ax, bx);
  final y1 = math.max(ay, by);
  final x2 = math.min(ax + aw, bx + bw);
  final y2 = math.min(ay + ah, by + bh);
  final iw = math.max(0, x2 - x1);
  final ih = math.max(0, y2 - y1);
  final inter = iw * ih;
  final union = aw * ah + bw * bh - inter;
  final v = union <= 0 ? 0 : inter / union;
  return v.toDouble();
}

// ---------------------------------------------------------------------------
// Aligned crop (pure, testable)

/// Samples a square crop of side [size] centred at ([cx], [cy]), rotated by
/// [rollDeg] (so the eye line ends up level) — the framing the MediaPipe
/// landmark model expects. Bilinear, clamped at the edges.
RgbaImage alignedCrop(RgbaImage src, double cx, double cy, double size, double rollDeg) {
  const side = 256;
  final out = Uint8List(side * side * 4);
  final a = rollDeg * math.pi / 180;
  final ca = math.cos(a);
  final sa = math.sin(a);
  final half = size / 2;
  final sw = src.width;
  final sh = src.height;
  final px = src.pixels;
  for (var v = 0; v < side; v++) {
    final ly = -half + (v + 0.5) * size / side;
    for (var u = 0; u < side; u++) {
      final lx = -half + (u + 0.5) * size / side;
      final sx = cx + lx * ca - ly * sa;
      final sy = cy + lx * sa + ly * ca;
      final xi = sx.clamp(0.0, (sw - 1).toDouble());
      final yi = sy.clamp(0.0, (sh - 1).toDouble());
      final x0 = xi.floor();
      final y0 = yi.floor();
      final x1 = math.min(x0 + 1, sw - 1);
      final y1 = math.min(y0 + 1, sh - 1);
      final fx = xi - x0;
      final fy = yi - y0;
      final o = (v * side + u) * 4;
      for (var c = 0; c < 4; c++) {
        final p00 = px[(y0 * sw + x0) * 4 + c];
        final p10 = px[(y0 * sw + x1) * 4 + c];
        final p01 = px[(y1 * sw + x0) * 4 + c];
        final p11 = px[(y1 * sw + x1) * 4 + c];
        final top = p00 + (p10 - p00) * fx;
        final bottom = p01 + (p11 - p01) * fx;
        out[o + c] = (top + (bottom - top) * fy).round();
      }
    }
  }
  return RgbaImage(side, side, out);
}

/// Maps crop-pixel coordinates (0..256) of an [alignedCrop] back to the
/// source raster.
(double, double) cropToSource(double u, double v, double cx, double cy, double size, double rollDeg) {
  final a = rollDeg * math.pi / 180;
  final ca = math.cos(a);
  final sa = math.sin(a);
  final k = size / 256;
  final lx = u * k - size / 2;
  final ly = v * k - size / 2;
  return (cx + lx * ca - ly * sa, cy + lx * sa + ly * ca);
}

// ---------------------------------------------------------------------------
// Tensor helpers

/// RGBA → NCHW float32 BGR 0..255 (YuNet input).
Float32List rgbaToNchwBgr255(RgbaImage img) {
  final n = img.width * img.height;
  final out = Float32List(3 * n);
  final px = img.pixels;
  for (var i = 0; i < n; i++) {
    out[i] = px[i * 4 + 2].toDouble(); // B
    out[n + i] = px[i * 4 + 1].toDouble(); // G
    out[2 * n + i] = px[i * 4].toDouble(); // R
  }
  return out;
}

/// RGBA → NHWC float32 RGB 0..1 (face landmark input [1,256,256,3]).
Float32List rgbaToNhwc01(RgbaImage img) {
  final n = img.width * img.height;
  final out = Float32List(n * 3);
  final px = img.pixels;
  for (var i = 0; i < n; i++) {
    out[i * 3] = px[i * 4] / 255;
    out[i * 3 + 1] = px[i * 4 + 1] / 255;
    out[i * 3 + 2] = px[i * 4 + 2] / 255;
  }
  return out;
}

// ---------------------------------------------------------------------------
// Mask rasterisation (pure, testable)

/// Even-odd scanline fill of [poly] into [mask] (w×h floats) with [value].
void fillPolygon(Float32List mask, int w, int h, List<(double, double)> poly, double value) {
  if (poly.length < 3) return;
  var minY = double.infinity;
  var maxY = -double.infinity;
  for (final p in poly) {
    if (p.$2 < minY) minY = p.$2;
    if (p.$2 > maxY) maxY = p.$2;
  }
  final y0 = math.max(0, minY.floor());
  final y1 = math.min(h - 1, maxY.floor());
  for (var y = y0; y <= y1; y++) {
    final yc = y + 0.5;
    final xs = <double>[];
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i];
      final b = poly[(i + 1) % poly.length];
      if ((a.$2 <= yc && b.$2 > yc) || (b.$2 <= yc && a.$2 > yc)) {
        xs.add(a.$1 + (yc - a.$2) / (b.$2 - a.$2) * (b.$1 - a.$1));
      }
    }
    if (xs.length < 2) continue;
    xs.sort();
    for (var k = 0; k + 1 < xs.length; k += 2) {
      final sx = math.max(0, xs[k].ceil());
      final ex = math.min(w - 1, xs[k + 1].floor());
      for (var x = sx; x <= ex; x++) {
        mask[y * w + x] = value;
      }
    }
  }
}

/// Scales every point of [poly] by [factor] around its centroid
/// ([factor] > 1 dilates, < 1 erodes).
List<(double, double)> scalePolygon(List<(double, double)> poly, double factor) {
  var sx = 0.0;
  var sy = 0.0;
  for (final p in poly) {
    sx += p.$1;
    sy += p.$2;
  }
  sx /= poly.length;
  sy /= poly.length;
  return [for (final p in poly) (sx + (p.$1 - sx) * factor, sy + (p.$2 - sy) * factor)];
}

List<(double, double)> _pointsOf(Float32List all, List<int> indices) =>
    [for (final i in indices) (all[i * 2], all[i * 2 + 1])];

/// Builds a soft grayscale face mask for [region] across every analysed
/// face, rasterised at ≤ [rasterSide] and bilinearly stretched to
/// [width]×[height]. Skin = the face oval minus eyes, brows and lips;
/// eyes = the eye rings dilated; teeth = the inner lip ring eroded.
RgbaImage buildFaceMask(FaceAnalysis analysis, FaceRegion region, int width, int height, {int rasterSide = 256}) {
  final k = math.min(1, rasterSide / math.max(analysis.width, analysis.height));
  final mw = math.max(2, (analysis.width * k).round());
  final mh = math.max(2, (analysis.height * k).round());
  final mask = Float32List(mw * mh);
  for (final face in analysis.faces) {
    final pts = Float32List.fromList(face.points.map((v) => v * k).toList());
    switch (region) {
      case FaceRegion.skin:
        fillPolygon(mask, mw, mh, _pointsOf(pts, kFaceOval), 1);
        for (final hole in [kEyeA, kEyeB, kBrowA, kBrowB, kLipsOuter]) {
          fillPolygon(mask, mw, mh, _pointsOf(pts, hole), 0);
        }
      case FaceRegion.eyes:
        for (final ring in [kEyeA, kEyeB]) {
          fillPolygon(mask, mw, mh, scalePolygon(_pointsOf(pts, ring), 1.8), 1);
        }
      case FaceRegion.teeth:
        fillPolygon(mask, mw, mh, scalePolygon(_pointsOf(pts, kLipsInner), 0.8), 1);
    }
  }
  final small = RgbaImage(mw, mh);
  for (var i = 0; i < mw * mh; i++) {
    final v = (mask[i].clamp(0.0, 1.0) * 255).round();
    small.pixels[i * 4] = v;
    small.pixels[i * 4 + 1] = v;
    small.pixels[i * 4 + 2] = v;
    small.pixels[i * 4 + 3] = 255;
  }
  return small.resize(width, height);
}

// ---------------------------------------------------------------------------
// Pipeline

/// Face detection (YuNet) + 478-point landmarks (MediaPipe Face
/// Landmarker) — the geometry behind face-aware retouch (v1.4 "Faces").
/// Everything runs on device: detection on a 640×640 stretch of the photo,
/// then one landmark pass per face on a rotated square crop. ~5 MB of
/// models, ~30 ms per face on two x86 cores.
class FacePipeline {
  FacePipeline(this.engine);
  final InferenceEngine engine;

  static const detectorSide = 640;
  static const meshSide = 256;
  static const scoreThreshold = 0.5;
  static const presenceThreshold = 0.5;

  String? _path;
  FaceAnalysis? _cached;

  /// Detects every face and runs the landmark mesh on it. Results are
  /// cached per path (like [DepthPipeline]). Throws [AiException] with
  /// [AiErrorKind.inference] when a graph returns an unexpected shape.
  Future<FaceAnalysis> analyze(String imagePath) async {
    final hit = _cached;
    if (hit != null && _path == imagePath) return hit;
    final src = await loadRgba(imagePath, maxSide: 2048);
    final det = src.resize(detectorSide, detectorSide);
    final detInput = await Isolate.run(() => rgbaToNchwBgr255(det));
    const spec = ModelRegistry.yunetFaceDetect;
    final detOut = await engine.runAll(spec, {
      spec.inputNames.first: (detInput, [1, 3, detectorSide, detectorSide]),
    });
    final raw = decodeYunet(detOut, detectorSide, detectorSide);
    final kx = src.width / detectorSide;
    final ky = src.height / detectorSide;
    final faces = <FaceGeometry>[];
    for (final r in raw) {
      final d = _scaleDetection(r, kx, ky);
      final mesh = await _meshFace(src, d);
      if (mesh != null) faces.add(mesh);
    }
    _path = imagePath;
    return _cached = FaceAnalysis(faces, src.width, src.height);
  }

  /// Builds and encodes the region mask at the raster's size.
  Future<String> maskPath(FaceAnalysis analysis, FaceRegion region) async {
    final mask = buildFaceMask(analysis, region, analysis.width, analysis.height);
    return savePng(mask, 'face_${region.name}');
  }

  FaceDetection _scaleDetection(RawFace r, double kx, double ky) {
    final kp = Float32List(10);
    for (var k = 0; k < 10; k++) {
      kp[k] = r.kps[k] * (k.isEven ? kx : ky);
    }
    return FaceDetection(r.x * kx, r.y * ky, r.w * kx, r.h * ky, r.score, kp);
  }

  /// One landmark pass per face; `null` when the mesh rejects the crop
  /// (presence ≤ 0.5 — occluded or no complete face).
  Future<FaceGeometry?> _meshFace(RgbaImage src, FaceDetection d) async {
    final roll = _eyeRoll(d.keypoints);
    final cx = d.x + d.width / 2;
    final cy = d.y + d.height / 2;
    final size = math.max(d.width, d.height);
    final crop = alignedCrop(src, cx, cy, size, roll);
    final input = await Isolate.run(() => rgbaToNhwc01(crop));
    const spec = ModelRegistry.faceLandmarks478;
    final out = await engine.runAll(spec, {
      spec.inputNames.first: (input, [1, meshSide, meshSide, 3]),
    });
    final flat = out[spec.outputName]!;
    if (flat.length != 478 * 3) {
      throw AiException(AiErrorKind.inference, model: spec, detail: 'unexpected mesh size ${flat.length}');
    }
    // Identity_1 is the presence *logit*; sigmoid it and gate on 0.5.
    final logit = out['Identity_1']!.first.toDouble().clamp(-30.0, 30.0);
    final presence = 1 / (1 + math.exp(-logit));
    if (presence <= presenceThreshold) return null;
    final points = Float32List(478 * 2);
    for (var i = 0; i < 478; i++) {
      final (px, py) = cropToSource(flat[i * 3].toDouble(), flat[i * 3 + 1].toDouble(), cx, cy, size, roll);
      points[i * 2] = px;
      points[i * 2 + 1] = py;
    }
    return FaceGeometry(points, presence, d);
  }

  /// Rotation that levels the eye line (YuNet keypoints: right eye, left
  /// eye, nose, right mouth, left mouth).
  static double _eyeRoll(Float32List keypoints) {
    final rx = keypoints[0];
    final ry = keypoints[1];
    final lx = keypoints[2];
    final ly = keypoints[3];
    return math.atan2(ly - ry, lx - rx) * 180 / math.pi;
  }
}
