import 'dart:math' as math;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'geometry.freezed.dart';
part 'geometry.g.dart';

/// Non-destructive geometry: crop rect (normalized to the rotated,
/// straightened image), 90° turns, fine straighten angle, flips and
/// perspective keystone correction.
@freezed
abstract class GeometryState with _$GeometryState {
  const factory GeometryState({
    @Default(0) double cropLeft,
    @Default(0) double cropTop,
    @Default(1) double cropRight,
    @Default(1) double cropBottom,
    @Default(0) int quarterTurns,
    @Default(0) double straightenDegrees,
    @Default(false) bool flipHorizontal,
    @Default(false) bool flipVertical,
    @Default(0) double perspectiveVertical,
    @Default(0) double perspectiveHorizontal,
    double? aspectRatio,
  }) = _GeometryState;

  const GeometryState._();

  factory GeometryState.fromJson(Map<String, dynamic> json) => _$GeometryStateFromJson(json);

  bool get isIdentity =>
      cropLeft == 0 &&
      cropTop == 0 &&
      cropRight == 1 &&
      cropBottom == 1 &&
      quarterTurns % 4 == 0 &&
      straightenDegrees == 0 &&
      !flipHorizontal &&
      !flipVertical &&
      perspectiveVertical == 0 &&
      perspectiveHorizontal == 0;

  GeometryState withoutCrop() => copyWith(cropLeft: 0, cropTop: 0, cropRight: 1, cropBottom: 1);

  /// Size of the rotated frame (before crop) for a source of [w]x[h].
  (double, double) rotatedSize(double w, double h) => quarterTurns.isOdd ? (h, w) : (w, h);

  /// Output pixel size for a source of [srcW]x[srcH].
  (int, int) outputSize(int srcW, int srcH) {
    final (rw, rh) = rotatedSize(srcW.toDouble(), srcH.toDouble());
    final w = math.max(1, ((cropRight - cropLeft) * rw).round());
    final h = math.max(1, ((cropBottom - cropTop) * rh).round());
    return (w, h);
  }
}

/// Row-major 3x3 matrix.
class Mat3 {
  const Mat3(this.m);

  factory Mat3.identity() => const Mat3([1, 0, 0, 0, 1, 0, 0, 0, 1]);

  factory Mat3.translate(double x, double y) => Mat3([1, 0, x, 0, 1, y, 0, 0, 1]);

  factory Mat3.scale(double x, double y) => Mat3([x, 0, 0, 0, y, 0, 0, 0, 1]);

  factory Mat3.rotate(double radians) {
    final c = math.cos(radians);
    final s = math.sin(radians);
    return Mat3([c, -s, 0, s, c, 0, 0, 0, 1]);
  }

  final List<double> m;

  Mat3 operator *(Mat3 o) {
    final r = List<double>.filled(9, 0);
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        var s = 0.0;
        for (var k = 0; k < 3; k++) {
          s += m[i * 3 + k] * o.m[k * 3 + j];
        }
        r[i * 3 + j] = s;
      }
    }
    return Mat3(r);
  }

  (double, double) apply(double x, double y) {
    final w = m[6] * x + m[7] * y + m[8];
    return ((m[0] * x + m[1] * y + m[2]) / w, (m[3] * x + m[4] * y + m[5]) / w);
  }

  Mat3 inverse() {
    final a = m;
    final det =
        a[0] * (a[4] * a[8] - a[5] * a[7]) - a[1] * (a[3] * a[8] - a[5] * a[6]) + a[2] * (a[3] * a[7] - a[4] * a[6]);
    if (det.abs() < 1e-12) return Mat3.identity();
    final d = 1 / det;
    return Mat3([
      (a[4] * a[8] - a[5] * a[7]) * d,
      (a[2] * a[7] - a[1] * a[8]) * d,
      (a[1] * a[5] - a[2] * a[4]) * d,
      (a[5] * a[6] - a[3] * a[8]) * d,
      (a[0] * a[8] - a[2] * a[6]) * d,
      (a[2] * a[3] - a[0] * a[5]) * d,
      (a[3] * a[7] - a[4] * a[6]) * d,
      (a[1] * a[6] - a[0] * a[7]) * d,
      (a[0] * a[4] - a[1] * a[3]) * d,
    ]);
  }

  /// Homography mapping the unit square corners to [dst] (4 points).
  static Mat3 squareToQuad(List<(double, double)> dst) {
    final (x0, y0) = dst[0];
    final (x1, y1) = dst[1];
    final (x2, y2) = dst[2];
    final (x3, y3) = dst[3];
    final dx1 = x1 - x2;
    final dx2 = x3 - x2;
    final dx3 = x0 - x1 + x2 - x3;
    final dy1 = y1 - y2;
    final dy2 = y3 - y2;
    final dy3 = y0 - y1 + y2 - y3;
    if (dx3.abs() < 1e-12 && dy3.abs() < 1e-12) {
      return Mat3([x1 - x0, x3 - x0, x0, y1 - y0, y3 - y0, y0, 0, 0, 1]);
    }
    final den = dx1 * dy2 - dx2 * dy1;
    final g = (dx3 * dy2 - dx2 * dy3) / den;
    final h = (dx1 * dy3 - dx3 * dy1) / den;
    return Mat3([x1 - x0 + g * x1, x3 - x0 + h * x3, x0, y1 - y0 + g * y1, y3 - y0 + h * y3, y0, g, h, 1]);
  }
}

/// Builds the inverse mapping used by `warp.frag`: output pixel → source
/// normalized coordinate (0..1). [srcW]/[srcH] is the source size, and
/// [outW]/[outH] the size of the render target.
Mat3 buildInverseWarp(GeometryState g, int srcW, int srcH, int outW, int outH) {
  // 1. output px -> normalized crop space (0..1 over the cropped frame)
  final toNorm = Mat3.scale(1 / outW, 1 / outH);
  // 2. crop space -> rotated frame normalized
  final crop = Mat3.translate(g.cropLeft, g.cropTop) * Mat3.scale(g.cropRight - g.cropLeft, g.cropBottom - g.cropTop);
  // 3. rotated frame normalized -> centered rotated frame in px
  final (rw, rh) = g.rotatedSize(srcW.toDouble(), srcH.toDouble());
  final toPx = Mat3.translate(-rw / 2, -rh / 2) * Mat3.scale(rw, rh);
  // 4. undo straighten (with auto zoom so no empty corners appear)
  final theta = g.straightenDegrees * math.pi / 180;
  final zoom = _straightenZoom(rw, rh, theta);
  final straighten = Mat3.rotate(-theta) * Mat3.scale(1 / zoom, 1 / zoom);
  // 5. undo quarter turns
  final turns = Mat3.rotate(-(g.quarterTurns % 4) * math.pi / 2);
  // 6. back to source normalized
  final toSrc = Mat3.scale(1 / srcW, 1 / srcH) * Mat3.translate(srcW / 2, srcH / 2);
  // 7. flips, in source normalized space
  final flip =
      Mat3.translate(g.flipHorizontal ? 1 : 0, g.flipVertical ? 1 : 0) *
      Mat3.scale(g.flipHorizontal ? -1 : 1, g.flipVertical ? -1 : 1);
  // 8. perspective keystone: maps the corrected unit square to the
  // trapezoid that is sampled in the source.
  final keystone = _keystone(g.perspectiveHorizontal, g.perspectiveVertical);

  return keystone * flip * toSrc * turns * straighten * toPx * crop * toNorm;
}

double _straightenZoom(double w, double h, double theta) {
  if (theta == 0) return 1;
  final c = math.cos(theta).abs();
  final s = math.sin(theta).abs();
  // Scale needed so the rotated image fully covers the frame.
  return math.max((w * c + h * s) / w, (w * s + h * c) / h);
}

Mat3 _keystone(double h, double v) {
  if (h == 0 && v == 0) return Mat3.identity();
  final kv = v * 0.25;
  final kh = h * 0.25;
  // Corners: TL, TR, BR, BL of the source region to sample.
  final dst = <(double, double)>[
    (0 + kv.clamp(0, 1), 0 + kh.clamp(0, 1)),
    (1 - kv.clamp(0, 1), 0 - kh.clamp(-1, 0)),
    (1 + kv.clamp(-1, 0), 1 + kh.clamp(-1, 0)),
    (0 - kv.clamp(-1, 0), 1 - kh.clamp(0, 1)),
  ];
  // squareToQuad expects order: (0,0), (1,0), (1,1), (0,1).
  return Mat3.squareToQuad(dst);
}
