import 'dart:math' as math;

import 'package:lumora/features/photo_editor/engine/pixel_ops.dart';

/// Enhancement applied to a flattened page.
enum ScanFilter {
  /// Colours as photographed.
  original,

  /// Shadows and uneven light removed, paper made white, colours boosted.
  magicColor,

  /// Shadows removed, kept in colour without boosting.
  noShadow,

  /// Clean greyscale.
  grayscale,

  /// Crisp black ink on white paper (adaptive threshold).
  blackWhite,
}

/// Estimates the paper / illumination colour at every pixel: a low-res max
/// filter (which removes ink strokes) followed by a blur, sampled back up.
Rgba estimateBackground(Rgba src) {
  final small = downscaleBox(src, 96);
  final dilated = Rgba(small.width, small.height);
  const r = 2;
  for (var y = 0; y < small.height; y++) {
    for (var x = 0; x < small.width; x++) {
      var mr = 0;
      var mg = 0;
      var mb = 0;
      for (var dy = -r; dy <= r; dy++) {
        final yy = (y + dy).clamp(0, small.height - 1);
        for (var dx = -r; dx <= r; dx++) {
          final o = small.offset((x + dx).clamp(0, small.width - 1), yy);
          mr = math.max(mr, small.data[o]);
          mg = math.max(mg, small.data[o + 1]);
          mb = math.max(mb, small.data[o + 2]);
        }
      }
      final o = dilated.offset(x, y);
      dilated.data
        ..[o] = mr
        ..[o + 1] = mg
        ..[o + 2] = mb
        ..[o + 3] = 255;
    }
  }
  blurInPlace(dilated, 3);
  return dilated;
}

/// Applies [filter] and returns a new image.
Rgba applyScanFilter(Rgba src, ScanFilter filter) {
  if (filter == ScanFilter.original) return src;
  final bg = estimateBackground(src);
  final out = Rgba(src.width, src.height);
  final px = List<double>.filled(4, 0);
  final sx = bg.width / src.width;
  final sy = bg.height / src.height;
  double smooth(double e0, double e1, double v) {
    final t = ((v - e0) / (e1 - e0)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      bg.sample((x + 0.5) * sx - 0.5, (y + 0.5) * sy - 0.5, px);
      final o = src.offset(x, y);
      // Divide by the local paper colour → flat white paper, no shadows.
      var r = src.data[o] / math.max(px[0], 24) * 255;
      var g = src.data[o + 1] / math.max(px[1], 24) * 255;
      var b = src.data[o + 2] / math.max(px[2], 24) * 255;
      switch (filter) {
        case ScanFilter.original:
          break;
        case ScanFilter.noShadow:
          break;
        case ScanFilter.magicColor:
          // Levels (ink darker, paper pure white) + saturation boost.
          r = (r - 40) * 255 / 200;
          g = (g - 40) * 255 / 200;
          b = (b - 40) * 255 / 200;
          final l = 0.299 * r + 0.587 * g + 0.114 * b;
          r = l + (r - l) * 1.35;
          g = l + (g - l) * 1.35;
          b = l + (b - l) * 1.35;
        case ScanFilter.grayscale:
          final l = ((0.299 * r + 0.587 * g + 0.114 * b) - 30) * 255 / 215;
          r = l;
          g = l;
          b = l;
        case ScanFilter.blackWhite:
          final l = 0.299 * r + 0.587 * g + 0.114 * b;
          final v = 255 * smooth(150, 200, l);
          r = v;
          g = v;
          b = v;
      }
      out.data[o] = r.round().clamp(0, 255);
      out.data[o + 1] = g.round().clamp(0, 255);
      out.data[o + 2] = b.round().clamp(0, 255);
      out.data[o + 3] = 255;
    }
  }
  return out;
}
