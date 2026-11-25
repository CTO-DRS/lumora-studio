import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/photo_editor/engine/low_light.dart';

/// Dark gradient scene with seeded luminance + colour noise.
Uint8List _dark(int w, int h, {double base = 0.08, double noise = 0.03, int seed = 7}) {
  final rnd = math.Random(seed);
  final out = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final o = (y * w + x) * 4;
      final g = base + 0.12 * (x / w);
      final n = (rnd.nextDouble() - 0.5) * 2 * noise;
      final cn = (rnd.nextDouble() - 0.5) * 2 * noise;
      out[o] = ((g + n + cn).clamp(0.0, 1.0) * 255).round();
      out[o + 1] = ((g + n).clamp(0.0, 1.0) * 255).round();
      out[o + 2] = ((g + n - cn).clamp(0.0, 1.0) * 255).round();
      out[o + 3] = 255;
    }
  }
  return out;
}

/// Mean absolute difference between horizontal neighbours: a grain proxy.
double _grain(Uint8List d, int w, int h) {
  var s = 0.0;
  var c = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 1; x < w; x++) {
      final a = (y * w + x) * 4;
      final b = a - 4;
      s += ((d[a] + d[a + 1] + d[a + 2]) - (d[b] + d[b + 1] + d[b + 2])).abs() / 3;
      c++;
    }
  }
  return s / c;
}

void main() {
  const w = 64;
  const h = 48;

  test('lifts a dark photo toward the target brightness', () {
    final src = _dark(w, h);
    final out = lowLightRescue(src, w, h);
    expect(meanLuma(src), lessThan(0.2));
    expect(meanLuma(out), greaterThan(meanLuma(src) + 0.12));
    expect(meanLuma(out), lessThan(0.55));
  });

  test('denoises: grain after rescue is below a lift-only baseline', () {
    final src = _dark(w, h);
    final withDenoise = lowLightRescue(src, w, h, params: const LowLightParams(preserveDetail: 0.2));
    // Same lift, denoise switched off by zero strength cannot lift, so build
    // the baseline by scaling grain with the same brightness gain instead.
    final gain = meanLuma(withDenoise) / meanLuma(src);
    final raw = _grain(src, w, h) * gain;
    expect(_grain(withDenoise, w, h), lessThan(raw * 0.7));
  });

  test('a well-exposed photo is barely changed', () {
    final src = _dark(w, h, base: 0.55, noise: 0);
    final out = lowLightRescue(src, w, h);
    expect((meanLuma(out) - meanLuma(src)).abs(), lessThan(0.03));
    expect(looksUnderexposed(src), isFalse);
  });

  test('neutral grey stays neutral (no colour cast)', () {
    final src = Uint8List(w * h * 4);
    for (var i = 0; i < w * h; i++) {
      src
        ..[i * 4] = 25
        ..[i * 4 + 1] = 25
        ..[i * 4 + 2] = 25
        ..[i * 4 + 3] = 255;
    }
    final out = lowLightRescue(src, w, h);
    for (var i = 0; i < w * h; i++) {
      expect((out[i * 4] - out[i * 4 + 1]).abs(), lessThanOrEqualTo(2));
      expect((out[i * 4 + 2] - out[i * 4 + 1]).abs(), lessThanOrEqualTo(2));
    }
  });

  test('alpha is preserved and strength 0 leaves brightness alone', () {
    final src = _dark(w, h);
    for (var i = 0; i < w * h; i++) {
      src[i * 4 + 3] = 77;
    }
    final out = lowLightRescue(src, w, h, params: const LowLightParams(strength: 0));
    expect(out[3], 77);
    expect((meanLuma(out) - meanLuma(src)).abs(), lessThan(0.01));
  });

  test('tiny and invalid inputs do not crash', () {
    expect(lowLightRescue(Uint8List.fromList([10, 10, 10, 255]), 1, 1).length, 4);
    expect(lowLightRescue(Uint8List(2 * 2 * 4), 2, 2).length, 16);
    expect(() => lowLightRescue(Uint8List(7), 2, 2), throwsArgumentError);
    expect(meanLuma(Uint8List(0)), 0);
  });

  test('liftAlpha is zero when bright enough and grows when darker', () {
    expect(liftAlpha(0.6), 0);
    expect(liftAlpha(0.05), greaterThan(liftAlpha(0.2)));
  });
}
