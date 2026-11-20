import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/photo_editor/domain/geometry.dart';
import 'package:lumora/features/photo_editor/engine/curves/tone_curve.dart';

void main() {
  group('ToneCurve', () {
    test('identity curve is identity', () {
      final t = ToneCurve(kIdentityCurve).toTable();
      for (var i = 0; i < 256; i++) {
        expect(t[i], i);
      }
    });

    test('passes through control points and is monotone (no overshoot)', () {
      const pts = [
        CurvePoint(0, 0),
        CurvePoint(0.25, 0.15),
        CurvePoint(0.5, 0.5),
        CurvePoint(0.75, 0.9),
        CurvePoint(1, 1),
      ];
      final c = ToneCurve(pts);
      for (final p in pts) {
        expect(c.evaluate(p.x), closeTo(p.y, 1e-9));
      }
      var prev = -1.0;
      for (var i = 0; i <= 1000; i++) {
        final v = c.evaluate(i / 1000);
        expect(v, greaterThanOrEqualTo(prev - 1e-12));
        expect(v, inInclusiveRange(0, 1));
        prev = v;
      }
    });

    test('unsorted / duplicate points are normalised', () {
      final c = ToneCurve(const [CurvePoint(1, 1), CurvePoint(0, 0.2), CurvePoint(0, 0.1)]);
      expect(c.evaluate(0), closeTo(0.1, 1e-9));
    });

    test('curveSetToRgba packs channels', () {
      final rgba = curveSetToRgba(const CurveSet(red: [CurvePoint(0, 1), CurvePoint(1, 0)]));
      expect(rgba.length, 1024);
      expect(rgba[0], 255); // red inverted
      expect(rgba[1], 0); // green identity
      expect(rgba[255 * 4], 0);
      expect(rgba[255 * 4 + 3], 255);
    });
  });

  group('Geometry', () {
    test('identity warp maps output pixels to the same normalized source', () {
      const g = GeometryState();
      final m = buildInverseWarp(g, 400, 200, 400, 200);
      final (u, v) = m.apply(100, 50);
      expect(u, closeTo(0.25, 1e-9));
      expect(v, closeTo(0.25, 1e-9));
    });

    test('crop maps output corners to crop corners', () {
      const g = GeometryState(cropLeft: 0.2, cropTop: 0.1, cropRight: 0.6, cropBottom: 0.9);
      final (w, h) = g.outputSize(1000, 500);
      expect((w, h), (400, 400));
      final m = buildInverseWarp(g, 1000, 500, w, h);
      final (u0, v0) = m.apply(0, 0);
      final (u1, v1) = m.apply(w.toDouble(), h.toDouble());
      expect(u0, closeTo(0.2, 1e-9));
      expect(v0, closeTo(0.1, 1e-9));
      expect(u1, closeTo(0.6, 1e-9));
      expect(v1, closeTo(0.9, 1e-9));
    });

    test('quarter turn swaps output size and rotates clockwise', () {
      const g = GeometryState(quarterTurns: 1);
      expect(g.outputSize(400, 200), (200, 400));
      final m = buildInverseWarp(g, 400, 200, 200, 400);
      // Top-left of the rotated output shows the bottom-left of the source.
      final (u, v) = m.apply(0, 0);
      expect(u, closeTo(0, 1e-9));
      expect(v, closeTo(1, 1e-9));
    });

    test('horizontal flip mirrors x', () {
      final m = buildInverseWarp(const GeometryState(flipHorizontal: true), 100, 100, 100, 100);
      final (u, _) = m.apply(10, 10);
      expect(u, closeTo(0.9, 1e-9));
    });

    test('straighten zooms in so no empty corners are sampled', () {
      const g = GeometryState(straightenDegrees: 10);
      final m = buildInverseWarp(g, 300, 200, 300, 200);
      for (final (x, y) in [(0.0, 0.0), (300.0, 0.0), (0.0, 200.0), (300.0, 200.0)]) {
        final (u, v) = m.apply(x, y);
        expect(u, inInclusiveRange(-1e-9, 1 + 1e-9));
        expect(v, inInclusiveRange(-1e-9, 1 + 1e-9));
      }
    });

    test('Mat3 inverse and squareToQuad', () {
      final r = Mat3.rotate(0.3) * Mat3.translate(2, 5);
      final i = r.inverse();
      final (x, y) = (i * r).apply(3, 4);
      expect(x, closeTo(3, 1e-9));
      expect(y, closeTo(4, 1e-9));
      final q = Mat3.squareToQuad(const [(0.1, 0), (0.9, 0), (1, 1), (0, 1)]);
      final (a, b) = q.apply(1, 0);
      expect(a, closeTo(0.9, 1e-9));
      expect(b, closeTo(0, 1e-9));
      final (c, d) = q.apply(0, 1);
      expect(c, closeTo(0, 1e-9));
      expect(d, closeTo(1, 1e-9));
      expect(math.pi, isPositive);
    });
  });
}
