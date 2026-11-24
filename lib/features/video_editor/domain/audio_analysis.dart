import 'dart:math' as math;
import 'dart:typed_data';

/// Pure-Dart audio analysis for the video editor: waveform buckets and a
/// beat grid, both computed from decoded PCM with plain signal processing —
/// no model, no network (v1.4 "Pro foundations", video theme).
///
/// The FFmpeg decode (mono `s16le`) happens in [VideoEngine]; everything
/// here is deterministic and fully unit tested.

/// Peak/RMS levels per time bucket, normalised to 0..1.
class AudioWaveform {
  const AudioWaveform({
    required this.peaks,
    required this.rms,
    required this.bucketMs,
    required this.sampleRate,
    required this.durationMs,
  });

  /// Largest absolute sample per bucket, 0..1.
  final List<double> peaks;

  /// Root-mean-square per bucket, 0..1 (loudness).
  final List<double> rms;

  /// Duration of one bucket in milliseconds.
  final int bucketMs;

  /// Sample rate of the decoded PCM this waveform was built from.
  final int sampleRate;

  /// Audio duration in milliseconds (may be shorter than the video).
  final int durationMs;

  /// Peak level at timeline position [ms] (clamped, 0..1).
  double peakAt(int ms) {
    if (peaks.isEmpty) return 0;
    final i = (ms ~/ bucketMs).clamp(0, peaks.length - 1);
    return peaks[i];
  }

  /// Loudness level at timeline position [ms] (clamped, 0..1).
  double rmsAt(int ms) {
    if (rms.isEmpty) return 0;
    final i = (ms ~/ bucketMs).clamp(0, rms.length - 1);
    return rms[i];
  }

  Map<String, dynamic> toJson() => {
    'peaks': peaks,
    'rms': rms,
    'bucketMs': bucketMs,
    'sampleRate': sampleRate,
    'durationMs': durationMs,
  };

  factory AudioWaveform.fromJson(Map<String, dynamic> json) => AudioWaveform(
    peaks: [for (final v in json['peaks'] as List) (v as num).toDouble()],
    rms: [for (final v in json['rms'] as List) (v as num).toDouble()],
    bucketMs: json['bucketMs'] as int,
    sampleRate: json['sampleRate'] as int,
    durationMs: json['durationMs'] as int,
  );
}

/// Detected beats (onsets) and a tempo estimate for one audio track.
class BeatGrid {
  const BeatGrid({required this.beatMs, this.bpm});

  /// Beat/onset timestamps in milliseconds, sorted ascending.
  final List<int> beatMs;

  /// Tempo estimate in beats per minute, or null when the audio is too
  /// quiet or aperiodic for a reliable estimate.
  final int? bpm;

  /// Nearest beat within [toleranceMs] of [ms], or null.
  int? snap(int ms, {int toleranceMs = 150}) {
    if (beatMs.isEmpty) return null;
    var lo = 0;
    var hi = beatMs.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (beatMs[mid] < ms) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final before = beatMs[lo];
    final after = beatMs[hi];
    final best = (ms - before).abs() <= (after - ms).abs() ? before : after;
    if ((best - ms).abs() > toleranceMs) return null;
    return best;
  }

  Map<String, dynamic> toJson() => {'beatMs': beatMs, 'bpm': bpm};

  factory BeatGrid.fromJson(Map<String, dynamic> json) =>
      BeatGrid(beatMs: [for (final v in json['beatMs'] as List) (v as num).toInt()], bpm: json['bpm'] as int?);
}

/// Waveform + beat grid for one file, produced by a single FFmpeg decode.
class ClipAudio {
  const ClipAudio({required this.waveform, required this.beats});

  final AudioWaveform waveform;
  final BeatGrid beats;
}

/// Signal-processing entry points. Input is little-endian mono PCM16 bytes
/// (what FFmpeg's `-f s16le` writes), as delivered by the engine.
abstract final class AudioAnalysis {
  /// Builds level buckets of [bucketMs] from mono PCM16 bytes.
  static AudioWaveform buildWaveform(Uint8List pcm, int sampleRate, {int bucketMs = 100}) {
    final samples = decodePcm(pcm);
    final bucket = math.max(1, bucketMs * sampleRate ~/ 1000);
    final nBuckets = math.max(1, (samples.length / bucket).ceil());
    final peaks = Float64List(nBuckets);
    final rms = Float64List(nBuckets);
    for (var b = 0; b < nBuckets; b++) {
      final start = b * bucket;
      final end = math.min(start + bucket, samples.length);
      var peak = 0;
      var sumSq = 0.0;
      for (var i = start; i < end; i++) {
        final a = samples[i].abs();
        if (a > peak) peak = a;
        sumSq += a * a;
      }
      final count = math.max(1, end - start);
      peaks[b] = peak / 32768;
      rms[b] = math.sqrt(sumSq / count) / 32768;
    }
    return AudioWaveform(
      peaks: peaks,
      rms: rms,
      bucketMs: bucketMs,
      sampleRate: sampleRate,
      durationMs: (samples.length * 1000 / sampleRate).round(),
    );
  }

  /// Detects onsets/beats with an energy-flux envelope and an adaptive
  /// threshold, then estimates tempo by autocorrelation. Returns an empty
  /// grid (no beats, null bpm) for silence or aperiodic audio.
  static BeatGrid detectBeats(Uint8List pcm, int sampleRate, {int minBpm = 60, int maxBpm = 190}) {
    final samples = decodePcm(pcm);
    if (samples.length < sampleRate) return const BeatGrid(beatMs: []);
    // Energy envelope: ~46 ms frames, 50 % hop.
    final frameLen = math.max(256, sampleRate * 46 ~/ 1000);
    final hop = frameLen ~/ 2;
    final frames = (samples.length - frameLen) ~/ hop + 1;
    if (frames < 4) return const BeatGrid(beatMs: []);
    final energy = Float64List(frames);
    for (var f = 0; f < frames; f++) {
      final start = f * hop;
      var sumSq = 0.0;
      for (var i = start; i < start + frameLen; i++) {
        final a = samples[i].abs();
        sumSq += a * a;
      }
      energy[f] = math.sqrt(sumSq / frameLen) / 32768;
    }
    // Onset strength: half-wave rectified difference of log energy.
    const eps = 1e-5;
    final onset = Float64List(frames);
    var maxOnset = 0.0;
    for (var f = 1; f < frames; f++) {
      final d = math.log(energy[f] + eps) - math.log(energy[f - 1] + eps);
      onset[f] = d > 0 ? d : 0;
      if (onset[f] > maxOnset) maxOnset = onset[f];
    }
    if (maxOnset <= 0) return const BeatGrid(beatMs: []);
    for (var f = 0; f < frames; f++) {
      onset[f] /= maxOnset;
    }
    // Adaptive threshold: local mean x factor + floor.
    const w = 8;
    const factor = 1.35;
    const floor = 0.04;

    // Minimum gap between beats = the interval at [maxBpm], in envelope
    // frames: (60 s / maxBpm) * sampleRate samples → frames.
    final minGapFrames = math.max(1, sampleRate * 60000 ~/ (maxBpm * 1000) ~/ hop);
    final beats = <int>[];
    var lastBeatFrame = -minGapFrames - 1;
    for (var f = 1; f < frames - 1; f++) {
      var sum = 0.0;
      var count = 0;
      for (var k = math.max(1, f - w); k <= math.min(frames - 1, f + w); k++) {
        sum += onset[k];
        count++;
      }
      final thr = sum / count * factor + floor;
      final isPeak = onset[f] >= onset[f - 1] && onset[f] > onset[f + 1];
      if (isPeak && onset[f] > thr && f - lastBeatFrame >= minGapFrames) {
        beats.add((f * hop * 1000 / sampleRate).round());
        lastBeatFrame = f;
      }
    }
    final bpm = _estimateBpm(onset, sampleRate, hop, minBpm: minBpm, maxBpm: maxBpm);
    return BeatGrid(beatMs: beats, bpm: bpm);
  }

  /// Autocorrelation of the onset envelope inside the [minBpm]..[maxBpm]
  /// lag window; returns the rounded tempo or null when the peak is too
  /// weak (aperiodic audio).
  static int? _estimateBpm(Float64List onset, int sampleRate, int hop, {required int minBpm, required int maxBpm}) {
    final framesPerSecond = sampleRate / hop;
    final minLag = (framesPerSecond * 60 / maxBpm).round();
    final maxLag = math.min((framesPerSecond * 60 / minBpm).round(), onset.length ~/ 2);
    if (maxLag - minLag < 2) return null;
    var bestLag = 0;
    var bestScore = 0.0;
    var mean = 0.0;
    for (final v in onset) {
      mean += v;
    }
    mean /= onset.length;
    for (var lag = minLag; lag <= maxLag; lag++) {
      var score = 0.0;
      for (var i = 0; i + lag < onset.length; i++) {
        score += (onset[i] - mean) * (onset[i + lag] - mean);
      }
      if (score > bestScore) {
        bestScore = score;
        bestLag = lag;
      }
    }
    if (bestLag == 0) return null;
    final bpm = (framesPerSecond * 60 / bestLag).round();
    if (bpm < minBpm || bpm > maxBpm) return null;
    return bpm;
  }

  /// Decodes little-endian mono PCM16 bytes into an [Int16List]. Odd
  /// trailing bytes are ignored.
  static Int16List decodePcm(Uint8List pcm) {
    final n = pcm.length ~/ 2;
    final out = Int16List(n);
    final data = ByteData.sublistView(pcm, 0, n * 2);
    for (var i = 0; i < n; i++) {
      out[i] = data.getInt16(i * 2, Endian.little);
    }
    return out;
  }
}
