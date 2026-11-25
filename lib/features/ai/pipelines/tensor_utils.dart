import 'dart:math' as math;
import 'dart:typed_data';

/// Plain RGBA8 image buffer used by the AI pipelines (isolate friendly).
class RgbaImage {
  RgbaImage(this.width, this.height, [Uint8List? pixels])
    : pixels = pixels ?? Uint8List(width * height * 4),
      assert(pixels == null || pixels.length == width * height * 4, 'pixel buffer does not match dimensions');

  final int width;
  final int height;
  final Uint8List pixels;

  /// Bilinear resize.
  RgbaImage resize(int w, int h) {
    if (w == width && h == height) return this;
    final out = Uint8List(w * h * 4);
    final sx = width / w;
    final sy = height / h;
    var o = 0;
    for (var y = 0; y < h; y++) {
      final fy = ((y + 0.5) * sy - 0.5).clamp(0.0, height - 1.0);
      final y0 = fy.floor();
      final y1 = math.min(y0 + 1, height - 1);
      final ay = fy - y0;
      for (var x = 0; x < w; x++) {
        final fx = ((x + 0.5) * sx - 0.5).clamp(0.0, width - 1.0);
        final x0 = fx.floor();
        final x1 = math.min(x0 + 1, width - 1);
        final ax = fx - x0;
        final i00 = (y0 * width + x0) * 4;
        final i10 = (y0 * width + x1) * 4;
        final i01 = (y1 * width + x0) * 4;
        final i11 = (y1 * width + x1) * 4;
        for (var c = 0; c < 4; c++) {
          final top = pixels[i00 + c] * (1 - ax) + pixels[i10 + c] * ax;
          final bot = pixels[i01 + c] * (1 - ax) + pixels[i11 + c] * ax;
          out[o++] = (top * (1 - ay) + bot * ay).round();
        }
      }
    }
    return RgbaImage(w, h, out);
  }

  RgbaImage crop(int x, int y, int w, int h) {
    final out = Uint8List(w * h * 4);
    for (var row = 0; row < h; row++) {
      final s = ((y + row) * width + x) * 4;
      out.setRange(row * w * 4, (row + 1) * w * 4, pixels, s);
    }
    return RgbaImage(w, h, out);
  }
}

/// Converts RGBA to a planar NCHW float tensor `[1, 3, H, W]` with
/// `(v / 255 - mean) / std` normalization.
Float32List rgbaToNchw(RgbaImage img, {List<double> mean = const [0, 0, 0], List<double> std = const [1, 1, 1]}) {
  final plane = img.width * img.height;
  final out = Float32List(plane * 3);
  final px = img.pixels;
  for (var i = 0; i < plane; i++) {
    final o = i * 4;
    out[i] = (px[o] / 255 - mean[0]) / std[0];
    out[plane + i] = (px[o + 1] / 255 - mean[1]) / std[1];
    out[2 * plane + i] = (px[o + 2] / 255 - mean[2]) / std[2];
  }
  return out;
}

/// Converts RGBA to a planar uint8 NCHW tensor (for models such as MI-GAN
/// that embed their own normalization).
Uint8List rgbaToNchwUint8(RgbaImage img) {
  final plane = img.width * img.height;
  final out = Uint8List(plane * 3);
  final px = img.pixels;
  for (var i = 0; i < plane; i++) {
    out[i] = px[i * 4];
    out[plane + i] = px[i * 4 + 1];
    out[2 * plane + i] = px[i * 4 + 2];
  }
  return out;
}

/// Converts a planar `[1, 3, H, W]` tensor back to RGBA. Values are
/// multiplied by [scale] (use 255 for 0..1 outputs).
RgbaImage nchwToRgba(List<num> data, int width, int height, {double scale = 255}) {
  final plane = width * height;
  final out = Uint8List(plane * 4);
  for (var i = 0; i < plane; i++) {
    out[i * 4] = (data[i] * scale).round().clamp(0, 255);
    out[i * 4 + 1] = (data[plane + i] * scale).round().clamp(0, 255);
    out[i * 4 + 2] = (data[2 * plane + i] * scale).round().clamp(0, 255);
    out[i * 4 + 3] = 255;
  }
  return RgbaImage(width, height, out);
}

/// Min-max normalizes a single channel map to 0..1 (U²-Net style output).
Float32List normalizeMinMax(List<num> data) {
  var mn = double.infinity;
  var mx = double.negativeInfinity;
  for (final v in data) {
    if (v < mn) mn = v.toDouble();
    if (v > mx) mx = v.toDouble();
  }
  final range = mx - mn;
  final out = Float32List(data.length);
  for (var i = 0; i < data.length; i++) {
    out[i] = range <= 1e-8 ? 0 : (data[i] - mn) / range;
  }
  return out;
}

/// Turns a 0..1 matte of [mw]x[mh] into a grayscale RGBA mask of
/// [width]x[height] (bilinear upsampling).
RgbaImage matteToMask(List<double> matte, int mw, int mh, int width, int height) {
  final small = RgbaImage(mw, mh);
  for (var i = 0; i < mw * mh; i++) {
    final v = (matte[i].clamp(0.0, 1.0) * 255).round();
    small.pixels[i * 4] = v;
    small.pixels[i * 4 + 1] = v;
    small.pixels[i * 4 + 2] = v;
    small.pixels[i * 4 + 3] = 255;
  }
  return small.resize(width, height);
}

/// Applies a grayscale mask as alpha (background removal).
RgbaImage applyMaskAsAlpha(RgbaImage image, RgbaImage mask) {
  assert(image.width == mask.width && image.height == mask.height, 'size mismatch');
  final out = Uint8List.fromList(image.pixels);
  for (var i = 0; i < image.width * image.height; i++) {
    out[i * 4 + 3] = (out[i * 4 + 3] * mask.pixels[i * 4] / 255).round();
  }
  return RgbaImage(image.width, image.height, out);
}

/// Rounds [v] up to a multiple of [m].
int roundUpTo(int v, int m) => ((v + m - 1) ~/ m) * m;

/// Scales [w]x[h] so the long side is at most [maxSide] and both sides are
/// multiples of [multiple].
(int, int) fitForModel(int w, int h, {required int maxSide, int multiple = 32}) {
  final k = math.min(1, maxSide / math.max(w, h));
  final nw = math.max(multiple, (w * k / multiple).round() * multiple);
  final nh = math.max(multiple, (h * k / multiple).round() * multiple);
  return (nw, nh);
}

/// Bounding box `(x, y, w, h)` of mask pixels above [threshold], or null.
(int, int, int, int)? maskBounds(RgbaImage mask, {int threshold = 127}) {
  var minX = mask.width;
  var minY = mask.height;
  var maxX = -1;
  var maxY = -1;
  for (var y = 0; y < mask.height; y++) {
    for (var x = 0; x < mask.width; x++) {
      if (mask.pixels[(y * mask.width + x) * 4] > threshold) {
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
  }
  if (maxX < 0) return null;
  return (minX, minY, maxX - minX + 1, maxY - minY + 1);
}

/// Morphological dilation of a binary mask by [radius] px (square kernel,
/// separable – O(n·r)).
RgbaImage dilateMask(RgbaImage mask, int radius) {
  if (radius <= 0) return mask;
  final w = mask.width;
  final h = mask.height;
  final bin = Uint8List(w * h);
  for (var i = 0; i < w * h; i++) {
    bin[i] = mask.pixels[i * 4] > 127 ? 1 : 0;
  }
  final tmp = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var v = 0;
      for (var k = math.max(0, x - radius); k <= math.min(w - 1, x + radius); k++) {
        if (bin[y * w + k] == 1) {
          v = 1;
          break;
        }
      }
      tmp[y * w + x] = v;
    }
  }
  final out = RgbaImage(w, h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var v = 0;
      for (var k = math.max(0, y - radius); k <= math.min(h - 1, y + radius); k++) {
        if (tmp[k * w + x] == 1) {
          v = 255;
          break;
        }
      }
      final o = (y * w + x) * 4;
      out.pixels[o] = v;
      out.pixels[o + 1] = v;
      out.pixels[o + 2] = v;
      out.pixels[o + 3] = 255;
    }
  }
  return out;
}

/// Tile layout for fixed-size super resolution models.
class SrTile {
  const SrTile(this.x, this.y, this.size);
  final int x;
  final int y;
  final int size;
}

/// Plans overlapping input tiles of [tile] px covering [w]x[h]. The last
/// row/column is shifted inwards so every tile is full size (requires the
/// image to be at least [tile] px; smaller images are padded by the caller).
List<SrTile> planSrTiles(int w, int h, {int tile = 128, int overlap = 16}) {
  final step = tile - overlap;
  List<int> starts(int len) {
    if (len <= tile) return [0];
    final s = <int>[];
    for (var p = 0; ; p += step) {
      if (p + tile >= len) {
        s.add(len - tile);
        break;
      }
      s.add(p);
    }
    return s;
  }

  return [
    for (final y in starts(h))
      for (final x in starts(w)) SrTile(x, y, tile),
  ];
}

// ---------------------------------------------------------------------------
// v1.4 helpers – faces (YuNet / Face Mesh) & sky (SkySeg)

/// RGBA → planar `[1, 3, H, W]` float32 in **BGR order, 0..255 range** (no
/// normalisation) – the input contract of the OpenCV Zoo YuNet graph.
Float32List rgbaToNchwBgr255(RgbaImage img) {
  final plane = img.width * img.height;
  final out = Float32List(plane * 3);
  final px = img.pixels;
  for (var i = 0; i < plane; i++) {
    final o = i * 4;
    out[i] = px[o + 2].toDouble(); // B
    out[plane + i] = px[o + 1].toDouble(); // G
    out[2 * plane + i] = px[o].toDouble(); // R
  }
  return out;
}

/// RGBA → NHWC `[1, H, W, 3]` float32 RGB in 0..1 – the input contract of
/// the MediaPipe Face Mesh graph.
Float32List rgbaToNhwc01(RgbaImage img) {
  final out = Float32List(img.width * img.height * 3);
  final px = img.pixels;
  var o = 0;
  for (var i = 0; i < img.width * img.height; i++) {
    out[o++] = px[i * 4] / 255;
    out[o++] = px[i * 4 + 1] / 255;
    out[o++] = px[i * 4 + 2] / 255;
  }
  return out;
}

/// Separable box blur (two passes) of a grayscale RGBA mask, used to
/// feather AI masks so composited adjustments never show hard edges.
RgbaImage blurMask(RgbaImage mask, int radius) {
  if (radius <= 0) return mask;
  final w = mask.width;
  final h = mask.height;
  final src = mask.pixels;
  final tmp = Uint8List(w * h);
  // Horizontal pass with a sliding window sum.
  for (var y = 0; y < h; y++) {
    var sum = 0;
    final row = y * w;
    for (var x = -radius; x <= radius; x++) {
      sum += src[(row + x.clamp(0, w - 1)) * 4];
    }
    for (var x = 0; x < w; x++) {
      tmp[row + x] = (sum / (2 * radius + 1)).round();
      final outX = (x - radius).clamp(0, w - 1);
      final inX = (x + radius + 1).clamp(0, w - 1);
      sum += src[(row + inX) * 4] - src[(row + outX) * 4];
    }
  }
  final out = RgbaImage(w, h);
  // Vertical pass.
  for (var x = 0; x < w; x++) {
    var sum = 0;
    for (var y = -radius; y <= radius; y++) {
      sum += tmp[y.clamp(0, h - 1) * w + x];
    }
    for (var y = 0; y < h; y++) {
      final v = (sum / (2 * radius + 1)).round();
      final o = (y * w + x) * 4;
      out.pixels[o] = v;
      out.pixels[o + 1] = v;
      out.pixels[o + 2] = v;
      out.pixels[o + 3] = 255;
      final outY = (y - radius).clamp(0, h - 1);
      final inY = (y + radius + 1).clamp(0, h - 1);
      sum += tmp[inY * w + x] - tmp[outY * w + x];
    }
  }
  return out;
}

/// Fills a polygon (even–odd scanline rule) into a white-on-black RGBA mask
/// of [width]×[height].
RgbaImage polygonMask(List<(double, double)> polygon, int width, int height) {
  final out = RgbaImage(width, height);
  if (polygon.length < 3) return out;
  var yMin = double.infinity;
  var yMax = double.negativeInfinity;
  for (final (_, y) in polygon) {
    if (y < yMin) yMin = y;
    if (y > yMax) yMax = y;
  }
  final y0 = math.max(0, yMin.floor());
  final y1 = math.min(height - 1, yMax.ceil());
  final n = polygon.length;
  for (var y = y0; y <= y1; y++) {
    final cy = y + 0.5;
    final xs = <double>[];
    for (var i = 0; i < n; i++) {
      final (ax, ay) = polygon[i];
      final (bx, by) = polygon[(i + 1) % n];
      if ((ay <= cy && by > cy) || (by <= cy && ay > cy)) {
        xs.add(ax + (cy - ay) / (by - ay) * (bx - ax));
      }
    }
    if (xs.length < 2) continue;
    xs.sort();
    for (var k = 0; k + 1 < xs.length; k += 2) {
      final from = xs[k].ceil().clamp(0, width - 1);
      final to = xs[k + 1].floor().clamp(0, width - 1);
      for (var x = from; x <= to; x++) {
        final o = (y * width + x) * 4;
        out.pixels[o] = 255;
        out.pixels[o + 1] = 255;
        out.pixels[o + 2] = 255;
        out.pixels[o + 3] = 255;
      }
    }
  }
  return out;
}

/// Scales polygon points around its centroid – used to grow/shrink facial
/// regions (eye rings, brows, lips) before painting masks.
List<(double, double)> scalePolygon(List<(double, double)> polygon, double factor) {
  if (polygon.isEmpty || factor == 1) return polygon;
  var cx = 0.0;
  var cy = 0.0;
  for (final (x, y) in polygon) {
    cx += x;
    cy += y;
  }
  cx /= polygon.length;
  cy /= polygon.length;
  return [
    for (final (x, y) in polygon) (cx + (x - cx) * factor, cy + (y - cy) * factor),
  ];
}

/// out = base AND NOT subtract (per pixel, channel 0).
RgbaImage subtractMask(RgbaImage base, RgbaImage subtract) {
  assert(base.width == subtract.width && base.height == subtract.height, 'size mismatch');
  final out = Uint8List.fromList(base.pixels);
  for (var i = 0; i < base.width * base.height; i++) {
    if (subtract.pixels[i * 4] > 127) out[i * 4] = 0;
    out[i * 4 + 1] = out[i * 4];
    out[i * 4 + 2] = out[i * 4];
  }
  return RgbaImage(base.width, base.height, out);
}

/// Union (max) of two masks.
RgbaImage unionMask(RgbaImage a, RgbaImage b) {
  assert(a.width == b.width && a.height == b.height, 'size mismatch');
  final out = RgbaImage(a.width, a.height);
  for (var i = 0; i < a.width * a.height; i++) {
    final v = math.max(a.pixels[i * 4], b.pixels[i * 4]);
    out.pixels[i * 4] = v;
    out.pixels[i * 4 + 1] = v;
    out.pixels[i * 4 + 2] = v;
    out.pixels[i * 4 + 3] = 255;
  }
  return out;
}
