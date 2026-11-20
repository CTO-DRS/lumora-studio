import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumora/features/photo_editor/engine/pixel_ops.dart';
import 'package:lumora/features/scanner/domain/document_geometry.dart';

/// Result of automatic document detection.
class DetectedDocument {
  const DetectedDocument(this.quad, this.confidence);

  /// Corners normalised to the image (0..1).
  final Quad quad;

  /// 0..1; below ~0.5 the UI suggests adjusting the corners by hand.
  final double confidence;

  bool get found => confidence > 0;
}

/// Classic, model-free document edge detection (runs in milliseconds on a
/// small proxy, no OpenCV or ML Kit):
///
/// 1. luminance + blur on a ≤ 360 px proxy,
/// 2. Otsu threshold, tried for both "paper brighter than background" and
///    the opposite,
/// 3. largest connected region (flood fill) not covering the whole frame,
/// 4. convex hull of the region's outline,
/// 5. the largest-area quadrilateral on the hull (iterative corner refine),
/// 6. scored by size and rectangularity (region area / quad area).
DetectedDocument detectDocument(Rgba image) {
  final proxy = downscaleBox(image, 360);
  final w = proxy.width;
  final h = proxy.height;
  if (w < 8 || h < 8) return const DetectedDocument(Quad.inset, 0);
  final gray = Uint8List(w * h);
  for (var i = 0; i < w * h; i++) {
    final o = i * 4;
    gray[i] = (54 * proxy.data[o] + 183 * proxy.data[o + 1] + 19 * proxy.data[o + 2]) >> 8;
  }
  final blurred = _boxBlurGray(gray, w, h, 2);
  final t = otsuThreshold(blurred);

  DetectedDocument? best;
  var bestScore = 0.0;
  for (final bright in [true, false]) {
    final mask = Uint8List(w * h);
    for (var i = 0; i < w * h; i++) {
      mask[i] = (bright ? blurred[i] > t : blurred[i] <= t) ? 1 : 0;
    }
    final region = _largestRegion(mask, w, h);
    if (region == null) continue;
    final (pixels, rowMin, rowMax) = region;
    final frac = pixels / (w * h);
    if (frac < 0.08) continue;
    final outline = <Pt>[];
    for (var y = 0; y < h; y++) {
      if (rowMin[y] <= rowMax[y]) {
        outline
          ..add(Pt(rowMin[y].toDouble(), y.toDouble()))
          ..add(Pt(rowMax[y] + 1.0, y.toDouble()));
      }
    }
    final hull = convexHull(outline);
    if (hull.length < 4) continue;
    final quad = largestQuad(hull);
    final qa = quad.area;
    if (qa <= 0) continue;
    final rect = (pixels / qa).clamp(0.0, 1.0);
    final size = qa / (w * h);
    // Regions that are really the whole frame (or background touching
    // every edge) are not documents.
    final touches = _edgesTouched(quad, w.toDouble(), h.toDouble());
    if (size > 0.985 && touches >= 4) continue;
    final score = rect * rect * math.min(1, size / 0.25) * (touches >= 3 ? 0.6 : 1);
    if (score > bestScore) {
      bestScore = score;
      best = DetectedDocument(quad.scale(1 / w, 1 / h), score.clamp(0.0, 1.0));
    }
  }
  return best ?? const DetectedDocument(Quad.inset, 0);
}

int _edgesTouched(Quad q, double w, double h) {
  const eps = 2.0;
  var n = 0;
  final pts = q.points;
  if (pts.where((p) => p.x <= eps).length >= 2) n++;
  if (pts.where((p) => p.y <= eps).length >= 2) n++;
  if (pts.where((p) => p.x >= w - eps).length >= 2) n++;
  if (pts.where((p) => p.y >= h - eps).length >= 2) n++;
  return n;
}

Uint8List _boxBlurGray(Uint8List g, int w, int h, int r) {
  final rgba = Rgba(w, h);
  for (var i = 0; i < w * h; i++) {
    rgba.data[i * 4] = g[i];
  }
  blurInPlace(rgba, r);
  return Uint8List.fromList([for (var i = 0; i < w * h; i++) rgba.data[i * 4]]);
}

/// Otsu's threshold of an 8-bit buffer.
int otsuThreshold(Uint8List values) {
  final hist = List<int>.filled(256, 0);
  for (final v in values) {
    hist[v]++;
  }
  final total = values.length;
  var sum = 0.0;
  for (var i = 0; i < 256; i++) {
    sum += i * hist[i];
  }
  var sumB = 0.0;
  var wB = 0;
  var best = 0.0;
  var threshold = 127;
  for (var t = 0; t < 256; t++) {
    wB += hist[t];
    if (wB == 0) continue;
    final wF = total - wB;
    if (wF == 0) break;
    sumB += t * hist[t];
    final mB = sumB / wB;
    final mF = (sum - sumB) / wF;
    final between = wB * wF * (mB - mF) * (mB - mF);
    if (between > best) {
      best = between;
      threshold = t;
    }
  }
  return threshold;
}

/// Largest 4-connected region of 1s: (pixel count, per-row min x, max x).
(int, Int32List, Int32List)? _largestRegion(Uint8List mask, int w, int h) {
  final labels = Int32List(w * h);
  var bestLabel = 0;
  var bestCount = 0;
  var label = 0;
  final stack = Int32List(w * h);
  for (var start = 0; start < w * h; start++) {
    if (mask[start] == 0 || labels[start] != 0) continue;
    label++;
    var sp = 0;
    stack[sp++] = start;
    labels[start] = label;
    var count = 0;
    while (sp > 0) {
      final i = stack[--sp];
      count++;
      final x = i % w;
      final y = i ~/ w;
      if (x > 0 && mask[i - 1] == 1 && labels[i - 1] == 0) {
        labels[i - 1] = label;
        stack[sp++] = i - 1;
      }
      if (x < w - 1 && mask[i + 1] == 1 && labels[i + 1] == 0) {
        labels[i + 1] = label;
        stack[sp++] = i + 1;
      }
      if (y > 0 && mask[i - w] == 1 && labels[i - w] == 0) {
        labels[i - w] = label;
        stack[sp++] = i - w;
      }
      if (y < h - 1 && mask[i + w] == 1 && labels[i + w] == 0) {
        labels[i + w] = label;
        stack[sp++] = i + w;
      }
    }
    if (count > bestCount) {
      bestCount = count;
      bestLabel = label;
    }
  }
  if (bestLabel == 0) return null;
  final rowMin = Int32List(h)..fillRange(0, h, w);
  final rowMax = Int32List(h)..fillRange(0, h, -1);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (labels[y * w + x] == bestLabel) {
        if (x < rowMin[y]) rowMin[y] = x;
        if (x > rowMax[y]) rowMax[y] = x;
      }
    }
  }
  return (bestCount, rowMin, rowMax);
}

/// Monotone-chain convex hull (counter-clockwise in y-down coordinates).
List<Pt> convexHull(List<Pt> points) {
  if (points.length < 3) return points;
  final p = [...points]..sort((a, b) => a.x != b.x ? a.x.compareTo(b.x) : a.y.compareTo(b.y));
  double cross(Pt o, Pt a, Pt b) => (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);
  final lower = <Pt>[];
  for (final pt in p) {
    while (lower.length >= 2 && cross(lower[lower.length - 2], lower.last, pt) <= 0) {
      lower.removeLast();
    }
    lower.add(pt);
  }
  final upper = <Pt>[];
  for (final pt in p.reversed) {
    while (upper.length >= 2 && cross(upper[upper.length - 2], upper.last, pt) <= 0) {
      upper.removeLast();
    }
    upper.add(pt);
  }
  return [...lower.sublist(0, lower.length - 1), ...upper.sublist(0, upper.length - 1)];
}

/// Approximates the largest-area quadrilateral with vertices on [hull]:
/// starts from the four diagonal extremes, then moves each corner along
/// the hull while the area grows.
Quad largestQuad(List<Pt> hull) {
  int argBy(double Function(Pt) f, {required bool max}) {
    var best = 0;
    for (var i = 1; i < hull.length; i++) {
      final better = max ? f(hull[i]) > f(hull[best]) : f(hull[i]) < f(hull[best]);
      if (better) best = i;
    }
    return best;
  }

  final idx = [
    argBy((p) => p.x + p.y, max: false),
    argBy((p) => p.x - p.y, max: true),
    argBy((p) => p.x + p.y, max: true),
    argBy((p) => p.x - p.y, max: false),
  ];
  double area(List<int> ix) => polygonArea([for (final i in ix) hull[i]]);
  var current = area(idx);
  for (var pass = 0; pass < 6; pass++) {
    var improved = false;
    for (var k = 0; k < 4; k++) {
      for (var i = 0; i < hull.length; i++) {
        if (idx.contains(i)) continue;
        final trial = [...idx]..[k] = i;
        final a = area(trial);
        if (a > current + 1e-9 && Quad(hull[trial[0]], hull[trial[1]], hull[trial[2]], hull[trial[3]]).isConvex) {
          current = a;
          idx[k] = i;
          improved = true;
        }
      }
    }
    if (!improved) break;
  }
  return Quad.fromUnordered([for (final i in idx) hull[i]]);
}
