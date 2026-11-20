import 'dart:typed_data';

/// 256-bin RGB + luminance histogram with clipping statistics.
class Histogram {
  Histogram._(this.red, this.green, this.blue, this.luma, this.pixelCount, this.highlightClip, this.shadowClip);

  /// Builds the histogram of straight-alpha RGBA [rgba]. Fully transparent
  /// pixels (e.g. a removed background) are ignored.
  factory Histogram.fromRgba(Uint8List rgba, {int step = 1}) {
    final r = Uint32List(256);
    final g = Uint32List(256);
    final b = Uint32List(256);
    final l = Uint32List(256);
    var n = 0;
    var hi = 0;
    var lo = 0;
    final stride = step < 1 ? 4 : 4 * step;
    for (var i = 0; i + 3 < rgba.length; i += stride) {
      if (rgba[i + 3] == 0) continue;
      final rr = rgba[i];
      final gg = rgba[i + 1];
      final bb = rgba[i + 2];
      r[rr]++;
      g[gg]++;
      b[bb]++;
      l[((54 * rr + 183 * gg + 19 * bb) >> 8).clamp(0, 255)]++;
      if (rr >= 254 || gg >= 254 || bb >= 254) hi++;
      if (rr <= 1 && gg <= 1 && bb <= 1) lo++;
      n++;
    }
    return Histogram._(r, g, b, l, n, n == 0 ? 0 : hi / n, n == 0 ? 0 : lo / n);
  }

  final Uint32List red;
  final Uint32List green;
  final Uint32List blue;
  final Uint32List luma;
  final int pixelCount;

  /// Fraction (0..1) of pixels with at least one blown-out channel.
  final double highlightClip;

  /// Fraction (0..1) of pixels crushed to black.
  final double shadowClip;

  /// Largest bin over all channels, ignoring the two extreme bins so a
  /// clipped spike does not flatten the rest of the graph.
  int get peak {
    var m = 1;
    for (final ch in [red, green, blue, luma]) {
      for (var i = 1; i < 255; i++) {
        if (ch[i] > m) m = ch[i];
      }
    }
    return m;
  }

  /// Warn above 0.5 % of the frame.
  bool get clipsHighlights => highlightClip > 0.005;
  bool get clipsShadows => shadowClip > 0.005;

  /// Mean luminance 0..255.
  double get meanLuma {
    if (pixelCount == 0) return 0;
    var s = 0.0;
    for (var i = 0; i < 256; i++) {
      s += i * luma[i];
    }
    return s / pixelCount;
  }
}
