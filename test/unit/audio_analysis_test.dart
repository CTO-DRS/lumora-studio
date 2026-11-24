import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/video_editor/domain/audio_analysis.dart';
import 'package:lumora/features/video_editor/engine/ffmpeg_command_builder.dart';

const rate = 22050;

/// Little-endian PCM16 bytes for [samples].
Uint8List pcmBytes(Int16List samples) {
  final b = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    b.setInt16(i * 2, samples[i], Endian.little);
  }
  return b.buffer.asUint8List();
}

/// A click track: [bpm] clicks per minute ([seconds] long) — 60 ms sine
/// bursts over a faint noise floor. Perfect for asserting beat detection.
Int16List clickTrack({required int bpm, int seconds = 6, double amplitude = 0.9}) {
  final rnd = math.Random(11);
  final n = rate * seconds;
  final out = Int16List(n);
  final clickLen = rate * 60 ~/ 1000;
  for (final t in positions(bpm: bpm, seconds: seconds)) {
    final start = t * rate ~/ 1000;
    for (var i = 0; i < clickLen && start + i < n; i++) {
      final env = 1 - i / clickLen;
      final v = amplitude * env * math.sin(2 * math.pi * 440 * i / rate);
      out[start + i] = (v * 32767).round();
    }
  }
  for (var i = 0; i < n; i++) {
    out[i] += ((rnd.nextDouble() * 2 - 1) * 0.02 * 32767).round();
  }
  return out;
}

/// Click start times in ms.
List<int> positions({required int bpm, required int seconds}) {
  final out = <int>[];
  final periodMs = 60000 / bpm;
  for (var t = 0.0; t < seconds * 1000; t += periodMs) {
    out.add(t.round());
  }
  return out;
}

Int16List silence(int seconds) => Int16List(rate * seconds);

void main() {
  group('AudioWaveform', () {
    test('buckets map loud and quiet zones correctly', () {
      final pcm = pcmBytes(clickTrack(bpm: 120));
      final w = AudioAnalysis.buildWaveform(pcm, rate);
      expect(w.durationMs, 6000);
      expect(w.peaks.length, 60);
      // A click bucket is loud; the bucket right after it is quiet.
      final clickBucket = 500 ~/ w.bucketMs;
      expect(w.peaks[clickBucket], greaterThan(0.5));
      expect(w.rms[clickBucket], greaterThan(0.1));
      expect(w.peaks[clickBucket + 1], lessThan(0.1));
    });

    test('peakAt and rmsAt clamp to the last bucket', () {
      final pcm = pcmBytes(clickTrack(bpm: 120));
      final w = AudioAnalysis.buildWaveform(pcm, rate);
      expect(w.peakAt(500), greaterThan(0.5));
      expect(w.peakAt(999999), w.peaks.last);
      expect(w.rmsAt(-5), w.rms.first);
      expect(w.peakAt(0), isA<double>());
    });

    test('JSON round trip', () {
      final pcm = pcmBytes(clickTrack(bpm: 120, seconds: 2));
      final w = AudioAnalysis.buildWaveform(pcm, rate);
      final back = AudioWaveform.fromJson(w.toJson());
      expect(back.peaks, w.peaks);
      expect(back.rms, w.rms);
      expect(back.bucketMs, w.bucketMs);
      expect(back.sampleRate, w.sampleRate);
      expect(back.durationMs, w.durationMs);
    });
  });

  group('BeatGrid', () {
    test('snap returns the nearest beat within tolerance', () {
      const g = BeatGrid(beatMs: [500, 1000, 1500], bpm: 120);
      expect(g.snap(520), 500);
      expect(g.snap(1480), 1500);
      expect(g.snap(520, toleranceMs: 10), isNull);
      expect(g.snap(2000), isNull);
      expect(g.snap(1000, toleranceMs: 1), 1000);
    });

    test('empty grid snaps nowhere; JSON round trip', () {
      const g = BeatGrid(beatMs: [], bpm: null);
      expect(g.snap(500), isNull);
      final withBeats = BeatGrid.fromJson(const BeatGrid(beatMs: [250, 750], bpm: 240).toJson());
      expect(withBeats.beatMs, [250, 750]);
      expect(withBeats.bpm, 240);
      expect(BeatGrid.fromJson(g.toJson()).beatMs, isEmpty);
      expect(BeatGrid.fromJson(g.toJson()).bpm, isNull);
    });
  });

  group('AudioAnalysis.detectBeats', () {
    test('finds the beats of a 120 BPM click track', () {
      final beats = AudioAnalysis.detectBeats(pcmBytes(clickTrack(bpm: 120)), rate);
      expect(beats.bpm, inInclusiveRange(117, 123));
      final expected = positions(bpm: 120, seconds: 6);
      // Every detected beat must sit on a real click (± 60 ms), and most
      // clicks must be detected.
      for (final b in beats.beatMs) {
        final near = expected.any((e) => (e - b).abs() <= 60);
        expect(near, isTrue, reason: 'stray beat at $b');
      }
      final hits = expected.where((e) => beats.beatMs.any((b) => (b - e).abs() <= 60));
      expect(hits.length, greaterThanOrEqualTo(8));
    });

    test('finds the beats of a 90 BPM click track', () {
      final beats = AudioAnalysis.detectBeats(pcmBytes(clickTrack(bpm: 90)), rate);
      expect(beats.bpm, inInclusiveRange(88, 92));
      final expected = positions(bpm: 90, seconds: 6);
      final hits = expected.where((e) => beats.beatMs.any((b) => (b - e).abs() <= 60));
      expect(hits.length, greaterThanOrEqualTo(5));
    });

    test('silence has no beats and no tempo', () {
      final beats = AudioAnalysis.detectBeats(pcmBytes(silence(3)), rate);
      expect(beats.beatMs, isEmpty);
      expect(beats.bpm, isNull);
    });

    test('very short audio returns an empty grid', () {
      final beats = AudioAnalysis.detectBeats(pcmBytes(silence(1).sublist(0, 1000)), rate);
      expect(beats.beatMs, isEmpty);
    });
  });

  group('FfmpegCommandBuilder.audioPcmArgs', () {
    test('decodes to mono little-endian PCM16 at the requested rate', () {
      final args = FfmpegCommandBuilder.audioPcmArgs('in.mp4', 'out.pcm');
      expect(args.first, '-y');
      expect(args.contains('-vn'), isTrue);
      expect(args.contains('-ac'), isTrue);
      expect(args[args.indexOf('-ac') + 1], '1');
      expect(args[args.indexOf('-ar') + 1], '$rate');
      expect(args[args.indexOf('-f') + 1], 's16le');
      expect(args[args.indexOf('-acodec') + 1], 'pcm_s16le');
      expect(args.last, 'out.pcm');
      final custom = FfmpegCommandBuilder.audioPcmArgs('a', 'b', sampleRate: 44100);
      expect(custom[custom.indexOf('-ar') + 1], '44100');
    });
  });
}
