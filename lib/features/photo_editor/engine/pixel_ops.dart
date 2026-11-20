import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumora/features/photo_editor/domain/finishing.dart';

/// An 8-bit straight-alpha RGBA bitmap (CPU side). Pure Dart so it can be
/// processed on background isolates and unit tested without a GPU.
class Rgba {
  Rgba(this.width, this.height, [Uint8List? data]) : data = data ?? Uint8List(width * height * 4) {
    assert(this.data.length == width * height * 4, 'RGBA buffer size mismatch');
  }

  final int width;
  final int height;
  final Uint8List data;

  int offset(int x, int y) => (y * width + x) * 4;

  void fill(int argb) {
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    final a = (argb >> 24) & 0xFF;
    for (var i = 0; i < data.length; i += 4) {
      data[i] = r;
      data[i + 1] = g;
      data[i + 2] = b;
      data[i + 3] = a;
    }
  }

  /// Bilinear sample at continuous pixel coordinates (clamped), into [out].
  void sample(double x, double y, List<double> out) {
    final fx = x.clamp(0.0, width - 1.0);
    final fy = y.clamp(0.0, height - 1.0);
    final x0 = fx.floor();
    final y0 = fy.floor();
    final x1 = math.min(x0 + 1, width - 1);
    final y1 = math.min(y0 + 1, height - 1);
    final tx = fx - x0;
    final ty = fy - y0;
    final o00 = offset(x0, y0);
    final o10 = offset(x1, y0);
    final o01 = offset(x0, y1);
    final o11 = offset(x1, y1);
    for (var c = 0; c < 4; c++) {
      final top = data[o00 + c] + (data[o10 + c] - data[o00 + c]) * tx;
      final bottom = data[o01 + c] + (data[o11 + c] - data[o01 + c]) * tx;
      out[c] = top + (bottom - top) * ty;
    }
  }
}

/// Box-averaged downscale so the longer side is at most [maxSide].
Rgba downscaleBox(Rgba src, int maxSide) {
  final k = math.min(1, maxSide / math.max(src.width, src.height));
  if (k >= 1) return Rgba(src.width, src.height, Uint8List.fromList(src.data));
  final w = math.max(1, (src.width * k).round());
  final h = math.max(1, (src.height * k).round());
  final out = Rgba(w, h);
  final sx = src.width / w;
  final sy = src.height / h;
  for (var y = 0; y < h; y++) {
    final y0 = (y * sy).floor();
    final y1 = math.max(y0 + 1, ((y + 1) * sy).floor());
    for (var x = 0; x < w; x++) {
      final x0 = (x * sx).floor();
      final x1 = math.max(x0 + 1, ((x + 1) * sx).floor());
      var r = 0;
      var g = 0;
      var b = 0;
      var a = 0;
      var n = 0;
      for (var yy = y0; yy < y1 && yy < src.height; yy++) {
        var o = src.offset(x0, yy);
        for (var xx = x0; xx < x1 && xx < src.width; xx++, o += 4) {
          r += src.data[o];
          g += src.data[o + 1];
          b += src.data[o + 2];
          a += src.data[o + 3];
          n++;
        }
      }
      final o = out.offset(x, y);
      out.data[o] = r ~/ n;
      out.data[o + 1] = g ~/ n;
      out.data[o + 2] = b ~/ n;
      out.data[o + 3] = a ~/ n;
    }
  }
  return out;
}

/// Separable box blur repeated 3× (≈ gaussian) with radius [r] pixels.
void blurInPlace(Rgba img, int r) {
  if (r < 1) return;
  final w = img.width;
  final h = img.height;
  final tmp = Uint8List(img.data.length);
  for (var pass = 0; pass < 3; pass++) {
    _boxH(img.data, tmp, w, h, r);
    _boxV(tmp, img.data, w, h, r);
  }
}

void _boxH(Uint8List src, Uint8List dst, int w, int h, int r) {
  final span = 2 * r + 1;
  for (var y = 0; y < h; y++) {
    final row = y * w * 4;
    for (var c = 0; c < 4; c++) {
      var acc = 0;
      for (var i = -r; i <= r; i++) {
        acc += src[row + i.clamp(0, w - 1) * 4 + c];
      }
      for (var x = 0; x < w; x++) {
        dst[row + x * 4 + c] = acc ~/ span;
        final add = (x + r + 1).clamp(0, w - 1);
        final sub = (x - r).clamp(0, w - 1);
        acc += src[row + add * 4 + c] - src[row + sub * 4 + c];
      }
    }
  }
}

void _boxV(Uint8List src, Uint8List dst, int w, int h, int r) {
  final span = 2 * r + 1;
  for (var x = 0; x < w; x++) {
    for (var c = 0; c < 4; c++) {
      var acc = 0;
      for (var i = -r; i <= r; i++) {
        acc += src[(i.clamp(0, h - 1) * w + x) * 4 + c];
      }
      for (var y = 0; y < h; y++) {
        dst[(y * w + x) * 4 + c] = acc ~/ span;
        final add = (y + r + 1).clamp(0, h - 1);
        final sub = (y - r).clamp(0, h - 1);
        acc += src[(add * w + x) * 4 + c] - src[(sub * w + x) * 4 + c];
      }
    }
  }
}

/// Resize to exactly [w]×[h] (box pre-filter when shrinking a lot, then
/// bilinear).
Rgba resizeBilinear(Rgba input, int w, int h) {
  var src = input;
  if (src.width > w * 2 && src.height > h * 2) {
    final k = math.max(w / src.width, h / src.height);
    src = downscaleBox(src, (math.max(src.width, src.height) * k * 2).round());
  }
  final out = Rgba(w, h);
  final px = List<double>.filled(4, 0);
  final sx = src.width / w;
  final sy = src.height / h;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      src.sample((x + 0.5) * sx - 0.5, (y + 0.5) * sy - 0.5, px);
      final o = out.offset(x, y);
      for (var c = 0; c < 4; c++) {
        out.data[o + c] = px[c].round().clamp(0, 255);
      }
    }
  }
  return out;
}

/// Center crop to the aspect ratio [aspect] (w / h).
Rgba cropToAspect(Rgba src, double aspect) {
  final current = src.width / src.height;
  var w = src.width;
  var h = src.height;
  if (current > aspect) {
    w = math.max(1, (h * aspect).round());
  } else {
    h = math.max(1, (w / aspect).round());
  }
  final x0 = (src.width - w) ~/ 2;
  final y0 = (src.height - h) ~/ 2;
  final out = Rgba(w, h);
  for (var y = 0; y < h; y++) {
    final from = src.offset(x0, y0 + y);
    out.data.setRange(y * w * 4, (y + 1) * w * 4, src.data, from);
  }
  return out;
}

/// Alpha-composites [patch] (straight alpha) onto [dst] at ([left], [top]).
void blendPatch(Rgba dst, Rgba patch, int left, int top) {
  for (var y = 0; y < patch.height; y++) {
    final dy = top + y;
    if (dy < 0 || dy >= dst.height) continue;
    for (var x = 0; x < patch.width; x++) {
      final dx = left + x;
      if (dx < 0 || dx >= dst.width) continue;
      final po = patch.offset(x, y);
      final a = patch.data[po + 3];
      if (a == 0) continue;
      final o = dst.offset(dx, dy);
      if (a == 255) {
        dst.data[o] = patch.data[po];
        dst.data[o + 1] = patch.data[po + 1];
        dst.data[o + 2] = patch.data[po + 2];
        dst.data[o + 3] = 255;
        continue;
      }
      final k = a / 255;
      final da = dst.data[o + 3] / 255;
      final outA = k + da * (1 - k);
      for (var c = 0; c < 3; c++) {
        final v = (patch.data[po + c] * k + dst.data[o + c] * da * (1 - k)) / (outA == 0 ? 1 : outA);
        dst.data[o + c] = v.round().clamp(0, 255);
      }
      dst.data[o + 3] = (outA * 255).round().clamp(0, 255);
    }
  }
}

/// Coverage (0..1) of a rounded rectangle of size [w]×[h] with corner
/// radius [r] at pixel centre ([x], [y]) relative to its top-left.
double roundedCoverage(int x, int y, int w, int h, double r) {
  if (r <= 0) return 1;
  final px = x + 0.5;
  final py = y + 0.5;
  final cx = px < r ? r : (px > w - r ? w - r : px);
  final cy = py < r ? r : (py > h - r ? h - r : py);
  if (cx == px || cy == py) return 1;
  final d = math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
  return (r - d + 0.5).clamp(0.0, 1.0);
}

/// Places [src] inside the frame described by [frame] (CPU, any size).
/// Used for full resolution export; the preview uses the same layout on
/// the GPU (see `FinishingRenderer`).
Rgba applyFrame(Rgba src, FrameSettings frame) {
  final layout = layoutFrame(src.width, src.height, frame);
  final radius = frame.cornerRadius * math.min(src.width, src.height);
  if (layout.isIdentity && radius <= 0) return src;
  final out = Rgba(layout.width, layout.height);
  if (frame.fill == FrameFill.blur && !frame.isNone) {
    // Cover-fit a blurred, low-res copy of the photo behind it.
    final small = downscaleBox(src, 96);
    blurInPlace(small, math.max(2, small.width ~/ 14));
    final k = math.max(layout.width / small.width, layout.height / small.height);
    final ox = (small.width * k - layout.width) / 2;
    final oy = (small.height * k - layout.height) / 2;
    final px = List<double>.filled(4, 0);
    for (var y = 0; y < layout.height; y++) {
      for (var x = 0; x < layout.width; x++) {
        small.sample((x + ox) / k - 0.5, (y + oy) / k - 0.5, px);
        final o = out.offset(x, y);
        out.data[o] = (px[0] * 0.85).round();
        out.data[o + 1] = (px[1] * 0.85).round();
        out.data[o + 2] = (px[2] * 0.85).round();
        out.data[o + 3] = 255;
      }
    }
  } else if (frame.isNone) {
    out.fill(0x00000000);
  } else {
    out.fill(frame.color);
  }
  final rect = layout.imageRect;
  final rounded = Rgba(src.width, src.height, Uint8List.fromList(src.data));
  if (radius > 0) {
    for (var y = 0; y < src.height; y++) {
      // Only rows near the top/bottom edge can be inside a corner.
      if (y > radius && y < src.height - radius - 1) continue;
      for (var x = 0; x < src.width; x++) {
        final cov = roundedCoverage(x, y, src.width, src.height, radius);
        if (cov < 1) {
          final o = rounded.offset(x, y);
          rounded.data[o + 3] = (rounded.data[o + 3] * cov).round();
        }
      }
    }
  }
  blendPatch(out, rounded, rect.left, rect.top);
  return out;
}

/// Social-media friendly output sizes.
enum SocialSize {
  original(0, 0, 95),
  instagramPortrait(1080, 1350, 92),
  instagramSquare(1080, 1080, 92),
  story(1080, 1920, 92),
  x(1600, 900, 90),
  whatsapp(1600, 0, 80),
  facebook(2048, 0, 90);

  const SocialSize(this.width, this.height, this.quality);

  /// Target width; 0 keeps the original.
  final int width;

  /// Target height; 0 keeps the aspect ratio (long side = [width]).
  final int height;
  final int quality;

  bool get fixedAspect => width > 0 && height > 0;
}

/// How a photo is fitted to a fixed-aspect [SocialSize].
enum SocialFit { crop, pad }

/// Resizes [src] for [size]: crops or pads (with [padColor] or a blur) to
/// the target aspect, then scales to the exact pixel size.
Rgba fitSocial(
  Rgba src,
  SocialSize size, {
  SocialFit fit = SocialFit.pad,
  int padColor = 0xFFFFFFFF,
  bool blur = true,
}) {
  if (size == SocialSize.original) return src;
  if (!size.fixedAspect) {
    final long = math.max(src.width, src.height);
    if (long <= size.width) return src;
    final k = size.width / long;
    return resizeBilinear(src, math.max(1, (src.width * k).round()), math.max(1, (src.height * k).round()));
  }
  final aspect = size.width / size.height;
  final shaped = fit == SocialFit.crop
      ? cropToAspect(src, aspect)
      : applyFrame(
          src,
          FrameSettings(
            style: FrameStyle.fitAspect,
            width: 0,
            aspect: aspect,
            color: padColor,
            fill: blur ? FrameFill.blur : FrameFill.color,
          ),
        );
  return resizeBilinear(shaped, size.width, size.height);
}
