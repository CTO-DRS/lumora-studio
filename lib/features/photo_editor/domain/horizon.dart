import 'dart:math' as math;
import 'dart:typed_data';

/// The dominant near-horizontal straight structure of a photo (usually the
/// horizon, sometimes a roof line or a table edge) and how certain the
/// detection is. Pure Dart so it runs on a small preview proxy and is
/// unit-testable without a GPU.
class HorizonResult {
  const HorizonResult({required this.angleDegrees, required this.confidence});

  /// Tilt of the strongest straight, near-horizontal structure, in degrees.
  /// Positive means the structure runs downhill to the right (clockwise in
  /// image coordinates, y down).
  final double angleDegrees;

  /// 0..1 — the share of compatible edge energy that lies on the single
  /// strongest line. High for a clear horizon, low for cluttered or
  /// structure-less images.
  final double confidence;

  /// Degrees to feed `GeometryState.straightenDegrees` so the structure
  /// becomes level, clamped to the straighten slider range.
  double get correctionDegrees => (-angleDegrees).clamp(-45.0, 45.0);

  /// Whether the detection is confident enough to act on. (Whether the
  /// angle itself is worth applying — |angle| ≥ 0.1° — is decided by the
  /// caller, so a perfectly level photo still yields a usable result.)
  bool get isUsable => confidence >= kHorizonMinConfidence;
}

/// Minimum confidence for an auto-straighten to be applied automatically.
const double kHorizonMinConfidence = 0.10;

/// Working proxy size (longest side). Detection runs on a downscaled copy;
/// 224 px keeps a 5° tilt across the full width ~20 px tall — enough for
/// sub-degree precision while staying fast on low-end phones.
const int _maxSide = 224;

/// Detects the tilt of the dominant near-horizontal structure in [rgba]
/// (straight-alpha RGBA, [width]×[height]).
///
/// Method: Sobel edges, keeping only pixels whose gradient is far from
/// horizontal (a horizon's gradient is near-vertical; building edges are
/// excluded) → a coarse-to-fine 1-D Hough over candidate tilts: for each
/// angle θ the perpendicular offsets ρ = −x·sin θ + y·cos θ are binned and
/// the angle that concentrates the most edge energy in one line wins.
///
/// Note the angle comes from the *positions* of the edge pixels, not from
/// their gradient orientations: a rasterised tilted boundary has
/// axis-biased per-pixel gradients, so only the Hough over ρ recovers the
/// true tilt.
HorizonResult detectHorizon(Uint8List rgba, int width, int height, {double maxDegrees = 15}) {
  if (width < 8 || height < 8) return const HorizonResult(angleDegrees: 0, confidence: 0);

  // 1. Box-downscaled luma.
  final step = math.max(1, (math.max(width, height) / _maxSide).ceil());
  final w = width ~/ step;
  final h = height ~/ step;
  // Below ~32 px a "horizon" is not meaningful; bail out.
  if (w < 32 || h < 32) return const HorizonResult(angleDegrees: 0, confidence: 0);
  final luma = Float32List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var sr = 0;
      var sg = 0;
      var sb = 0;
      var n = 0;
      for (var dy = 0; dy < step; dy++) {
        final sy = y * step + dy;
        if (sy >= height) break;
        for (var dx = 0; dx < step; dx++) {
          final sx = x * step + dx;
          if (sx >= width) break;
          final o = (sy * width + sx) * 4;
          if (rgba[o + 3] < 16) continue; // ignore transparent pixels
          sr += rgba[o];
          sg += rgba[o + 1];
          sb += rgba[o + 2];
          n++;
        }
      }
      luma[y * w + x] = n == 0 ? 0 : (0.2126 * sr + 0.7152 * sg + 0.0722 * sb) / (255 * n);
    }
  }

  // 2. Sobel gradients and edge magnitude (interior only).
  final gx = Float32List(w * h);
  final gy = Float32List(w * h);
  final mag = Float32List(w * h);
  var maxMag = 0.0;
  var sumMag = 0.0;
  var sumSq = 0.0;
  var count = 0;
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final i = y * w + x;
      final tl = luma[i - w - 1];
      final t = luma[i - w];
      final tr = luma[i - w + 1];
      final l = luma[i - 1];
      final r = luma[i + 1];
      final bl = luma[i + w - 1];
      final b = luma[i + w];
      final br = luma[i + w + 1];
      final dx = (tr + 2 * r + br) - (tl + 2 * l + bl);
      final dy = (bl + 2 * b + br) - (tl + 2 * t + tr);
      gx[i] = dx;
      gy[i] = dy;
      final m = math.sqrt(dx * dx + dy * dy);
      mag[i] = m;
      sumMag += m;
      sumSq += m * m;
      if (m > maxMag) maxMag = m;
      count++;
    }
  }
  if (count == 0 || maxMag < 1e-6) return const HorizonResult(angleDegrees: 0, confidence: 0);
  final mean = sumMag / count;
  final std = math.sqrt(math.max(0.0, sumSq / count - mean * mean));
  final threshold = math.max(mean + 1.0 * std, 0.12 * maxMag);

  // 3. Keep strong edges whose gradient is far from horizontal: a horizon
  // boundary has a near-vertical gradient, while vertical structures
  // (walls, poles) have a near-horizontal one and must not vote.
  final maxRad = (maxDegrees + 2.5) * math.pi / 180;
  final xs = <int>[];
  final ys = <int>[];
  final weights = <double>[];
  var totalEnergy = 0.0;
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final i = y * w + x;
      final m = mag[i];
      if (m < threshold) continue;
      var theta = math.atan2(-gx[i], gy[i]); // line angle: perpendicular to the gradient
      if (theta > math.pi / 2) theta -= math.pi;
      if (theta < -math.pi / 2) theta += math.pi;
      if (theta.abs() > maxRad) continue;
      xs.add(x);
      ys.add(y);
      weights.add(m);
      totalEnergy += m;
    }
  }
  if (totalEnergy < 1e-9 || xs.isEmpty) return const HorizonResult(angleDegrees: 0, confidence: 0);

  // 4. Coarse pass: score every candidate tilt, keep the winner. Ties go
  // to the angle closest to zero — a level photo must not pick up a
  // spurious rotation just because the scan started on the negative side.
  const coarseStep = 0.5 * math.pi / 180;
  var bestAngle = 0.0;
  var bestScore = -1.0;
  for (var a = -maxRad; a <= maxRad + 1e-9; a += coarseStep) {
    final score = _lineScore(xs, ys, weights, a);
    if (_better(score, a, bestScore, bestAngle)) {
      bestScore = score;
      bestAngle = a;
    }
  }

  // 5. Fine pass on a fixed grid around the coarse winner (sub-degree
  // precision). The grid is fixed — a greedy walk would drift on the
  // noisy score landscape.
  const fineStep = 0.125 * math.pi / 180;
  final coarseAngle = bestAngle;
  for (var k = -8; k <= 8; k++) {
    final a = coarseAngle + k * fineStep;
    if (a.abs() > maxRad) continue;
    final score = _lineScore(xs, ys, weights, a);
    if (_better(score, a, bestScore, bestAngle)) {
      bestScore = score;
      bestAngle = a;
    }
  }

  return HorizonResult(angleDegrees: bestAngle * 180 / math.pi, confidence: (bestScore / totalEnergy).clamp(0.0, 1.0));
}

/// Strictly better score for the Hough argmax; when scores are equal (or
/// differ by float noise only) the angle closest to zero wins.
bool _better(double score, double a, double bestScore, double bestAngle) {
  if (score > bestScore * 1.000001) return true;
  if (score >= bestScore * 0.999999 && a.abs() < bestAngle.abs()) return true;
  return false;
}

/// Edge energy concentrated in the strongest 3-bin ρ window for tilt [a],
/// where ρ = −x·sin a + y·cos a is the perpendicular offset of an edge
/// pixel from the image origin. Pixels on one straight line share ρ, so a
/// real horizon peaks hard at its own tilt while clutter spreads out.
double _lineScore(List<int> xs, List<int> ys, List<double> weights, double a) {
  final sin = math.sin(a);
  final cos = math.cos(a);
  final rho = <int, double>{};
  for (var i = 0; i < xs.length; i++) {
    final r = (-xs[i] * sin + ys[i] * cos).round();
    rho[r] = (rho[r] ?? 0) + weights[i];
  }
  var best = 0.0;
  for (final k in rho.keys) {
    final s = (rho[k] ?? 0) + (rho[k - 1] ?? 0) + (rho[k + 1] ?? 0);
    if (s > best) best = s;
  }
  return best;
}
