import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumora/features/photo_editor/domain/adjustments.dart';

/// Monotone cubic (Fritsch–Carlson) interpolation through curve points,
/// guaranteeing no overshoot – the behaviour photographers expect from a
/// tone curve.
class ToneCurve {
  ToneCurve(List<CurvePoint> points) : _pts = _normalize(points) {
    _computeTangents();
  }

  final List<CurvePoint> _pts;
  late final List<double> _m;

  static List<CurvePoint> _normalize(List<CurvePoint> points) {
    final sorted = [...points]..sort((a, b) => a.x.compareTo(b.x));
    final out = <CurvePoint>[];
    for (final p in sorted) {
      final c = CurvePoint(p.x.clamp(0, 1), p.y.clamp(0, 1));
      if (out.isNotEmpty && (c.x - out.last.x).abs() < 1e-6) {
        out[out.length - 1] = c;
      } else {
        out.add(c);
      }
    }
    if (out.isEmpty) return kIdentityCurve;
    if (out.length == 1) return [out.first, out.first.copyWith(x: 1)];
    return out;
  }

  void _computeTangents() {
    final n = _pts.length;
    final d = List<double>.generate(n - 1, (i) => (_pts[i + 1].y - _pts[i].y) / (_pts[i + 1].x - _pts[i].x));
    final m = List<double>.filled(n, 0);
    m[0] = d[0];
    m[n - 1] = d[n - 2];
    for (var i = 1; i < n - 1; i++) {
      m[i] = (d[i - 1] * d[i] <= 0) ? 0 : (d[i - 1] + d[i]) / 2;
    }
    for (var i = 0; i < n - 1; i++) {
      if (d[i] == 0) {
        m[i] = 0;
        m[i + 1] = 0;
        continue;
      }
      final a = m[i] / d[i];
      final b = m[i + 1] / d[i];
      final s = a * a + b * b;
      if (s > 9) {
        final t = 3 / math.sqrt(s);
        m[i] = t * a * d[i];
        m[i + 1] = t * b * d[i];
      }
    }
    _m = m;
  }

  double evaluate(double x) {
    if (x <= _pts.first.x) return _pts.first.y;
    if (x >= _pts.last.x) return _pts.last.y;
    var i = 0;
    while (i < _pts.length - 2 && x > _pts[i + 1].x) {
      i++;
    }
    final p0 = _pts[i];
    final p1 = _pts[i + 1];
    final h = p1.x - p0.x;
    final t = (x - p0.x) / h;
    final t2 = t * t;
    final t3 = t2 * t;
    final h00 = 2 * t3 - 3 * t2 + 1;
    final h10 = t3 - 2 * t2 + t;
    final h01 = -2 * t3 + 3 * t2;
    final h11 = t3 - t2;
    return (h00 * p0.y + h10 * h * _m[i] + h01 * p1.y + h11 * h * _m[i + 1]).clamp(0.0, 1.0);
  }

  /// 256-entry lookup table (0..255).
  Uint8List toTable() {
    final t = Uint8List(256);
    for (var i = 0; i < 256; i++) {
      t[i] = (evaluate(i / 255) * 255).round().clamp(0, 255);
    }
    return t;
  }
}

/// Packs a [CurveSet] into a 256x1 RGBA texture: R, G, B channel curves and
/// the master curve in alpha. Consumed by `develop.frag`.
Uint8List curveSetToRgba(CurveSet set) {
  final r = ToneCurve(set.red).toTable();
  final g = ToneCurve(set.green).toTable();
  final b = ToneCurve(set.blue).toTable();
  final m = ToneCurve(set.master).toTable();
  final out = Uint8List(256 * 4);
  for (var i = 0; i < 256; i++) {
    out[i * 4] = r[i];
    out[i * 4 + 1] = g[i];
    out[i * 4 + 2] = b[i];
    out[i * 4 + 3] = m[i];
  }
  return out;
}
