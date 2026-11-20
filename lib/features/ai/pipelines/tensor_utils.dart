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
