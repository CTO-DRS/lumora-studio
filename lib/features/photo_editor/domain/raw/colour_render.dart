/// Camera-neutral colour rendering for the RAW pipeline (Wave 2 W2 M2-4).
///
/// Until this milestone the DNG path treated camera-native RGB as if it
/// were sRGB — every real camera renders with a colour cast. This module
/// implements the DNG-spec colour pipeline end to end, in pure Dart:
///
/// 1. **White balance** — pixels are divided by `AsShotNeutral` (normalised
///    so its max channel is 1), which maps the shot's neutral to
///    `[1, 1, 1]` in camera space.
/// 2. **Camera → XYZ** — the inverse of `ColorMatrix1` (which the DNG spec
///    defines as mapping XYZ D50 → camera RGB), rescaled so the neutral
///    maps to `Y = 1`.
/// 3. **Chromatic adaptation** — a Bradford matrix adapts the *shot*
///    illuminant (the chromaticity of `inverse(ColorMatrix1) · neutral`)
///    to D65, so achromatic scene colours land exactly on the sRGB white.
/// 4. **XYZ D65 → linear sRGB**, then the sRGB transfer function.
///
/// Between the matrix and the gamma step, **highlight recovery** runs on
/// the linear data: pixels above a threshold get a quadratic shoulder that
/// compresses brightness instead of hard-clipping, blended toward their
/// own luminance so clipped colour fringes stay hue-neutral (the darktable
/// / LibRaw "reconstruct in luminance" idea, simplified for a first
/// milestone).
///
/// Files without colour metadata keep the legacy identity path bit-for-bit
/// (`toRgba` in dng_decoder.dart). Singular matrices, absent tags and
/// degenerate neutrals all degrade gracefully — the renderer never throws
/// on data the parser accepted (fuzz gate).
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumora/features/ai/pipelines/tensor_utils.dart' show RgbaImage;
import 'package:lumora/features/photo_editor/domain/raw/dng_decoder.dart' show DemosaicResult;

/// Parameters of the highlight-recovery shoulder.
class HighlightRecovery {
  const HighlightRecovery({this.threshold = 0.95, this.strength = 0.6});

  /// Linear level where the shoulder starts (0..1).
  final double threshold;

  /// 0 = pure clip, 1 = strongest hue-neutralising blend at full clip.
  final double strength;

  /// Applies the shoulder + luminance blend to linear planes in place and
  /// returns the clipped-pixel fraction (0..1) for diagnostics.
  ///
  /// For a pixel with `m = max(r,g,b) > threshold`: clip depth
  /// `k = (m - t) / (1 - t)`, shoulder target
  /// `m' = t + (1 - t) · (1 - (1-k)²)` (monotone, `m' → 1` as `m → 1`,
  /// never overshoots), then every channel is scaled by `m'/m` and blended
  /// toward the pixel's Rec.709 luminance with weight `w = strength · k`
  /// — white stays white, and a blown red channel loses its magenta cast
  /// gradually instead of hard-clipping.
  double apply(DemosaicResult d) {
    final t = threshold.clamp(0.0, 1.0);
    final strength = this.strength.clamp(0.0, 1.0);
    final n = d.width * d.height;
    var clipped = 0;
    for (var i = 0; i < n; i++) {
      final r = d.red[i];
      final g = d.green[i];
      final b = d.blue[i];
      final m = math.max(r, math.max(g, b));
      if (m <= t) continue;
      clipped++;
      final k = m >= 1.0 ? 1.0 : (m - t) / (1.0 - t);
      final target = t + (1.0 - t) * (1.0 - (1.0 - k) * (1.0 - k));
      final s = m > 0 ? target / m : 1.0;
      final lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
      final w = strength * k;
      final iw = 1.0 - w;
      d.red[i] = s * (iw * r + w * lum);
      d.green[i] = s * (iw * g + w * lum);
      d.blue[i] = s * (iw * b + w * lum);
    }
    return n == 0 ? 0 : clipped / n;
  }
}

/// Inverts a row-major 3×3 matrix; returns `null` when the determinant is
/// (numerically) zero — a degenerate ColorMatrix then falls back instead
/// of poisoning every pixel with infinities.
List<double>? invert3x3(List<double> m) {
  final a = m[0];
  final b = m[1];
  final c = m[2];
  final d = m[3];
  final e = m[4];
  final f = m[5];
  final g = m[6];
  final h = m[7];
  final i = m[8];
  final det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g);
  if (det.abs() < 1e-12) return null;
  final invDet = 1.0 / det;
  return [
    (e * i - f * h) * invDet, (c * h - b * i) * invDet, (b * f - c * e) * invDet,
    (f * g - d * i) * invDet, (a * i - c * g) * invDet, (c * d - a * f) * invDet,
    (d * h - e * g) * invDet, (b * g - a * h) * invDet, (a * e - b * d) * invDet,
  ];
}

/// Row-major 3×3 × row-major 3×3.
List<double> mul3x3(List<double> a, List<double> b) {
  final out = List<double>.filled(9, 0);
  for (var r = 0; r < 3; r++) {
    for (var c = 0; c < 3; c++) {
      out[r * 3 + c] =
          a[r * 3] * b[c] + a[r * 3 + 1] * b[3 + c] + a[r * 3 + 2] * b[6 + c];
    }
  }
  return out;
}

/// Row-major 3×3 × column vector.
List<double> mul3x3Vec(List<double> m, List<double> v) => [
      m[0] * v[0] + m[1] * v[1] + m[2] * v[2],
      m[3] * v[0] + m[4] * v[1] + m[5] * v[2],
      m[6] * v[0] + m[7] * v[1] + m[8] * v[2],
    ];

/// D65 white in CIE XYZ (the sRGB reference white).
const List<double> kWhiteD65Xyz = [0.95047, 1.0, 1.08883];

/// Bradford cone-response matrix (standard, Lindbloom).
const List<double> _kBradford = [
  0.8951, 0.2664, -0.1614, //
  -0.7502, 1.7135, 0.0367, //
  0.0389, -0.0685, 1.0296,
];

/// XYZ D65 → linear sRGB (sRGB matrix, Rec.709 primaries).
const List<double> _kXyzD65ToSrgb = [
  3.2404542, -1.5371385, -0.4985314, //
  -0.9692660, 1.8760108, 0.0415560, //
  0.0556434, -0.2040259, 1.0572252,
];

/// Chromaticity `x, y` of an XYZ vector (any positive scale).
(double, double) xyzChromaticity(List<double> xyz) {
  final sum = xyz[0] + xyz[1] + xyz[2];
  if (sum <= 0) return (1 / 3, 1 / 3);
  return (xyz[0] / sum, xyz[1] / sum);
}

/// Bradford chromatic-adaptation matrix mapping [srcWhiteXyz] to the D65
/// white: `M_b⁻¹ · diag(ρdst / ρsrc) · M_b`. von Kries scaling in the
/// Bradford cone space — the standard DNG/ICC adaptation. The source
/// white is Y-normalised first, so the result is invariant to the white's
/// overall scale (only chromaticity matters).
List<double> bradfordToD65(List<double> srcWhiteXyz) {
  final inv = invert3x3(_kBradford)!; // Bradford is well-conditioned.
  final y = srcWhiteXyz[1];
  final srcNorm = y.abs() < 1e-12
      ? List<double>.from(srcWhiteXyz)
      : [srcWhiteXyz[0] / y, 1.0, srcWhiteXyz[2] / y];
  final src = mul3x3Vec(_kBradford, srcNorm);
  final dst = mul3x3Vec(_kBradford, kWhiteD65Xyz); // Y = 1 already.
  final scale = <double>[
    dst[0] / src[0],
    dst[1] / src[1],
    dst[2] / src[2],
  ];
  final diag = <double>[
    scale[0], 0, 0, //
    0, scale[1], 0, //
    0, 0, scale[2],
  ];
  return mul3x3(inv, diag);
}

/// The full camera→linear-sRGB matrix for a DNG's `ColorMatrix1`.
///
/// Composition (DNG spec §D.3 + DNG SDK `dng_color_spec`):
/// 1. `B = inverse(ColorMatrix1)` — camera RGB → XYZ (D50 basis).
/// 2. Rescale so `B · [1,1,1]` has `Y = 1` (the neutral lands at Y=1).
/// 3. `A = Bradford(shot-white → D65)` where the shot-white chromaticity
///    is that of `B · [1,1,1]` — adapting the actual illuminant, not a
///    hard-coded D50, is what makes the neutral land exactly on the sRGB
///    white.
/// 4. `M = sRGB · A · B`. Returns `null` for singular inputs (caller
///    falls back to the identity path).
List<double>? cameraToSrgbLinear(List<double> colorMatrix1) {
  final b0 = invert3x3(colorMatrix1);
  if (b0 == null) return null;
  final neutralXyz = mul3x3Vec(b0, [1.0, 1.0, 1.0]);
  if (neutralXyz[1].abs() < 1e-9) return null;
  final yScale = 1.0 / neutralXyz[1];
  final b = [
    for (final v in b0) v * yScale,
  ];
  final adaptation = bradfordToD65(neutralXyz);
  return mul3x3(_kXyzD65ToSrgb, mul3x3(adaptation, b));
}

/// sRGB transfer function (linear 0..1 → encoded 0..1).
double srgbEncode(double v) {
  if (v <= 0.0031308) return 12.92 * v;
  return 1.055 * math.pow(v, 1 / 2.4).toDouble() - 0.055;
}

int _srgb8(double v) => (255 * srgbEncode(v.clamp(0.0, 1.0))).round().clamp(0, 255);

/// Renders demosaiced linear camera RGB to the editor's 8-bit sRGB RGBA
/// with the full camera-neutral pipeline.
///
/// * [asShotNeutral] — `AsShotNeutral` (3 channels) or empty to skip WB.
/// * [colorMatrix1] — nine doubles row-major, or empty/singular to skip
///   the colour matrix (the pixels then stay camera-space, legacy path).
/// * [recovery] — highlight shoulder applied after WB + matrix (pass
///   `null` to disable, e.g. for callers that only want the colour step).
RgbaImage renderRawSrgb(
  DemosaicResult d, {
  List<double>? asShotNeutral,
  List<double>? colorMatrix1,
  HighlightRecovery? recovery = const HighlightRecovery(),
}) {
  final n = d.width * d.height;

  // 1. White-balance gains: neutral → [1,1,1] in camera space. Any
  //    non-positive or non-finite channel disables that channel's gain
  //    (identity) instead of producing NaNs downstream.
  final wb = List<double>.filled(3, 1);
  if (asShotNeutral != null && asShotNeutral.length == 3) {
    final maxNeutral = asShotNeutral
        .where((v) => v.isFinite && v > 0)
        .fold<double>(0, math.max);
    if (maxNeutral > 0) {
      for (var i = 0; i < 3; i++) {
        final v = asShotNeutral[i];
        wb[i] = (v.isFinite && v > 0) ? maxNeutral / v : 1.0;
      }
    }
  }

  // 2. Colour matrix (camera WB'd RGB → linear sRGB).
  final matrix = colorMatrix1 == null || colorMatrix1.isEmpty
      ? null
      : cameraToSrgbLinear(colorMatrix1);

  // 3. Per-pixel: WB → matrix → (optional) highlight shoulder.
  final r = Float32List(n);
  final g = Float32List(n);
  final b = Float32List(n);
  for (var i = 0; i < n; i++) {
    final c0 = d.red[i] * wb[0];
    final c1 = d.green[i] * wb[1];
    final c2 = d.blue[i] * wb[2];
    if (matrix == null) {
      r[i] = c0;
      g[i] = c1;
      b[i] = c2;
    } else {
      r[i] = matrix[0] * c0 + matrix[1] * c1 + matrix[2] * c2;
      g[i] = matrix[3] * c0 + matrix[4] * c1 + matrix[5] * c2;
      b[i] = matrix[6] * c0 + matrix[7] * c1 + matrix[8] * c2;
    }
  }

  final planes = DemosaicResult(r, g, b, d.width, d.height);
  recovery?.apply(planes);

  // 4. sRGB gamma → 8-bit RGBA.
  final out = Uint8List(n * 4);
  for (var i = 0; i < n; i++) {
    out[i * 4] = _srgb8(planes.red[i]);
    out[i * 4 + 1] = _srgb8(planes.green[i]);
    out[i * 4 + 2] = _srgb8(planes.blue[i]);
    out[i * 4 + 3] = 255;
  }
  return RgbaImage(d.width, d.height, out);
}
