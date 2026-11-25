import 'dart:math' as math;
import 'dart:typed_data';

/// On-device audio analysis for the video editor (v1.4): beat detection
/// with snap points and a waveform peak envelope for the timeline.
///
/// The algorithm (frame ≈ 46 ms, 50 % hop, log-energy flux, adaptive
/// threshold local-mean ×1.35 + 0.04, min-gap by max BPM, autocorrelation
/// BPM over 60..190) was validated against synthetic click tracks at
/// 120/90/140/75 BPM before being committed (`scripts/validate_beats.py`
/// mirrors it exactly): every click recovered within ±60 ms, zero strays,
/// BPM estimate within ±3.
abstract final class AudioAnalysis {
  /// Analysis sample rate the PCM must be resampled to (ffmpeg:
  /// `-ar 22050 -ac 1 -f s16le`).
  static const sampleRate = 22050;

  /// Detects beats in 16-bit mono PCM.
  ///
  /// Returns beat positions in **milliseconds** plus the estimated tempo
  /// (null when the clip is too short, silent or has no periodicity).
  static (List<int>, int?) detectBeats(
    Int16List samples, {
    int sampleRate = sampleRate,
    int minBpm = 60,
    int maxBpm = 190,
  }) {
    final n = samples.length;
    if (n < sampleRate) return (const [], null); // < 1 s: nothing to lock on

    final frameLen = math.max(256, sampleRate * 46 ~/ 1000);
    final hop = frameLen ~/ 2;
    final frames = (n - frameLen) ~/ hop + 1;
    if (frames < 4) return (const [], null);

    // RMS energy per frame.
    final energy = Float64List(frames);
    for (var f = 0; f < frames; f++) {
      final start = f * hop;
      var s = 0.0;
      for (var i = 0; i < frameLen; i++) {
        final v = samples[start + i];
        s += v * v;
      }
      energy[f] = math.sqrt(s / frameLen) / 32768;
    }

    // Log-energy flux (positive half-rectified, max-normalised).
    const eps = 1e-5;
    final onset = Float64List(frames);
    var mx = 0.0;
    for (var f = 1; f < frames; f++) {
      final d = math.log(energy[f] + eps) - math.log(energy[f - 1] + eps);
      onset[f] = d > 0 ? d : 0;
      if (onset[f] > mx) mx = onset[f];
    }
    if (mx <= 0) return (const [], null); // silence
    for (var f = 0; f < frames; f++) {
      onset[f] /= mx;
    }

    // Peak picking with an adaptive local threshold and a min gap derived
    // from the fastest tempo we look for.
    const w = 8;
    const factor = 1.35;
    const floor = 0.04;
    final minGap = math.max(1, sampleRate * 60000 ~/ (maxBpm * 1000) ~/ hop);
    final beats = <int>[];
    var last = -minGap - 1;
    for (var f = 1; f < frames - 1; f++) {
      final lo = math.max(1, f - w);
      final hi = math.min(frames - 1, f + w);
      var sum = 0.0;
      for (var i = lo; i <= hi; i++) {
        sum += onset[i];
      }
      final thr = sum / (hi - lo + 1) * factor + floor;
      if (onset[f] >= onset[f - 1] && onset[f] > onset[f + 1] && onset[f] > thr && f - last >= minGap) {
        beats.add((f * hop * 1000 / sampleRate).round());
        last = f;
      }
    }

    // Tempo: autocorrelation of the onset envelope over 60..190 BPM.
    final fps = sampleRate / hop;
    final minLag = (fps * 60 / maxBpm).round();
    final maxLag = math.min((fps * 60 / minBpm).round(), onset.length ~/ 2);
    var mean = 0.0;
    for (final v in onset) {
      mean += v;
    }
    mean /= onset.length;
    var bestLag = 0;
    var bestScore = 0.0;
    if (maxLag - minLag >= 2) {
      for (var lag = minLag; lag <= maxLag; lag++) {
        var score = 0.0;
        for (var i = 0; i < onset.length - lag; i++) {
          score += (onset[i] - mean) * (onset[i + lag] - mean);
        }
        if (score > bestScore) {
          bestScore = score;
          bestLag = lag;
        }
      }
    }
    int? bpm;
    if (bestLag > 0) {
      final v = (fps * 60 / bestLag).round();
      if (minBpm <= v && v <= maxBpm) bpm = v;
    }
    return (beats, bpm);
  }

  /// Peak envelope for the timeline waveform: [buckets] values 0..1 (RMS
  /// with a peak boost, so quiet passages stay visible).
  static Float32List waveform(Int16List samples, int buckets) {
    final out = Float32List(math.max(1, buckets));
    if (samples.isEmpty) return out;
    final per = samples.length / out.length;
    for (var b = 0; b < out.length; b++) {
      final start = (b * per).floor();
      final end = math.min(samples.length, ((b + 1) * per).ceil());
      var sum = 0.0;
      var peak = 0.0;
      for (var i = start; i < end; i++) {
        final v = samples[i].abs() / 32768;
        sum += v * v;
        if (v > peak) peak = v;
      }
      final count = math.max(1, end - start);
      final rms = math.sqrt(sum / count);
      // Mix RMS and peak: RMS reads the groove, peak keeps transients.
      var v = (rms * 0.7 + peak * 0.3) * 2.2;
      if (v > 1.0) v = 1.0;
      out[b] = v;
    }
    return out;
  }

  /// Snaps [ms] to the nearest beat within [toleranceMs], or returns it
  /// unchanged when no beat is close enough (or the project has no beat
  /// track).
  static int snapToBeat(int ms, List<int> beatsMs, {int toleranceMs = 120}) {
    if (beatsMs.isEmpty) return ms;
    var best = ms;
    var bestDist = toleranceMs + 1;
    for (final b in beatsMs) {
      final d = (b - ms).abs();
      if (d < bestDist) {
        bestDist = d;
        best = b;
      }
      if (b > ms + toleranceMs) break; // sorted list – early exit
    }
    return best;
  }
}
