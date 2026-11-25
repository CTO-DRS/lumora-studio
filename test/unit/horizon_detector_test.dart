import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/photo_editor/domain/horizon_detector.dart';

Uint8List _rgba(int w, int h) => Uint8List(w * h * 4);

void _fill(Uint8List px, int w, int h, int v) {
  for (var i = 0; i < w * h; i++) {
    px[i * 4] = v;
    px[i * 4 + 1] = v;
    px[i * 4 + 2] = v;
    px[i * 4 + 3] = 255;
  }
}

/// Fills the region **above** the line y(x) = cy + tan(α)·x bright (sky)
/// and below dark (ground), with one anti-aliased boundary row – a realistic
/// horizon whose Sobel edge is exactly horizontal-in-image terms.
void _drawHorizon(Uint8List px, int w, int h, double alphaDeg, {int sky = 200, int ground = 30}) {
  final slope = math.tan(alphaDeg * math.pi / 180);
  final cy = h / 2;
  for (var x = 0; x < w; x++) {
    final yf = cy + slope * (x - w / 2);
    final yLine = yf.floor();
    final frac = yf - yLine;
    for (var y = 0; y < h; y++) {
      final i = (y * w + x) * 4;
      final int v;
      if (y < yLine) {
        v = sky;
      } else if (y == yLine) {
        // Blend one row at the boundary.
        v = (ground + (sky - ground) * (1 - frac)).round();
      } else {
        v = ground;
      }
      px[i] = v;
      px[i + 1] = v;
      px[i + 2] = v;
    }
  }
}

void main() {
  test('detects a line tilted +4° (falls to the right, y-down positive)', () {
    const w = 220;
    const h = 220;
    final px = _rgba(w, h);
    _fill(px, w, h, 30);
    _drawHorizon(px, w, h, 4);
    final tilt = HorizonDetector.detect(px, w, h)!;
    expect(tilt, closeTo(4.0, 0.7));
  });

  test('detects a line tilted −4°', () {
    const w = 220;
    const h = 220;
    final px = _rgba(w, h);
    _fill(px, w, h, 30);
    _drawHorizon(px, w, h, -4);
    final tilt = HorizonDetector.detect(px, w, h)!;
    expect(tilt, closeTo(-4.0, 0.7));
  });

  test('already level image reports 0', () {
    const w = 220;
    const h = 220;
    final px = _rgba(w, h);
    _fill(px, w, h, 30);
    _drawHorizon(px, w, h, 0);
    final tilt = HorizonDetector.detect(px, w, h)!;
    expect(tilt, 0);
  });

  test('a uniform image is not confident → null', () {
    const w = 160;
    const h = 160;
    final px = _rgba(w, h);
    _fill(px, w, h, 100);
    expect(HorizonDetector.detect(px, w, h), isNull);
  });

  test('a busy random texture (no dominant orientation) → null', () {
    const w = 160;
    const h = 160;
    final px = _rgba(w, h);
    final rnd = math.Random(7);
    for (var i = 0; i < w * h; i++) {
      final v = rnd.nextInt(256);
      px[i * 4] = v;
      px[i * 4 + 1] = v;
      px[i * 4 + 2] = v;
      px[i * 4 + 3] = 255;
    }
    // Per-column peak positions are uniform noise → the residual gate must
    // refuse to fit a line.
    expect(HorizonDetector.detect(px, w, h), isNull);
  });

  test('a second, weaker line does not win over the strong horizon', () {
    const w = 220;
    const h = 220;
    final px = _rgba(w, h);
    _fill(px, w, h, 30);
    _drawHorizon(px, w, h, 6); // strong horizon (200 over 30)
    // A faint 2-px roof band at −8° drawn *over* the bright sky.
    final slope = math.tan(-8 * math.pi / 180);
    for (var x = 0; x < w; x++) {
      final yf = (h / 2 + slope * (x - w / 2)).round();
      for (final y in [yf, yf + 1]) {
        if (y < 0 || y >= h) continue;
        final i = (y * w + x) * 4;
        px[i] = 90;
        px[i + 1] = 90;
        px[i + 2] = 90;
      }
    }
    final tilt = HorizonDetector.detect(px, w, h)!;
    expect(tilt, closeTo(6.0, 1.0));
  });
}
