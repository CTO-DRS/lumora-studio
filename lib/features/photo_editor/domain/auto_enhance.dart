import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumora/features/photo_editor/domain/adjustments.dart';

/// Statistics gathered from an RGBA buffer (usually a small preview proxy).
class ImageStats {
  const ImageStats({
    required this.meanLuma,
    required this.lowPercentile,
    required this.highPercentile,
    required this.meanSaturation,
    required this.meanR,
    required this.meanG,
    required this.meanB,
    required this.shadowClip,
    required this.highlightClip,
  });

  /// Computes statistics, sampling at most ~65k pixels.
  factory ImageStats.fromRgba(Uint8List rgba, int width, int height) {
    final total = width * height;
    final step = math.max(1, (total / 65536).floor());
    final hist = List<int>.filled(256, 0);
    var n = 0;
    var sumL = 0.0;
    var sumS = 0.0;
    var sr = 0.0;
    var sg = 0.0;
    var sb = 0.0;
    for (var i = 0; i < total; i += step) {
      final o = i * 4;
      if (rgba[o + 3] < 16) continue; // ignore transparent pixels
      final r = rgba[o] / 255;
      final g = rgba[o + 1] / 255;
      final b = rgba[o + 2] / 255;
      final l = 0.2126 * r + 0.7152 * g + 0.0722 * b;
      hist[(l * 255).round().clamp(0, 255)]++;
      final mx = math.max(r, math.max(g, b));
      final mn = math.min(r, math.min(g, b));
      sumS += mx == 0 ? 0 : (mx - mn) / mx;
      sumL += l;
      sr += r;
      sg += g;
      sb += b;
      n++;
    }
    if (n == 0) {
      return const ImageStats(
        meanLuma: 0.5,
        lowPercentile: 0,
        highPercentile: 1,
        meanSaturation: 0.3,
        meanR: 0.5,
        meanG: 0.5,
        meanB: 0.5,
        shadowClip: 0,
        highlightClip: 0,
      );
    }
    double percentile(double p) {
      final target = n * p;
      var acc = 0;
      for (var i = 0; i < 256; i++) {
        acc += hist[i];
        if (acc >= target) return i / 255;
      }
      return 1;
    }

    final shadowClip = (hist[0] + hist[1] + hist[2]) / n;
    final highlightClip = (hist[253] + hist[254] + hist[255]) / n;
    return ImageStats(
      meanLuma: sumL / n,
      lowPercentile: percentile(0.01),
      highPercentile: percentile(0.99),
      meanSaturation: sumS / n,
      meanR: sr / n,
      meanG: sg / n,
      meanB: sb / n,
      shadowClip: shadowClip,
      highlightClip: highlightClip,
    );
  }

  final double meanLuma;
  final double lowPercentile;
  final double highPercentile;
  final double meanSaturation;
  final double meanR;
  final double meanG;
  final double meanB;
  final double shadowClip;
  final double highlightClip;
}

/// Classic "auto" algorithm: exposure from mean luminance, levels from the
/// 1st/99th percentiles, gray-world white balance and adaptive vibrance.
/// Deterministic and explainable – a good baseline that runs instantly.
Adjustments autoEnhance(ImageStats s, {Adjustments base = const Adjustments()}) {
  double clamp(double v, double lo, double hi) => v.clamp(lo, hi);

  // Exposure: bring mean luma towards 0.46 in EV (log2 ratio), damped.
  const targetLuma = 0.46;
  final ev = s.meanLuma <= 0.001 ? 1.0 : clamp(math.log(targetLuma / s.meanLuma) / math.ln2 * 0.6, -1.5, 1.5);

  // Levels: stretch the histogram ends.
  final blacks = clamp(-(s.lowPercentile - 0.02) * 3, -0.5, 0.5);
  final whites = clamp((0.98 - s.highPercentile) * 3, -0.5, 0.5);

  // Recover clipped regions.
  final highlights = clamp(-s.highlightClip * 8, -0.6, 0);
  final shadows = clamp(s.shadowClip * 8 + (s.meanLuma < 0.3 ? 0.15 : 0), 0, 0.6);

  // Gray world white balance.
  final avg = (s.meanR + s.meanG + s.meanB) / 3;
  final temperature = avg <= 0 ? 0.0 : clamp((s.meanB - s.meanR) / avg * 0.8, -0.4, 0.4);
  final tint = avg <= 0 ? 0.0 : clamp((s.meanG - (s.meanR + s.meanB) / 2) / avg * 0.8, -0.3, 0.3);

  // Vibrance: lift dull images more.
  final vibrance = clamp((0.35 - s.meanSaturation) * 1.2, -0.1, 0.4);

  // Mild contrast when the histogram is narrow.
  final range = s.highPercentile - s.lowPercentile;
  final contrast = clamp((0.85 - range) * 0.6, 0, 0.3);

  return base.copyWith(
    exposure: ev,
    blacks: blacks,
    whites: whites,
    highlights: highlights,
    shadows: shadows,
    temperature: temperature,
    tint: tint,
    vibrance: vibrance,
    contrast: contrast,
  );
}
