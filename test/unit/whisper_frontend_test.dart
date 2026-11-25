import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/video_editor/domain/whisper_frontend.dart';

void main() {
  group('MixedRadixFft', () {
    test('matches a naive DFT for n=400', () {
      final rng = math.Random(7);
      final x = Float64List.fromList(List.generate(400, (_) => rng.nextDouble() * 2 - 1));
      final (re, im) = MixedRadixFft(400).real(x);
      for (final k in [0, 1, 5, 57, 200, 399]) {
        var sr = 0.0;
        var si = 0.0;
        for (var t = 0; t < 400; t++) {
          final a = -2 * math.pi * k * t / 400;
          sr += x[t] * math.cos(a);
          si += x[t] * math.sin(a);
        }
        expect(re[k], closeTo(sr, 1e-8));
        expect(im[k], closeTo(si, 1e-8));
      }
    });

    test('handles prime and tiny lengths', () {
      for (final n in [1, 2, 7, 12]) {
        final x = Float64List.fromList(List.generate(n, (i) => i + 1.0));
        final (re, im) = MixedRadixFft(n).real(x);
        for (var k = 0; k < n; k++) {
          var sr = 0.0;
          var si = 0.0;
          for (var t = 0; t < n; t++) {
            final a = -2 * math.pi * k * t / n;
            sr += x[t] * math.cos(a);
            si += x[t] * math.sin(a);
          }
          expect(re[k], closeTo(sr, 1e-9));
          expect(im[k], closeTo(si, 1e-9));
        }
      }
    });
  });

  group('mel filterbank', () {
    test('shape, non-negative, every filter non-empty', () {
      final fb = melFilterbank();
      expect(fb.length, 80 * 201);
      for (var m = 0; m < 80; m++) {
        var s = 0.0;
        for (var k = 0; k < 201; k++) {
          final v = fb[m * 201 + k];
          expect(v, greaterThanOrEqualTo(0));
          s += v;
        }
        expect(s, greaterThan(0));
      }
    });

    test('centre frequencies rise monotonically', () {
      final fb = melFilterbank();
      var prev = -1;
      for (var m = 0; m < 80; m++) {
        var best = 0;
        for (var k = 0; k < 201; k++) {
          if (fb[m * 201 + k] > fb[m * 201 + best]) best = k;
        }
        expect(best, greaterThanOrEqualTo(prev));
        prev = best;
      }
    });
  });

  group('resample / pad', () {
    test('48 kHz -> 16 kHz length and DC preserved', () {
      final x = Float32List.fromList(List.filled(48000, 0.5));
      final y = resampleTo16k(x, 48000);
      expect(y.length, 16000);
      expect(y.every((v) => (v - 0.5).abs() < 1e-6), isTrue);
    });

    test('8 kHz upsample interpolates', () {
      final y = resampleTo16k(Float32List.fromList([0, 1]), 8000);
      expect(y.length, 4);
      expect(y[1], closeTo(0.5, 1e-6));
    });

    test('padOrTrim fixes length to 30 s', () {
      expect(padOrTrim(Float32List(10)).length, whisperChunkSamples);
      expect(padOrTrim(Float32List(whisperChunkSamples + 5)).length, whisperChunkSamples);
    });

    test('degenerate inputs are empty, not crashes', () {
      expect(resampleTo16k(Float32List(0), 16000), isEmpty);
      expect(resampleTo16k(Float32List(5), 0), isEmpty);
    });
  });

  group('log-mel', () {
    test('30 s window is 80 x 3000 and normalised within range', () {
      final tone = Float32List(whisperChunkSamples);
      for (var i = 0; i < tone.length; i++) {
        tone[i] = 0.5 * math.sin(2 * math.pi * 440 * i / 16000);
      }
      final lm = logMelSpectrogram(tone);
      expect(lm.nMels, 80);
      expect(lm.frames, whisperFrames);
      var mx = -1e9;
      var mn = 1e9;
      for (final v in lm.data) {
        expect(v.isFinite, isTrue);
        mx = math.max(mx, v);
        mn = math.min(mn, v);
      }
      expect(mx - mn, lessThanOrEqualTo(2.0 + 1e-4)); // (max-8 .. max)/4
    });

    test('a 1 kHz tone peaks in the matching mel bin', () {
      final tone = Float32List(16000 * 2);
      for (var i = 0; i < tone.length; i++) {
        tone[i] = math.sin(2 * math.pi * 1000 * i / 16000);
      }
      final lm = logMelSpectrogram(tone);
      var best = 0;
      for (var m = 0; m < 80; m++) {
        if (lm.at(m, 50) > lm.at(best, 50)) best = m;
      }
      // 1 kHz is ~ mel bin 26 of 80 on the Slaney scale (15 of 45.3 mel).
      expect(best, inInclusiveRange(25, 28));
    });

    test('silence is flat and finite', () {
      final lm = logMelSpectrogram(Float32List(16000));
      final v0 = lm.at(0, 0);
      expect(lm.data.every((v) => v == v0), isTrue);
    });

    test('empty input yields zero frames without throwing', () {
      expect(logMelSpectrogram(Float32List(0)).frames, 0);
    });

    test('whisperFeaturesFromPcm end to end from 44.1 kHz', () {
      final pcm = Int16List(44100);
      for (var i = 0; i < pcm.length; i++) {
        pcm[i] = (12000 * math.sin(2 * math.pi * 300 * i / 44100)).round();
      }
      final lm = whisperFeaturesFromPcm(pcm, 44100);
      expect(lm.frames, whisperFrames);
      expect(lm.data.every((v) => v.isFinite), isTrue);
    });
  });
}
