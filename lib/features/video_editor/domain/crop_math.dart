import 'dart:math' as math;

/// Free-form crop helpers for video clips. Rects are `[l, t, r, b]`
/// normalised to the frame.

const kMinCrop = 0.08;

/// Largest centred rect of [targetAspect] (w/h, in pixels) inside a frame
/// whose own aspect is [frameAspect].
List<double> centeredCrop(double frameAspect, double targetAspect) {
  // Width as a fraction of the frame width for a full-height crop.
  final w = targetAspect / frameAspect;
  if (w <= 1) return [(1 - w) / 2, 0, (1 + w) / 2, 1];
  final h = 1 / w;
  return [0, (1 - h) / 2, 1, (1 + h) / 2];
}

/// Moves corner [corner] (0 TL, 1 TR, 2 BR, 3 BL) of [rect] by
/// ([dx], [dy]) (normalised), keeping a minimum size and, when
/// [targetAspect] is set, the aspect ratio (anchored at the opposite corner).
List<double> dragCropCorner(
  List<double> rect,
  int corner,
  double dx,
  double dy, {
  required double frameAspect,
  double? targetAspect,
}) {
  var l = rect[0];
  var t = rect[1];
  var r = rect[2];
  var b = rect[3];
  final left = corner == 0 || corner == 3;
  final top = corner == 0 || corner == 1;
  if (left) {
    l = (l + dx).clamp(0.0, r - kMinCrop);
  } else {
    r = (r + dx).clamp(l + kMinCrop, 1.0);
  }
  if (top) {
    t = (t + dy).clamp(0.0, b - kMinCrop);
  } else {
    b = (b + dy).clamp(t + kMinCrop, 1.0);
  }
  if (targetAspect != null) {
    // Height (normalised) that matches the width at this aspect.
    final wantH = (r - l) * frameAspect / targetAspect;
    if (top) {
      t = b - wantH;
      if (t < 0) {
        t = 0;
        final w = (b - t) * targetAspect / frameAspect;
        if (left) {
          l = r - w;
        } else {
          r = l + w;
        }
      }
    } else {
      b = t + wantH;
      if (b > 1) {
        b = 1;
        final w = (b - t) * targetAspect / frameAspect;
        if (left) {
          l = r - w;
        } else {
          r = l + w;
        }
      }
    }
  }
  return [l.clamp(0.0, 1.0), t.clamp(0.0, 1.0), r.clamp(0.0, 1.0), b.clamp(0.0, 1.0)];
}

/// Moves the whole [rect] by ([dx], [dy]) without leaving the frame.
List<double> moveCrop(List<double> rect, double dx, double dy) {
  final w = rect[2] - rect[0];
  final h = rect[3] - rect[1];
  final l = (rect[0] + dx).clamp(0.0, 1 - w);
  final t = (rect[1] + dy).clamp(0.0, 1 - h);
  return [l, t, l + w, t + h];
}

/// Pixel aspect ratio of [rect] in a frame of [frameAspect].
double cropAspect(List<double> rect, double frameAspect) =>
    (rect[2] - rect[0]) * frameAspect / math.max(1e-9, rect[3] - rect[1]);
