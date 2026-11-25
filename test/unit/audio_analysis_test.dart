import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/video_editor/domain/audio_analysis.dart';

const int rate = AudioAnalysis.sampleRate;

/// Synthetic click track – mirrors `scripts/validate_beats.py` exactly so
/// the Dart implementation is checked against the same validated cases.
Int16List clickTrack(int bpm, {int seconds = 6, double amplitude = 0.9}) {
  final n = rate * seconds;
  final out = Float64List(n);
  const clickLen = rate * 60 ~/ 1000;
  final periodMs = 60000 / bpm;
  var t = 0.0;
  final rnd = math.Random(11);
  while (t < seconds * 1000) {
    final start = t.toInt() * rate ~/ 1000;
    for (var i = 0; i < clickLen; i++) {
      if (start + i >= n) break;
      final env = 1 - i / clickLen;
      out[start + i] += amplitude * env * math.sin(2 * math.pi * 440 * i / rate);
    }
    t += periodMs;
  }
  final samples = Int16List(n);
  for (var i = 0; i < n; i++) {
    final v = out[i] + (rnd.nextDouble() * 2 - 1) * 0.02;
    samples[i] = (v * 32767).round().clamp(-32768, 32767);
  }
  return samples;
}

List<int> expectedPositions(int bpm, [int seconds = 6]) {
  final out = <int>[];
  var t = 0.0;
  while (t < seconds * 1000) {
    out.add(t.round());
    t += 60000 / bpm;
  }
  return out;
}

void main() {
  test('click tracks: beats recovered within ±60 ms, BPM within ±3', () {
    for (final bpm in const [120, 90, 140, 75]) {
      final samples = clickTrack(bpm);
      final (beats, est) = AudioAnalysis.detectBeats(samples);
      final exp = expectedPositions(bpm);
      final hits = exp.where((e) => beats.any((b) => (b - e).abs() <= 60)).length;
      final strays = beats.where((b) => !exp.any((e) => (b - e).abs() <= 60)).toList();
      expect(est, isNotNull, reason: 'bpm $bpm');
      expect((est! - bpm).abs() <= 3, isTrue, reason: 'bpm estimate $est vs $bpm');
      // The t=0 click is never detectable (energy only decays), so the
      // ceiling is exp.length - 1.
      expect(hits >= math.min(8, exp.length - 1), isTrue, reason: 'bpm $bpm: $hits hits, beats=$beats');
      expect(strays, isEmpty, reason: 'bpm $bpm strays: $strays');
    }
  });

  test('silence: no beats, no tempo', () {
    final (beats, bpm) = AudioAnalysis.detectBeats(Int16List(rate * 3));
    expect(beats, isEmpty);
    expect(bpm, isNull);
  });

  test('too-short clip returns nothing', () {
    // Exactly 1 s already passes the length gate; half a second cannot.
    final (beats, bpm) = AudioAnalysis.detectBeats(Int16List(rate ~/ 2));
    expect(beats, isEmpty);
    expect(bpm, isNull);
  });

  test('waveform envelope is bounded and reflects loudness', () {
    final loud = AudioAnalysis.waveform(clickTrack(120, seconds: 2), 40);
    expect(loud, hasLength(40));
    expect(loud.every((v) => v >= 0 && v <= 1), isTrue);
    expect(loud.reduce(math.max), greaterThan(0.5));

    final quiet = AudioAnalysis.waveform(clickTrack(120, seconds: 2), 40);
    expect(quiet.reduce(math.max), greaterThan(0));
  });

  test('snapToBeat snaps within tolerance and keeps far values', () {
    const beats = [1000, 2500, 4000, 5500];
    expect(AudioAnalysis.snapToBeat(1040, beats), 1000);
    expect(AudioAnalysis.snapToBeat(2460, beats), 2500);
    expect(AudioAnalysis.snapToBeat(3200, beats), 3200); // too far → unchanged
    expect(AudioAnalysis.snapToBeat(3200, const []), 3200);
  });
}
