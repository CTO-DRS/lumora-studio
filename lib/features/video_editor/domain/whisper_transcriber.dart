/// Whisper transcriber (Wave 2 W3-M5): ties the audio front end, the
/// encoder, the KV-cached decoder and the token layer together behind the
/// [AutoTranscriber] seam from W3-M2.
///
/// The neural graphs are reached through two tiny interfaces
/// ([WhisperEncoder], [WhisperDecoderGraph]) so all of the orchestration,
/// including the KV-cache bookkeeping of the merged decoder graph, is
/// unit-tested with fakes. The ONNX Runtime binding lives in
/// `features/ai/data/onnx_whisper_runtime.dart`.
///
/// Graph contract (checked against onnx-community/whisper-tiny, merged
/// decoder with `use_cache_branch`): inputs `input_ids` int64 `[1, n]`,
/// `encoder_hidden_states` `[1, 1500, d]`, `past_key_values.{i}.{decoder|
/// encoder}.{key|value}` `[1, heads, len, head_dim]`, `use_cache_branch`
/// bool `[1]`; outputs `logits` `[1, n, vocab]` and `present.*` with the same
/// names.
library;

import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumora/features/video_editor/domain/captioning.dart';
import 'package:lumora/features/video_editor/domain/whisper_decoding.dart';
import 'package:lumora/features/video_editor/domain/whisper_frontend.dart';

/// A tensor handed to / returned from a graph runner. Native runtimes may
/// return an opaque [handle] (data stays inside the runtime, so large KV
/// caches never cross the platform channel) together with an [onDispose]
/// callback; the decoder step releases tensors it no longer needs.
class WhisperTensor {
  const WhisperTensor.float(Float32List this.floats, this.shape, {this.handle, this.onDispose})
    : ints = null,
      flag = null;
  const WhisperTensor.int64(Int64List this.ints, this.shape)
    : floats = null,
      flag = null,
      handle = null,
      onDispose = null;
  const WhisperTensor.boolean(bool this.flag, this.shape) : floats = null, ints = null, handle = null, onDispose = null;

  /// Tensor that lives inside the runtime (no Dart-side data).
  const WhisperTensor.opaque(Object this.handle, this.shape, {this.onDispose})
    : floats = null,
      ints = null,
      flag = null;

  final Float32List? floats;
  final Int64List? ints;
  final bool? flag;
  final List<int> shape;
  final Object? handle;
  final Future<void> Function()? onDispose;

  Future<void> dispose() async => onDispose?.call();
}

/// Runs the encoder graph: log-mel `[1, 80, 3000]` to hidden states.
abstract interface class WhisperEncoder {
  Future<WhisperTensor> encode(Float32List logMel);
}

/// Runs the merged decoder graph once with named inputs.
abstract interface class WhisperDecoderGraph {
  Future<Map<String, WhisperTensor>> run(Map<String, WhisperTensor> inputs);
}

/// [WhisperDecoderStep] over the merged decoder graph with a KV cache.
///
/// First call (or after the prefix changes) feeds every token with empty
/// past tensors; every later call feeds only the newest token plus the cache.
/// Cross-attention (encoder) key/values are computed once and reused.
class CachedWhisperDecoderStep implements WhisperDecoderStep {
  CachedWhisperDecoderStep(
    this._graph,
    this._hidden, {
    this.layers = 4,
    this.heads = 6,
    this.headDim = 64,
    this.vocabSize = 51865,
  });

  final WhisperDecoderGraph _graph;
  final WhisperTensor _hidden;
  final int layers;
  final int heads;
  final int headDim;
  final int vocabSize;

  Map<String, WhisperTensor>? _cache;

  /// Releases the KV cache. Call when decoding is done.
  Future<void> close() async {
    final c = _cache;
    _cache = null;
    _seen = 0;
    for (final v in c?.values ?? const <WhisperTensor>[]) {
      await v.dispose();
    }
  }

  int _seen = 0;

  /// Number of graph runs so far (diagnostics, tests).
  int runs = 0;

  @override
  Future<Float32List> logits(List<int> tokens) async {
    if (tokens.isEmpty) throw ArgumentError('empty token list');
    final cached = _cache != null && tokens.length == _seen + 1;
    final ids = cached ? [tokens.last] : tokens;
    final inputs = <String, WhisperTensor>{
      'input_ids': WhisperTensor.int64(Int64List.fromList(ids), [1, ids.length]),
      'encoder_hidden_states': _hidden,
      'use_cache_branch': WhisperTensor.boolean(cached, const [1]),
    };
    for (var i = 0; i < layers; i++) {
      for (final kind in const ['decoder', 'encoder']) {
        for (final kv in const ['key', 'value']) {
          final name = 'past_key_values.$i.$kind.$kv';
          inputs[name] = cached
              ? _cache![name]!
              : WhisperTensor.float(Float32List(kind == 'decoder' ? 0 : heads * headDim), [
                  1,
                  heads,
                  kind == 'decoder' ? 0 : 1,
                  headDim,
                ]);
        }
      }
    }
    final out = await _graph.run(inputs);
    runs++;
    final lg = out['logits'];
    final data = lg?.floats;
    if (lg == null || data == null || lg.shape.length != 3) {
      throw StateError('decoder graph returned no logits');
    }
    final seq = lg.shape[1];
    final v = lg.shape[2];
    if (v < vocabSize || data.length < seq * v) {
      throw StateError('unexpected logits shape ${lg.shape}');
    }
    await lg.dispose();
    final next = <String, WhisperTensor>{};
    for (var i = 0; i < layers; i++) {
      for (final kind in const ['decoder', 'encoder']) {
        for (final kv in const ['key', 'value']) {
          final name = 'past_key_values.$i.$kind.$kv';
          final present = out['present.$i.$kind.$kv'];
          if (present == null) {
            throw StateError('decoder graph returned no present.$i.$kind.$kv');
          }
          // Encoder K/V are only valid from the first (uncached) run.
          if (cached && kind == 'encoder') {
            await present.dispose(); // pass-through copy, keep the original
            next[name] = _cache![name]!;
          } else {
            next[name] = present;
          }
        }
      }
    }
    final old = _cache;
    if (old != null) {
      for (final e in old.entries) {
        if (!identical(next[e.key], e.value)) await e.value.dispose();
      }
    }
    _cache = next;
    _seen = tokens.length;
    return Float32List.sublistView(data, (seq - 1) * v, seq * v);
  }
}

/// Parses a Hugging Face `vocab.json` (token string -> id) into id -> token.
Map<int, String> parseWhisperVocab(String json) {
  final raw = jsonDecode(json);
  if (raw is! Map) throw const FormatException('vocab.json is not an object');
  final out = <int, String>{};
  raw.forEach((k, v) {
    if (k is String && v is int) out[v] = k;
  });
  if (out.length < 50000) {
    throw const FormatException('vocab.json too small for Whisper');
  }
  return out;
}

/// The Whisper [AutoTranscriber].
class WhisperTranscriber implements AutoTranscriber {
  WhisperTranscriber({
    required this.encoder,
    required this.decoder,
    required this.vocab,
    this.tokens = const WhisperTokens(),
    this.language,
    this.silencePeak = 33,
    this.layers = 4,
    this.heads = 6,
    this.headDim = 64,
  });

  final WhisperEncoder encoder;
  final WhisperDecoderGraph decoder;
  final Map<int, String> vocab;
  final WhisperTokens tokens;

  /// Fixed language code, or null to auto-detect per window.
  final String? language;

  /// Windows whose peak |sample| (Int16 scale) is below this are treated as
  /// silence and skipped (Whisper hallucinates on silence).
  final int silencePeak;
  final int layers;
  final int heads;
  final int headDim;

  @override
  String get name => 'Whisper tiny';

  @override
  Future<List<CaptionSegment>> transcribe(CaptionWindow window) async {
    var peak = 0;
    for (final s in window.samples) {
      final a = s < 0 ? -s : s;
      if (a > peak) peak = a;
    }
    if (peak < silencePeak) return const [];

    final pcm = window.samples;
    final rate = window.sampleRate;
    final mel = await Isolate.run(() => whisperFeaturesFromPcm(pcm, rate).data);
    final hidden = await encoder.encode(mel);

    CachedWhisperDecoderStep newStep() => CachedWhisperDecoderStep(
      decoder,
      hidden,
      layers: layers,
      heads: heads,
      headDim: headDim,
      vocabSize: tokens.vocabSize,
    );

    final detectStep = newStep();
    final decodeStep = newStep();
    final WhisperWindowResult result;
    final String? lang;
    try {
      lang = language ?? await _detectLanguage(detectStep);
      result = await greedyDecode(decodeStep, tokens, language: lang);
    } finally {
      await detectStep.close();
      await decodeStep.close();
      await hidden.dispose();
    }
    return segmentsFromTokens(result.tokens, vocab, tokens, windowMs: window.durationMs, language: lang);
  }

  Future<String?> _detectLanguage(WhisperDecoderStep step) async {
    final logits = await step.logits([tokens.sot]);
    var best = -1;
    var bestV = double.negativeInfinity;
    for (var i = 0; i < WhisperTokens.languages.length; i++) {
      final v = logits[tokens.firstLanguage + i];
      if (v > bestV) {
        bestV = v;
        best = i;
      }
    }
    return best < 0 ? null : WhisperTokens.languages[math.max(0, best)];
  }
}
