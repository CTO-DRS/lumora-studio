import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/photo_editor/engine/low_light.dart';

/// A2: low-light tuning against PSNR/SSIM fixtures.
///
/// A synthetic "ground truth" night scene (gradient sky, hard building
/// edge, moon disc, fine texture patch) is degraded deterministically:
/// darkened toward mean luma ~0.1, then Gaussian luma + chroma noise.
/// The rescue must move the result measurably closer to the clean scene,
/// not just brighter: PSNR and SSIM against the original both improve.

const int _w = 96;
const int _h = 72;

/// Clean, well-exposed scene with edges, a smooth area and fine texture.
Uint8List _cleanScene() {
  final out = Uint8List(_w * _h * 4);
  for (var y = 0; y < _h; y++) {
    for (var x = 0; x < _w; x++) {
      final o = (y * _w + x) * 4;
      // Sky gradient with a warm horizon.
      var r = 0.25 + 0.35 * (y / _h);
      var g = 0.30 + 0.25 * (y / _h);
      var b = 0.45 - 0.15 * (y / _h);
      // Building: darker block with a hard vertical edge at x = 60.
      if (x >= 60 && y >= 30) {
        r = 0.16;
        g = 0.15;
        b = 0.18;
      }
      // Moon disc.
      final d = math.sqrt(math.pow(x - 22, 2) + math.pow(y - 16, 2));
      if (d < 7) {
        r = g = b = 0.92 - d * 0.03;
      }
      // Texture patch: high-frequency checkerboard, low amplitude.
      if (x >= 10 && x < 30 && y >= 45 && y < 65) {
        final t = ((x + y).isEven ? 1 : -1) * 0.05;
        r += t;
        g += t;
        b += t;
      }
      out[o] = (r.clamp(0.0, 1.0) * 255).round();
      out[o + 1] = (g.clamp(0.0, 1.0) * 255).round();
      out[o + 2] = (b.clamp(0.0, 1.0) * 255).round();
      out[o + 3] = 255;
    }
  }
  return out;
}

/// Darken + add seeded Gaussian noise (Box-Muller), the "captured" frame.
Uint8List _degrade(Uint8List clean, {int seed = 11, double darken = 0.18, double sigma = 0.025}) {
  final rnd = math.Random(seed);
  final out = Uint8List(clean.length);
  for (var i = 0; i < clean.length ~/ 4; i++) {
    final o = i * 4;
    for (var c = 0; c < 3; c++) {
      final v = clean[o + c] / 255 * darken;
      final u1 = math.max(rnd.nextDouble(), 1e-9);
      final u2 = rnd.nextDouble();
      final n = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2) * sigma;
      out[o + c] = ((v + n).clamp(0.0, 1.0) * 255).round();
    }
    out[o + 3] = clean[o + 3];
  }
  return out;
}

/// PSNR in dB over RGB (higher = closer). Identical inputs give 99.
double psnr(Uint8List a, Uint8List b) {
  var se = 0.0;
  var c = 0;
  for (var i = 0; i < a.length ~/ 4; i++) {
    for (var ch = 0; ch < 3; ch++) {
      final d = a[i * 4 + ch] - b[i * 4 + ch];
      se += d * d;
      c++;
    }
  }
  final mse = se / c;
  if (mse < 1e-9) return 99;
  return 10 * math.log(255 * 255 / mse) / math.ln10;
}

/// Global SSIM over the luma plane (single-window Wang et al. variant).
double ssim(Uint8List a, Uint8List b) {
  final n = a.length ~/ 4;
  double luma(Uint8List d, int i) => 0.299 * d[i * 4] + 0.587 * d[i * 4 + 1] + 0.114 * d[i * 4 + 2];
  var ma = 0.0;
  var mb = 0.0;
  for (var i = 0; i < n; i++) {
    ma += luma(a, i);
    mb += luma(b, i);
  }
  ma /= n;
  mb /= n;
  var va = 0.0;
  var vb = 0.0;
  var cov = 0.0;
  for (var i = 0; i < n; i++) {
    final da = luma(a, i) - ma;
    final db = luma(b, i) - mb;
    va += da * da;
    vb += db * db;
    cov += da * db;
  }
  va /= n;
  vb /= n;
  cov /= n;
  const c1 = 6.5025; // (0.01 * 255)^2
  const c2 = 58.5225; // (0.03 * 255)^2
  return ((2 * ma * mb + c1) * (2 * cov + c2)) / ((ma * ma + mb * mb + c1) * (va + vb + c2));
}

void main() {
  late Uint8List clean;
  late Uint8List dark;
  setUp(() {
    clean = _cleanScene();
    dark = _degrade(clean);
  });

  test('fixture: the degraded frame is dark, noisy and far from the original', () {
    expect(looksUnderexposed(dark), isTrue);
    expect(psnr(dark, clean), lessThan(16));
    expect(ssim(dark, clean), lessThan(0.75));
  });

  test('rescue improves PSNR against the ground truth, not just brightness', () {
    final rescued = lowLightRescue(dark, _w, _h);
    final before = psnr(dark, clean);
    final after = psnr(rescued, clean);
    expect(after, greaterThan(before + 2)); // at least +2 dB closer
  });

  test('rescue improves SSIM: structure survives the lift and denoise', () {
    final rescued = lowLightRescue(dark, _w, _h);
    final before = ssim(dark, clean);
    final after = ssim(rescued, clean);
    expect(after, greaterThan(before + 0.05));
  });

  test('denoise earns its keep: preserving zero detail beats max detail on noise', () {
    final smooth = lowLightRescue(dark, _w, _h, params: const LowLightParams(preserveDetail: 0.1));
    final gritty = lowLightRescue(dark, _w, _h, params: const LowLightParams(preserveDetail: 0.95));
    expect(psnr(smooth, clean), greaterThan(psnr(gritty, clean)));
  });

  test('default params are within 0.5 dB of the best grid point on this fixture', () {
    final grid = <double>[0.3, 0.5, 0.7, 0.9];
    var best = 0.0;
    for (final s in grid) {
      for (final d in grid) {
        for (final c in grid) {
          final out = lowLightRescue(
            dark,
            _w,
            _h,
            params: LowLightParams(strength: s, preserveDetail: d, colourNoise: c),
          );
          final p = psnr(out, clean);
          if (p > best) best = p;
        }
      }
    }
    final fallback = psnr(lowLightRescue(dark, _w, _h), clean);
    expect(fallback, greaterThan(best - 0.5));
  });

  test('no colour cast: rescued chroma tracks the ground truth with no bias', () {
    final rescued = lowLightRescue(dark, _w, _h);
    double driftOf(Uint8List img, {required bool signed}) {
      var d = 0.0;
      for (var i = 0; i < _w * _h; i++) {
        final o = i * 4;
        // Signed B-G difference as a cheap cast probe.
        final v = (img[o + 2] - img[o + 1]) - (clean[o + 2] - clean[o + 1]);
        d += signed ? v : v.abs();
      }
      return d / (_w * _h);
    }

    // No systematic cast: the signed drift stays within ~3% of the lifted
    // mean level (the lift multiplies any residual cast by its gain) ...
    final bias = driftOf(rescued, signed: true).abs() / (meanLuma(rescued) * 255);
    expect(bias, lessThan(0.035));
    // ... and the absolute drift is below the noisy capture's own drift.
    expect(driftOf(rescued, signed: false), lessThan(driftOf(dark, signed: false)));
  });
}
