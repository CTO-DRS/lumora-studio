/// Whisper audio front end (Wave 2 W3-M3): 16 kHz resampling, 30 s
/// pad/trim and the 80-bin log-mel spectrogram the Whisper encoder eats.
///
/// Pure Dart, no model and no platform code, so it is unit-testable and
/// runs inside an isolate. It follows the reference implementation
/// (openai/whisper `audio.py`): periodic Hann window, `n_fft = 400`,
/// `hop = 160`, centred STFT with reflect padding, the last frame dropped,
/// Slaney-scale mel filters (0-8 kHz), `log10(max(x, 1e-10))`, clamp to
/// `max - 8`, then `(x + 4) / 4`.
library;

import 'dart:math' as math;
import 'dart:typed_data';

const int whisperSampleRate = 16000;
const int whisperNFft = 400;
const int whisperHop = 160;
const int whisperNMels = 80;
const int whisperChunkSeconds = 30;
const int whisperChunkSamples = whisperSampleRate * whisperChunkSeconds;
const int whisperFrames = whisperChunkSamples ~/ whisperHop; // 3000

/// Converts Int16 PCM to float in [-1, 1).
Float32List pcm16ToFloat(Int16List pcm) {
  final out = Float32List(pcm.length);
  for (var i = 0; i < pcm.length; i++) {
    out[i] = pcm[i] / 32768;
  }
  return out;
}

/// Linear resampler to [whisperSampleRate]. Downsampling applies a short
/// box average over the source span of each output sample (a cheap
/// anti-alias); upsampling interpolates linearly. Returns a copy.
Float32List resampleTo16k(Float32List input, int sourceRate) {
  if (sourceRate <= 0 || input.isEmpty) return Float32List(0);
  if (sourceRate == whisperSampleRate) return Float32List.fromList(input);
  final outLen = (input.length * whisperSampleRate / sourceRate).floor();
  final out = Float32List(outLen);
  final step = sourceRate / whisperSampleRate;
  for (var i = 0; i < outLen; i++) {
    final pos = i * step;
    if (step > 1) {
      final a = pos.floor();
      final b = math.min(input.length, (pos + step).ceil());
      var sum = 0.0;
      var n = 0;
      for (var j = a; j < b; j++) {
        sum += input[j];
        n++;
      }
      out[i] = n == 0 ? 0 : sum / n;
    } else {
      final a = pos.floor();
      final f = pos - a;
      final x0 = input[a];
      final x1 = a + 1 < input.length ? input[a + 1] : x0;
      out[i] = x0 + (x1 - x0) * f;
    }
  }
  return out;
}

/// Pads with zeros or trims to exactly [length] samples.
Float32List padOrTrim(Float32List input, [int length = whisperChunkSamples]) {
  final out = Float32List(length);
  final n = math.min(length, input.length);
  out.setRange(0, n, input);
  return out;
}

/// Discrete Fourier transform for any length, by recursive mixed-radix
/// Cooley-Tukey on the smallest prime factor (400 = 2^4 * 5^2 stays fast).
/// Prime lengths fall back to the O(n^2) DFT, which is fine for the tiny
/// sizes this front end uses.
class MixedRadixFft {
  MixedRadixFft(this.n) : assert(n > 0, 'FFT length must be positive'), _cos = Float64List(n), _sin = Float64List(n) {
    for (var k = 0; k < n; k++) {
      final a = -2 * math.pi * k / n;
      _cos[k] = math.cos(a);
      _sin[k] = math.sin(a);
    }
  }

  final int n;
  final Float64List _cos;
  final Float64List _sin;

  /// In-place-free transform: returns (re, im) of the length-n DFT of the
  /// real signal [x] (length n).
  (Float64List, Float64List) real(Float64List x) {
    final re = Float64List(n);
    final im = Float64List(n);
    _fft(x, Float64List(n), 0, 1, n, re, im, 0, 1);
    return (re, im);
  }

  // Transforms the length-m subsequence of (xr, xi) starting at [off] with
  // stride [stride] into out[outOff ...] (contiguous).
  void _fft(
    Float64List xr,
    Float64List xi,
    int off,
    int stride,
    int m,
    Float64List outR,
    Float64List outI,
    int outOff,
    int twStride,
  ) {
    if (m == 1) {
      outR[outOff] = xr[off];
      outI[outOff] = xi[off];
      return;
    }
    var p = 2;
    while (m % p != 0) {
      p++;
      if (p * p > m) {
        p = m;
        break;
      }
    }
    final q = m ~/ p;
    // p sub-transforms of length q, each over elements off + r*stride + p*stride*j.
    for (var r = 0; r < p; r++) {
      _fft(xr, xi, off + r * stride, stride * p, q, outR, outI, outOff + r * q, twStride * p);
    }
    final tmpR = Float64List(p);
    final tmpI = Float64List(p);
    final base = n ~/ m; // twiddle index step for length m: w_m^k = w_n^(k*n/m)
    for (var k = 0; k < q; k++) {
      for (var r = 0; r < p; r++) {
        final idx = (r * k * base) % n;
        final c = _cos[idx];
        final s = _sin[idx];
        final vr = outR[outOff + r * q + k];
        final vi = outI[outOff + r * q + k];
        tmpR[r] = vr * c - vi * s;
        tmpI[r] = vr * s + vi * c;
      }
      for (var u = 0; u < p; u++) {
        var sr = 0.0;
        var si = 0.0;
        for (var r = 0; r < p; r++) {
          final idx = ((r * u * q) * base) % n;
          final c = _cos[idx];
          final s = _sin[idx];
          sr += tmpR[r] * c - tmpI[r] * s;
          si += tmpR[r] * s + tmpI[r] * c;
        }
        // results for output index k + u*q are written after all k are read,
        // so stage them.
        _stageR[(k + u * q)] = sr;
        _stageI[(k + u * q)] = si;
      }
    }
    for (var i = 0; i < m; i++) {
      outR[outOff + i] = _stageR[i];
      outI[outOff + i] = _stageI[i];
    }
  }

  late final Float64List _stageR = Float64List(n);
  late final Float64List _stageI = Float64List(n);
}

double _hzToMelSlaney(double hz) {
  const fSp = 200.0 / 3;
  const minLogHz = 1000.0;
  const minLogMel = minLogHz / fSp;
  final logStep = math.log(6.4) / 27.0;
  if (hz >= minLogHz) return minLogMel + math.log(hz / minLogHz) / logStep;
  return hz / fSp;
}

double _melToHzSlaney(double mel) {
  const fSp = 200.0 / 3;
  const minLogHz = 1000.0;
  const minLogMel = minLogHz / fSp;
  final logStep = math.log(6.4) / 27.0;
  if (mel >= minLogMel) return minLogHz * math.exp(logStep * (mel - minLogMel));
  return mel * fSp;
}

/// Slaney-normalised triangular mel filterbank, shape `[nMels][nFft/2+1]`
/// flattened row-major (librosa defaults, fmin 0, fmax sr/2).
Float32List melFilterbank({int sampleRate = whisperSampleRate, int nFft = whisperNFft, int nMels = whisperNMels}) {
  final nBins = nFft ~/ 2 + 1;
  final fmax = sampleRate / 2;
  final melMin = _hzToMelSlaney(0);
  final melMax = _hzToMelSlaney(fmax);
  final pts = List<double>.generate(nMels + 2, (i) => _melToHzSlaney(melMin + (melMax - melMin) * i / (nMels + 1)));
  final fb = Float32List(nMels * nBins);
  for (var m = 0; m < nMels; m++) {
    final lo = pts[m];
    final mid = pts[m + 1];
    final hi = pts[m + 2];
    final enorm = 2.0 / (hi - lo);
    for (var k = 0; k < nBins; k++) {
      final f = k * sampleRate / nFft;
      final up = (f - lo) / (mid - lo);
      final down = (hi - f) / (hi - mid);
      final w = math.max(0, math.min(up, down));
      fb[m * nBins + k] = w * enorm;
    }
  }
  return fb;
}

/// Log-mel spectrogram, `[nMels][frames]` flattened row-major, ready for
/// the encoder after the Whisper normalisation.
class LogMel {
  LogMel(this.data, this.nMels, this.frames);
  final Float32List data;
  final int nMels;
  final int frames;
  double at(int mel, int frame) => data[mel * frames + frame];
}

final MixedRadixFft _fft400 = MixedRadixFft(whisperNFft);
final Float32List _filters = melFilterbank();

/// Computes the Whisper log-mel for [audio16k] (already 16 kHz, any length;
/// pass through [padOrTrim] first for a fixed 30 s window).
LogMel logMelSpectrogram(Float32List audio16k) {
  const half = whisperNFft ~/ 2;
  const nBins = whisperNFft ~/ 2 + 1;
  final len = audio16k.length;
  // Centred STFT with reflect padding of n_fft/2 each side.
  final padded = Float64List(len + whisperNFft);
  double sample(int i) {
    if (len == 0) return 0;
    var j = i;
    if (j < 0) j = -j;
    if (j >= len) j = 2 * (len - 1) - j;
    if (j < 0) j = 0;
    return audio16k[math.min(j, len - 1)];
  }

  for (var i = 0; i < padded.length; i++) {
    padded[i] = sample(i - half);
  }
  final window = Float64List(whisperNFft);
  for (var i = 0; i < whisperNFft; i++) {
    window[i] = 0.5 - 0.5 * math.cos(2 * math.pi * i / whisperNFft);
  }
  final totalFrames = 1 + len ~/ whisperHop;
  final frames = math.max(0, totalFrames - 1); // reference drops the last
  final mags = Float64List(nBins * frames);
  final buf = Float64List(whisperNFft);
  for (var f = 0; f < frames; f++) {
    final s = f * whisperHop;
    for (var i = 0; i < whisperNFft; i++) {
      buf[i] = padded[s + i] * window[i];
    }
    final (re, im) = _fft400.real(buf);
    for (var k = 0; k < nBins; k++) {
      mags[k * frames + f] = re[k] * re[k] + im[k] * im[k];
    }
  }
  final out = Float32List(whisperNMels * frames);
  var maxLog = -1e30;
  final logs = Float64List(whisperNMels * frames);
  for (var m = 0; m < whisperNMels; m++) {
    for (var f = 0; f < frames; f++) {
      var acc = 0.0;
      for (var k = 0; k < nBins; k++) {
        acc += _filters[m * nBins + k] * mags[k * frames + f];
      }
      final v = math.log(math.max(acc, 1e-10)) / math.ln10;
      logs[m * frames + f] = v;
      if (v > maxLog) maxLog = v;
    }
  }
  final floor = maxLog - 8;
  for (var i = 0; i < logs.length; i++) {
    out[i] = (math.max(logs[i], floor) + 4) / 4;
  }
  return LogMel(out, whisperNMels, frames);
}

/// One-call helper: Int16 PCM at [sampleRate] -> fixed 30 s log-mel.
LogMel whisperFeaturesFromPcm(Int16List pcm, int sampleRate) {
  final f = resampleTo16k(pcm16ToFloat(pcm), sampleRate);
  return logMelSpectrogram(padOrTrim(f));
}
