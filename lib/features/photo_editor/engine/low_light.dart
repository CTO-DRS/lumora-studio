/// Low-light rescue, the model-free half of Wave 2 W5.
///
/// Pure Dart on straight-alpha RGBA bytes, isolate-safe, no Flutter:
///
/// 1. **Denoise before the lift** (so the lift never amplifies grain):
///    a 3x3 range-weighted luma filter that is strongest in the shadows
///    (`(1 - Y)^1.5`) and eased off by `preserveDetail`, plus chroma-noise
///    suppression on Cb/Cr (separable box blur, edge-guarded by the local
///    luma gradient so colour does not bleed over edges).
/// 2. **Exposure lift** with a Zero-DCE-style monotone curve
///    `LE(x) = x + a x (1 - x)`, applied 4 times; `a` is found by bisection
///    so the mean luma lands near the target. Chroma follows the lift by a
///    bounded factor so colours keep their hue (no casts) without exploding
///    the colour noise.
///
/// A learned denoiser/curve estimator (Zero-DCE++, NAFNet-lite) can replace
/// either stage later; this path is the always-available CPU floor.
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// User-facing knobs, all 0..1.
class LowLightParams {
  const LowLightParams({this.strength = 0.7, this.preserveDetail = 0.5, this.colourNoise = 0.6});

  /// How far toward the target brightness to lift, and how hard to denoise.
  final double strength;

  /// 1 keeps fine texture (weaker luma denoise); 0 smooths the most.
  final double preserveDetail;

  /// Chroma-noise suppression amount.
  final double colourNoise;
}

/// Mean luma target the lift aims for at full strength.
const double kLowLightTarget = 0.40;

/// Mean BT.601 luma of [rgba] in 0..1 (0 for an empty image).
double meanLuma(Uint8List rgba) {
  final n = rgba.length ~/ 4;
  if (n == 0) return 0;
  var sum = 0.0;
  for (var i = 0; i < n; i++) {
    final o = i * 4;
    sum += 0.299 * rgba[o] + 0.587 * rgba[o + 1] + 0.114 * rgba[o + 2];
  }
  return sum / n / 255;
}

/// True when the photo is dark enough that rescue is worth suggesting.
bool looksUnderexposed(Uint8List rgba) => meanLuma(rgba) < 0.28;

double _curve(double x, double a) {
  var v = x;
  for (var i = 0; i < 4; i++) {
    v = v + a * v * (1 - v);
  }
  return v;
}

/// The curve parameter that moves [meanY] toward [target]; 0 when already
/// bright enough.
double liftAlpha(double meanY, {double target = kLowLightTarget, double strength = 1}) {
  final goal = meanY + (target - meanY) * strength.clamp(0.0, 1.0);
  if (meanY >= goal - 1e-4) return 0;
  var lo = 0.0;
  var hi = 1.0;
  for (var i = 0; i < 24; i++) {
    final mid = (lo + hi) / 2;
    // Mean of the curve over a representative dark-skewed distribution is
    // approximated by the curve at the mean: good enough for a one-shot
    // estimate and monotone for bisection.
    if (_curve(meanY, mid) < goal) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return (lo + hi) / 2;
}

/// Returns a new RGBA buffer (same size, alpha untouched).
Uint8List lowLightRescue(Uint8List rgba, int width, int height, {LowLightParams params = const LowLightParams()}) {
  final n = width * height;
  if (width <= 0 || height <= 0 || rgba.length != n * 4) {
    throw ArgumentError('RGBA buffer does not match ${width}x$height');
  }
  final strength = params.strength.clamp(0.0, 1.0);
  final detail = params.preserveDetail.clamp(0.0, 1.0);
  final colour = params.colourNoise.clamp(0.0, 1.0);

  // --- planes (BT.601, Y 0..1, Cb/Cr -0.5..0.5) ---
  final y = Float32List(n);
  final cb = Float32List(n);
  final cr = Float32List(n);
  for (var i = 0; i < n; i++) {
    final o = i * 4;
    final r = rgba[o] / 255;
    final g = rgba[o + 1] / 255;
    final b = rgba[o + 2] / 255;
    final yy = 0.299 * r + 0.587 * g + 0.114 * b;
    y[i] = yy;
    cb[i] = (b - yy) * 0.564;
    cr[i] = (r - yy) * 0.713;
  }
  var meanY = 0.0;
  for (var i = 0; i < n; i++) {
    meanY += y[i];
  }
  meanY /= n;
  final alpha = liftAlpha(meanY, strength: strength);

  // --- luma denoise: 3x3 range-weighted, strongest in shadows ---
  final lift = alpha > 0 ? _curve(meanY, alpha) / math.max(meanY, 1e-3) : 1.0;
  final liftBoost = lift.clamp(1.0, 4.0);
  final sigma = (0.03 + 0.05 * (liftBoost - 1) / 3) * (1.2 - 0.7 * detail);
  final inv2s2 = 1 / (2 * sigma * sigma);
  final yd = Float32List.fromList(y);
  if (width >= 3 && height >= 3) {
    for (var py = 1; py < height - 1; py++) {
      for (var px = 1; px < width - 1; px++) {
        final i = py * width + px;
        final c = y[i];
        final mix = (strength * math.pow(1 - c, 1.5) * (1 - 0.6 * detail)).clamp(0.0, 1.0);
        if (mix < 0.01) continue;
        var acc = 0.0;
        var wsum = 0.0;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            final v = y[i + dy * width + dx];
            final d = v - c;
            final w = math.exp(-d * d * inv2s2) * (dx == 0 && dy == 0 ? 1.0 : 0.7);
            acc += v * w;
            wsum += w;
          }
        }
        yd[i] = c + (acc / wsum - c) * mix;
      }
    }
  }

  // --- chroma denoise: box blur guarded by the luma gradient ---
  if (colour > 0 && n > 4) {
    final radius = (2 + 4 * colour).round();
    final ys = _boxBlur(yd, width, height, radius);
    final cbs = _boxBlur(cb, width, height, radius);
    final crs = _boxBlur(cr, width, height, radius);
    for (var i = 0; i < n; i++) {
      final edge = ((yd[i] - ys[i]).abs() / 0.10).clamp(0.0, 1.0);
      final k = colour * (1 - edge);
      cb[i] += (cbs[i] - cb[i]) * k;
      cr[i] += (crs[i] - cr[i]) * k;
    }
  }

  // --- lift + reconstruct ---
  final out = Uint8List(rgba.length);
  for (var i = 0; i < n; i++) {
    final o = i * 4;
    final y0 = yd[i];
    final y1 = alpha > 0 ? _curve(y0, alpha) : y0;
    final ratio = y0 > 1e-3 ? y1 / y0 : 1.0;
    final cs = alpha > 0 ? math.sqrt(ratio).clamp(1.0, 1.6) : 1.0;
    final u = cb[i] * cs / 0.564;
    final v = cr[i] * cs / 0.713;
    final r = y1 + v;
    final b = y1 + u;
    final g = (y1 - 0.299 * r - 0.114 * b) / 0.587;
    out[o] = _to8(r);
    out[o + 1] = _to8(g);
    out[o + 2] = _to8(b);
    out[o + 3] = rgba[o + 3];
  }
  return out;
}

int _to8(double v) => (v * 255 + 0.5).clamp(0, 255).toInt();

/// Separable box blur with clamped edges, O(1) per pixel.
Float32List _boxBlur(Float32List src, int w, int h, int radius) {
  final tmp = Float32List(src.length);
  final out = Float32List(src.length);
  final r = radius.clamp(1, 64);
  final span = 2 * r + 1;
  for (var y = 0; y < h; y++) {
    final row = y * w;
    var acc = 0.0;
    for (var k = -r; k <= r; k++) {
      acc += src[row + k.clamp(0, w - 1)];
    }
    for (var x = 0; x < w; x++) {
      tmp[row + x] = acc / span;
      acc += src[row + (x + r + 1).clamp(0, w - 1)] - src[row + (x - r).clamp(0, w - 1)];
    }
  }
  for (var x = 0; x < w; x++) {
    var acc = 0.0;
    for (var k = -r; k <= r; k++) {
      acc += tmp[k.clamp(0, h - 1) * w + x];
    }
    for (var y = 0; y < h; y++) {
      out[y * w + x] = acc / span;
      acc += tmp[(y + r + 1).clamp(0, h - 1) * w + x] - tmp[(y - r).clamp(0, h - 1) * w + x];
    }
  }
  return out;
}
