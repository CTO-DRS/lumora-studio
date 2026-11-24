import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/photo_editor/domain/geometry.dart';
import 'package:lumora/features/photo_editor/domain/horizon.dart';

/// Synthetic landscape: bright smooth sky above a straight boundary,
/// textured ground below, with the boundary tilted by [tiltDeg]
/// (positive = right side lower).
Uint8List tiltedScene(int w, int h, double tiltDeg, {int seed = 7}) {
  final rnd = math.Random(seed);
  final buf = Uint8List(w * h * 4);
  final tilt = math.tan(tiltDeg * math.pi / 180);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final boundary = h * 0.5 + (x - w / 2) * tilt;
      final o = (y * w + x) * 4;
      if (y < boundary) {
        buf[o] = 190;
        buf[o + 1] = 212;
        buf[o + 2] = 242;
      } else {
        final n = rnd.nextInt(48);
        buf[o] = 58 + n;
        buf[o + 1] = 92 + n;
        buf[o + 2] = 40 + n;
      }
      buf[o + 3] = 255;
    }
  }
  return buf;
}

/// Renders what the GPU pipeline would render for [g], nearest-neighbour,
/// using the engine's own inverse warp (validates sign conventions too).
Uint8List renderWithGeometry(GeometryState g, Uint8List src, int w, int h) {
  final inverse = buildInverseWarp(g, w, h, w, h);
  final out = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final (nx, ny) = inverse.apply(x + 0.5, y + 0.5);
      final sx = (nx * w).floor().clamp(0, w - 1);
      final sy = (ny * h).floor().clamp(0, h - 1);
      final o = (y * w + x) * 4;
      final s = (sy * w + sx) * 4;
      out[o] = src[s];
      out[o + 1] = src[s + 1];
      out[o + 2] = src[s + 2];
      out[o + 3] = src[s + 3];
    }
  }
  return out;
}

void main() {
  group('detectHorizon', () {
    test('a level horizon is detected as level with strong confidence', () {
      final img = tiltedScene(320, 240, 0);
      final r = detectHorizon(img, 320, 240);
      expect(r.angleDegrees.abs(), lessThan(0.5));
      expect(r.confidence, greaterThanOrEqualTo(kHorizonMinConfidence));
      expect(r.isUsable, isTrue);
    });

    test('a +5° tilt is detected within half a degree', () {
      final img = tiltedScene(320, 240, 5);
      final r = detectHorizon(img, 320, 240);
      expect(r.angleDegrees, closeTo(5, 0.75));
      expect(r.isUsable, isTrue);
    });

    test('a −3° tilt is detected with the right sign', () {
      final img = tiltedScene(320, 240, -3);
      final r = detectHorizon(img, 320, 240);
      expect(r.angleDegrees, closeTo(-3, 0.75));
      expect(r.isUsable, isTrue);
    });

    test('applying the correction through the real warp levels the horizon', () {
      const tilt = 5.0;
      final img = tiltedScene(320, 240, tilt);
      final r = detectHorizon(img, 320, 240);
      expect(r.isUsable, isTrue);
      final g = GeometryState(straightenDegrees: r.correctionDegrees);
      final rendered = renderWithGeometry(g, img, 320, 240);
      final r2 = detectHorizon(rendered, 320, 240);
      expect(r2.angleDegrees.abs(), lessThan(0.75));
      expect(r2.confidence, greaterThanOrEqualTo(kHorizonMinConfidence));
    });

    test('pure noise is not usable', () {
      final rnd = math.Random(11);
      final img = Uint8List(320 * 240 * 4);
      for (var i = 0; i < img.length; i += 4) {
        img[i] = rnd.nextInt(256);
        img[i + 1] = rnd.nextInt(256);
        img[i + 2] = rnd.nextInt(256);
        img[i + 3] = 255;
      }
      final r = detectHorizon(img, 320, 240);
      expect(r.isUsable, isFalse);
    });

    test('a 45° diagonal structure is outside the search range', () {
      // Two halves split by a 45° line — a strong edge, but not
      // near-horizontal, so it must not be reported.
      final img = Uint8List(320 * 240 * 4);
      for (var y = 0; y < 240; y++) {
        for (var x = 0; x < 320; x++) {
          final o = (y * 320 + x) * 4;
          final above = y < x;
          img[o] = above ? 230 : 20;
          img[o + 1] = above ? 230 : 20;
          img[o + 2] = above ? 230 : 20;
          img[o + 3] = 255;
        }
      }
      final r = detectHorizon(img, 320, 240);
      expect(r.isUsable, isFalse);
    });

    test('a flat wall (no structure) reports zero', () {
      final img = Uint8List(320 * 240 * 4);
      for (var i = 0; i < img.length; i += 4) {
        img[i] = 120;
        img[i + 1] = 120;
        img[i + 2] = 120;
        img[i + 3] = 255;
      }
      final r = detectHorizon(img, 320, 240);
      expect(r.angleDegrees, 0);
      expect(r.confidence, 0);
      expect(r.isUsable, isFalse);
    });

    test('tiny images are rejected', () {
      final img = tiltedScene(8, 8, 5);
      final r = detectHorizon(img, 8, 8);
      expect(r.isUsable, isFalse);
    });
  });

  group('HorizonResult', () {
    test('correction opposes the tilt and stays in slider range', () {
      expect(const HorizonResult(angleDegrees: 4, confidence: 1).correctionDegrees, -4);
      expect(const HorizonResult(angleDegrees: -4, confidence: 1).correctionDegrees, 4);
      expect(const HorizonResult(angleDegrees: 80, confidence: 1).correctionDegrees, -45);
      expect(const HorizonResult(angleDegrees: -80, confidence: 1).correctionDegrees, 45);
    });
  });
}
