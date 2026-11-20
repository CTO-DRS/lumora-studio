import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumora/features/photo_editor/engine/pixel_ops.dart';

/// Healing / clone brush, model-free and fully on device.
///
/// * **Clone** copies pixels from `dest + offset` into the painted mask.
/// * **Heal** finds (or uses) a source offset, copies the texture, then
///   corrects its colour/brightness so it blends with the surroundings: the
///   difference between the destination and the source along the mask
///   border is interpolated smoothly across the mask (a membrane
///   approximation of Poisson blending, as in classic healing brushes).
class HealRequest {
  const HealRequest({required this.image, required this.mask, this.offset, this.clone = false});

  final Rgba image;

  /// One byte per pixel (0..255), same size as [image].
  final Uint8List mask;

  /// Source offset in pixels (source = destination + offset). Required for
  /// clone; found automatically for heal when null.
  final (int, int)? offset;
  final bool clone;
}

class _Box {
  _Box(this.left, this.top, this.right, this.bottom);
  int left;
  int top;
  int right;
  int bottom;
  int get width => right - left + 1;
  int get height => bottom - top + 1;
}

_Box? _maskBounds(Uint8List mask, int w, int h) {
  var l = w;
  var t = h;
  var r = -1;
  var b = -1;
  for (var y = 0; y < h; y++) {
    final row = y * w;
    for (var x = 0; x < w; x++) {
      if (mask[row + x] > 8) {
        if (x < l) l = x;
        if (x > r) r = x;
        if (y < t) t = y;
        if (y > b) b = y;
      }
    }
  }
  return r < 0 ? null : _Box(l, t, r, b);
}

/// Picks the source offset whose surrounding ring best matches the ring
/// around the mask (sum of squared differences), searching in every
/// direction at a few distances. Candidates overlapping the mask or
/// leaving the image are skipped.
(int, int)? findHealSource(Rgba img, Uint8List mask) {
  final w = img.width;
  final h = img.height;
  final box = _maskBounds(mask, w, h);
  if (box == null) return null;
  final pad = math.max(3, (math.max(box.width, box.height) * 0.15).round());
  final l = math.max(0, box.left - pad);
  final t = math.max(0, box.top - pad);
  final r = math.min(w - 1, box.right + pad);
  final b = math.min(h - 1, box.bottom + pad);
  final ring = <int>[];
  final step = math.max(1, (math.max(r - l, b - t) / 48).floor());
  for (var y = t; y <= b; y += step) {
    for (var x = l; x <= r; x += step) {
      if (mask[y * w + x] <= 8) ring.add(y * w + x);
    }
  }
  if (ring.isEmpty) return null;
  final size = math.max(box.width, box.height);
  (int, int)? best;
  var bestScore = double.infinity;
  for (final dist in [1.1, 1.5, 2.0, 2.8]) {
    final d = dist * size + pad;
    for (var a = 0; a < 24; a++) {
      final ang = a * math.pi / 12;
      final dx = (math.cos(ang) * d).round();
      final dy = (math.sin(ang) * d).round();
      if (l + dx < 0 || r + dx >= w || t + dy < 0 || b + dy >= h) continue;
      // The source window must not overlap the painted area.
      if (l + dx <= box.right && r + dx >= box.left && t + dy <= box.bottom && b + dy >= box.top) continue;
      var score = 0.0;
      for (final i in ring) {
        final x = i % w;
        final y = i ~/ w;
        final so = ((y + dy) * w + x + dx) * 4;
        final o = i * 4;
        for (var c = 0; c < 3; c++) {
          final diff = img.data[o + c] - img.data[so + c];
          score += diff * diff;
        }
        if (score > bestScore) break;
      }
      // Slightly prefer nearby sources (similar lighting).
      score *= 1 + dist * 0.05;
      if (score < bestScore) {
        bestScore = score;
        best = (dx, dy);
      }
    }
  }
  return best;
}

/// Applies the healing or clone brush and returns a new image.
Rgba applyHeal(HealRequest req) {
  final img = req.image;
  final w = img.width;
  final h = img.height;
  final mask = req.mask;
  final out = Rgba(w, h, Uint8List.fromList(img.data));
  final box = _maskBounds(mask, w, h);
  if (box == null) return out;
  final offset = req.offset ?? findHealSource(img, mask);
  if (offset == null) return out;
  final (dx, dy) = offset;

  // Border samples: unmasked pixels touching the mask, with the colour
  // difference destination − source.
  final border = <(double, double, double, double, double)>[];
  if (!req.clone) {
    final all = <(int, int)>[];
    for (var y = math.max(1, box.top - 1); y <= math.min(h - 2, box.bottom + 1); y++) {
      for (var x = math.max(1, box.left - 1); x <= math.min(w - 2, box.right + 1); x++) {
        if (mask[y * w + x] > 8) continue;
        final touches =
            mask[y * w + x - 1] > 8 ||
            mask[y * w + x + 1] > 8 ||
            mask[(y - 1) * w + x] > 8 ||
            mask[(y + 1) * w + x] > 8;
        if (touches) all.add((x, y));
      }
    }
    // Keep at most ~96 evenly spread samples.
    final stride = math.max(1, all.length ~/ 96);
    for (var i = 0; i < all.length; i += stride) {
      final (x, y) = all[i];
      final sx = (x + dx).clamp(0, w - 1);
      final sy = (y + dy).clamp(0, h - 1);
      final o = (y * w + x) * 4;
      final so = (sy * w + sx) * 4;
      border.add((
        x.toDouble(),
        y.toDouble(),
        (img.data[o] - img.data[so]).toDouble(),
        (img.data[o + 1] - img.data[so + 1]).toDouble(),
        (img.data[o + 2] - img.data[so + 2]).toDouble(),
      ));
    }
  }

  for (var y = box.top; y <= box.bottom; y++) {
    for (var x = box.left; x <= box.right; x++) {
      final m = mask[y * w + x];
      if (m <= 8) continue;
      final sx = (x + dx).clamp(0, w - 1);
      final sy = (y + dy).clamp(0, h - 1);
      final so = (sy * w + sx) * 4;
      var cr = 0.0;
      var cg = 0.0;
      var cb = 0.0;
      if (border.isNotEmpty) {
        // Inverse-distance (Shepard) interpolation of the border difference.
        var wsum = 0.0;
        for (final (bx, by, r, g, b) in border) {
          final d2 = (bx - x) * (bx - x) + (by - y) * (by - y) + 0.5;
          final wt = 1 / (d2 * d2);
          wsum += wt;
          cr += r * wt;
          cg += g * wt;
          cb += b * wt;
        }
        cr /= wsum;
        cg /= wsum;
        cb /= wsum;
      }
      final k = m / 255;
      final o = (y * w + x) * 4;
      final nr = (img.data[so] + cr).clamp(0.0, 255.0);
      final ng = (img.data[so + 1] + cg).clamp(0.0, 255.0);
      final nb = (img.data[so + 2] + cb).clamp(0.0, 255.0);
      out.data[o] = (img.data[o] + (nr - img.data[o]) * k).round();
      out.data[o + 1] = (img.data[o + 1] + (ng - img.data[o + 1]) * k).round();
      out.data[o + 2] = (img.data[o + 2] + (nb - img.data[o + 2]) * k).round();
    }
  }
  return out;
}
