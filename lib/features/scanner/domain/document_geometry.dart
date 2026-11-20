import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show immutable;
import 'package:lumora/features/photo_editor/engine/pixel_ops.dart';

/// A point in normalised (0..1) or pixel coordinates.
@immutable
class Pt {
  const Pt(this.x, this.y);

  static const zero = Pt(0, 0);

  final double x;
  final double y;

  Pt operator -(Pt o) => Pt(x - o.x, y - o.y);
  Pt operator +(Pt o) => Pt(x + o.x, y + o.y);
  Pt scale(double sx, double sy) => Pt(x * sx, y * sy);
  double distanceTo(Pt o) => math.sqrt((x - o.x) * (x - o.x) + (y - o.y) * (y - o.y));

  @override
  bool operator ==(Object other) => other is Pt && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Pt(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)})';

  List<double> toJson() => [x, y];
}

/// Document corners in clockwise order starting top-left.
@immutable
class Quad {
  const Quad(this.topLeft, this.topRight, this.bottomRight, this.bottomLeft);

  /// The whole frame (normalised).
  static const full = Quad(Pt(0, 0), Pt(1, 0), Pt(1, 1), Pt(0, 1));

  /// Slightly inset frame, the fallback when nothing is detected.
  static const inset = Quad(Pt(0.05, 0.05), Pt(0.95, 0.05), Pt(0.95, 0.95), Pt(0.05, 0.95));

  final Pt topLeft;
  final Pt topRight;
  final Pt bottomRight;
  final Pt bottomLeft;

  List<Pt> get points => [topLeft, topRight, bottomRight, bottomLeft];

  Quad scale(double sx, double sy) =>
      Quad(topLeft.scale(sx, sy), topRight.scale(sx, sy), bottomRight.scale(sx, sy), bottomLeft.scale(sx, sy));

  Quad withPoint(int index, Pt p) {
    final pts = [...points]..[index] = p;
    return Quad(pts[0], pts[1], pts[2], pts[3]);
  }

  /// Shoelace area (absolute).
  double get area => polygonArea(points);

  /// Rotates the corner labels by a quarter turn clockwise (for a page
  /// rotated by 90°).
  Quad rotatedLabels() => Quad(bottomLeft, topLeft, topRight, bottomRight);

  /// Whether the polygon is convex (a usable document outline).
  bool get isConvex {
    final p = points;
    var sign = 0;
    for (var i = 0; i < 4; i++) {
      final a = p[i];
      final b = p[(i + 1) % 4];
      final c = p[(i + 2) % 4];
      final cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x);
      if (cross.abs() < 1e-12) continue;
      final s = cross > 0 ? 1 : -1;
      if (sign == 0) {
        sign = s;
      } else if (s != sign) {
        return false;
      }
    }
    return true;
  }

  List<List<double>> toJson() => [for (final p in points) p.toJson()];

  static Quad fromJson(List<dynamic> json) {
    Pt pt(dynamic v) => Pt(((v as List)[0] as num).toDouble(), (v[1] as num).toDouble());
    return Quad(pt(json[0]), pt(json[1]), pt(json[2]), pt(json[3]));
  }

  /// Orders arbitrary corners as TL, TR, BR, BL.
  static Quad fromUnordered(List<Pt> pts) {
    assert(pts.length == 4, 'need four corners');
    final cx = pts.fold<double>(0, (s, p) => s + p.x) / 4;
    final cy = pts.fold<double>(0, (s, p) => s + p.y) / 4;
    final sorted = [...pts]..sort((a, b) => math.atan2(a.y - cy, a.x - cx).compareTo(math.atan2(b.y - cy, b.x - cx)));
    // atan2 order starting at -π is: top-left, top-right, bottom-right, bottom-left
    // in screen coordinates (y down) once rotated to start at the TL corner.
    var start = 0;
    var best = double.infinity;
    for (var i = 0; i < 4; i++) {
      final s = sorted[i].x + sorted[i].y;
      if (s < best) {
        best = s;
        start = i;
      }
    }
    final o = [for (var i = 0; i < 4; i++) sorted[(start + i) % 4]];
    return Quad(o[0], o[1], o[2], o[3]);
  }

  @override
  bool operator ==(Object other) =>
      other is Quad &&
      other.topLeft == topLeft &&
      other.topRight == topRight &&
      other.bottomRight == bottomRight &&
      other.bottomLeft == bottomLeft;

  @override
  int get hashCode => Object.hash(topLeft, topRight, bottomRight, bottomLeft);
}

double polygonArea(List<Pt> p) {
  var s = 0.0;
  for (var i = 0; i < p.length; i++) {
    final a = p[i];
    final b = p[(i + 1) % p.length];
    s += a.x * b.y - b.x * a.y;
  }
  return s.abs() / 2;
}

/// Projective transform (3×3, row-major, h33 = 1).
class Homography {
  const Homography(this.m);
  final List<double> m;

  (double, double) apply(double x, double y) {
    final w = m[6] * x + m[7] * y + m[8];
    return ((m[0] * x + m[1] * y + m[2]) / w, (m[3] * x + m[4] * y + m[5]) / w);
  }

  /// Maps the four [from] points onto the four [to] points.
  static Homography solve(List<Pt> from, List<Pt> to) {
    final a = List.generate(8, (_) => List<double>.filled(9, 0));
    for (var i = 0; i < 4; i++) {
      final (x, y) = (from[i].x, from[i].y);
      final (u, v) = (to[i].x, to[i].y);
      a[2 * i] = [x, y, 1, 0, 0, 0, -u * x, -u * y, u];
      a[2 * i + 1] = [0, 0, 0, x, y, 1, -v * x, -v * y, v];
    }
    // Gaussian elimination with partial pivoting.
    for (var col = 0; col < 8; col++) {
      var pivot = col;
      for (var r = col + 1; r < 8; r++) {
        if (a[r][col].abs() > a[pivot][col].abs()) pivot = r;
      }
      final tmp = a[col];
      a[col] = a[pivot];
      a[pivot] = tmp;
      final d = a[col][col];
      if (d.abs() < 1e-12) throw StateError('degenerate quad');
      for (var c = col; c < 9; c++) {
        a[col][c] /= d;
      }
      for (var r = 0; r < 8; r++) {
        if (r == col) continue;
        final f = a[r][col];
        if (f == 0) continue;
        for (var c = col; c < 9; c++) {
          a[r][c] -= f * a[col][c];
        }
      }
    }
    return Homography([for (var i = 0; i < 8; i++) a[i][8], 1]);
  }
}

/// Output size (pixels) for a flattened document with corners [q] given
/// in source pixels, capped to [maxSide] on the long edge.
(int, int) flattenedSize(Quad q, {int maxSide = 3508}) {
  final w = math.max(q.topLeft.distanceTo(q.topRight), q.bottomLeft.distanceTo(q.bottomRight));
  final h = math.max(q.topLeft.distanceTo(q.bottomLeft), q.topRight.distanceTo(q.bottomRight));
  final k = math.min(1, maxSide / math.max(w, h));
  return (math.max(1, (w * k).round()), math.max(1, (h * k).round()));
}

/// Perspective-corrects the document [q] (source pixels) of [src] into a
/// `outW`×`outH` image (bilinear sampling).
Rgba warpPerspective(Rgba src, Quad q, int outW, int outH) {
  final h = Homography.solve([
    Pt.zero,
    Pt(outW.toDouble(), 0),
    Pt(outW.toDouble(), outH.toDouble()),
    Pt(0, outH.toDouble()),
  ], q.points);
  final out = Rgba(outW, outH);
  final px = List<double>.filled(4, 0);
  final m = h.m;
  for (var y = 0; y < outH; y++) {
    final yc = y + 0.5;
    for (var x = 0; x < outW; x++) {
      final xc = x + 0.5;
      final w = m[6] * xc + m[7] * yc + m[8];
      final sx = (m[0] * xc + m[1] * yc + m[2]) / w - 0.5;
      final sy = (m[3] * xc + m[4] * yc + m[5]) / w - 0.5;
      src.sample(sx, sy, px);
      final o = (y * outW + x) * 4;
      out.data[o] = px[0].round();
      out.data[o + 1] = px[1].round();
      out.data[o + 2] = px[2].round();
      out.data[o + 3] = 255;
    }
  }
  return out;
}

/// Rotates an image by [quarterTurns] × 90° clockwise.
Rgba rotateQuarter(Rgba src, int quarterTurns) {
  final t = quarterTurns % 4;
  if (t == 0) return src;
  final w = src.width;
  final h = src.height;
  final out = t.isOdd ? Rgba(h, w) : Rgba(w, h);
  final d = src.data;
  final o32 = out.data.buffer.asUint32List();
  final s32 = Uint8List.fromList(d).buffer.asUint32List();
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final v = s32[y * w + x];
      switch (t) {
        case 1:
          o32[x * h + (h - 1 - y)] = v;
        case 2:
          o32[(h - 1 - y) * w + (w - 1 - x)] = v;
        default:
          o32[(w - 1 - x) * h + y] = v;
      }
    }
  }
  return out;
}
