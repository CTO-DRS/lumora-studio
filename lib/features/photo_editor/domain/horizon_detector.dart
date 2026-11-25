import 'dart:math' as math;
import 'dart:typed_data';

/// Automatic straightening (v1.4): finds the dominant near-horizontal edge
/// (a horizon, a skyline, a wall) and returns how many degrees the content
/// is tilted.
///
/// Algorithm: per-column sub-pixel edge positions (parabolic refinement of
/// the strongest vertical luminance step), then a weighted least-squares
/// line fit with one outlier-rejection pass. Pure, isolate-ready, and runs
/// on a ≤256 px copy in well under a frame.
abstract final class HorizonDetector {
  /// Returns the tilt of the content in **degrees, y-down convention**:
  /// a horizon that falls to the right (its right end is lower on screen)
  /// is **positive**. `null` when not confident (too few strong columns or
  /// the fit is too noisy).
  ///
  /// To straighten, set `straightenDegrees = -tilt` (the warp rotates the
  /// content by +`straightenDegrees`).
  static double? detect(
    Uint8List rgba,
    int width,
    int height, {
    double maxDegrees = 10,
    double minConfidence = 0.30,
  }) {
    if (width < 16 || height < 16) return null;

    // Luminance plane.
    final lum = Float32List(width * height);
    for (var i = 0; i < width * height; i++) {
      final o = i * 4;
      lum[i] = 0.299 * rgba[o] + 0.587 * rgba[o + 1] + 0.114 * rgba[o + 2];
    }

    // Strongest vertical luminance step per column, with sub-pixel
    // refinement (3-point parabola around the derivative peak).
    final xs = <double>[];
    final ys = <double>[];
    final ws = <double>[];
    var maxStep = 0.0;
    final colStep = Float32List(width);
    final colY = Float32List(width);
    for (var x = 0; x < width; x++) {
      var best = 0.0;
      var bestY = -1;
      for (var y = 1; y < height - 1; y++) {
        final g = lum[(y + 1) * width + x] - lum[(y - 1) * width + x];
        final a = g.abs();
        if (a > best) {
          best = a;
          bestY = y;
        }
      }
      colStep[x] = best;
      colY[x] = bestY.toDouble();
      if (best > maxStep) maxStep = best;
    }
    if (maxStep < 20) return null; // no meaningful vertical contrast at all

    // Keep columns with a strong edge (≥ 25 % of the strongest) and refine
    // their position sub-pixel: y±1 gradient values around the peak.
    final gate = maxStep * 0.25;
    for (var x = 0; x < width; x++) {
      final s = colStep[x];
      if (s < gate) continue;
      final y = colY[x].toInt();
      if (y < 2 || y > height - 3) continue;
      final gPrev = lum[(y - 1) * width + x] - lum[(y - 2) * width + x];
      final g = lum[(y + 1) * width + x] - lum[(y - 1) * width + x];
      final gNext = lum[(y + 2) * width + x] - lum[y * width + x];
      // Parabola vertex offset: δ = 0.5·(p−n)/(p−2c+n) in [-0.5, 0.5].
      final denom = gPrev - 2 * g + gNext;
      var delta = 0.0;
      if (denom.abs() > 1e-6) {
        delta = (0.5 * (gPrev - gNext) / denom).clamp(-0.5, 0.5);
      }
      xs.add(x + 0.5);
      ys.add(y + delta);
      ws.add(s);
    }
    final strong = xs.length;
    if (strong < math.max(10, width * 0.15)) return null;

    // Weighted least squares y = a + b·x, two passes with outlier
    // rejection (> 2σ residuals) so foreground objects do not bend the fit.
    var b = 0.0;
    var a = 0.0;
    final keep = List<bool>.filled(strong, true);
    for (var pass = 0; pass < 2; pass++) {
      var sw = 0.0;
      var sx = 0.0;
      var sy = 0.0;
      var sxx = 0.0;
      var sxy = 0.0;
      for (var i = 0; i < strong; i++) {
        if (!keep[i]) continue;
        final wgt = ws[i];
        sw += wgt;
        sx += wgt * xs[i];
        sy += wgt * ys[i];
        sxx += wgt * xs[i] * xs[i];
        sxy += wgt * xs[i] * ys[i];
      }
      if (sw <= 0) return null;
      final denom = sw * sxx - sx * sx;
      if (denom.abs() < 1e-9) return null;
      b = (sw * sxy - sx * sy) / denom;
      a = (sy - b * sx) / sw;
      // Residuals → outliers.
      var variance = 0.0;
      var count = 0;
      for (var i = 0; i < strong; i++) {
        if (!keep[i]) continue;
        final r = ys[i] - (a + b * xs[i]);
        variance += r * r;
        count++;
      }
      if (count < 8) return null;
      final sigma = math.sqrt(variance / count);
      var changed = false;
      for (var i = 0; i < strong; i++) {
        if (!keep[i]) continue;
        final r = (ys[i] - (a + b * xs[i])).abs();
        keep[i] = r <= 2.0 * math.max(sigma, 0.5);
        if (!keep[i]) changed = true;
      }
      if (!changed) break;
    }

    final kept = keep.where((k) => k).length;
    final confidence = kept / width;
    if (confidence < minConfidence) return null;
    // The inliers must actually form a LINE: residual spread far larger
    // than a few pixels means the columns are just random texture.
    var variance = 0.0;
    for (var i = 0; i < strong; i++) {
      if (!keep[i]) continue;
      final r = ys[i] - (a + b * xs[i]);
      variance += r * r;
    }
    final sigma = math.sqrt(variance / math.max(1, kept));
    if (sigma > height * 0.12) return null;
    final tilt = math.atan(b) * 180 / math.pi;
    if (tilt.abs() > maxDegrees * 1.5) return null; // not a near-horizontal edge
    if (tilt.abs() < 0.25) return 0; // already level
    return tilt;
  }
}
