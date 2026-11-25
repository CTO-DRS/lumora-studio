/// Whisper token layer and greedy decoding loop (Wave 2 W3-M4).
///
/// Everything around the neural net, pure Dart and testable without a
/// model: special-token layout of the multilingual checkpoints, the decoder
/// prompt, a byte-level BPE text decoder (GPT-2 byte table), the timestamp
/// rules from the reference decoder, a bounded greedy loop over a pluggable
/// [WhisperDecoderStep], and conversion of timestamped tokens into
/// [CaptionSegment]s. The ONNX/LiteRT encoder-decoder implements
/// [WhisperDecoderStep] in the next milestone.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumora/features/video_editor/domain/captioning.dart';

/// Special-token ids of the multilingual Whisper checkpoints (vocab 51865:
/// tiny/base/small/medium/large-v2).
class WhisperTokens {
  const WhisperTokens({
    this.eot = 50257,
    this.sot = 50258,
    this.firstLanguage = 50259,
    this.translate = 50358,
    this.transcribe = 50359,
    this.noSpeech = 50362,
    this.noTimestamps = 50363,
    this.timestampBegin = 50364,
    this.vocabSize = 51865,
    this.maxTokens = 224,
  });

  final int eot;
  final int sot;
  final int firstLanguage;
  final int translate;
  final int transcribe;
  final int noSpeech;
  final int noTimestamps;
  final int timestampBegin;
  final int vocabSize;

  /// Hard cap on generated tokens per window (reference: 224).
  final int maxTokens;

  /// Language codes in checkpoint order (first 99, multilingual).
  static const List<String> languages = [
    'en',
    'zh',
    'de',
    'es',
    'ru',
    'ko',
    'fr',
    'ja',
    'pt',
    'tr',
    'pl',
    'ca',
    'nl',
    'ar',
    'sv',
    'it',
    'id',
    'hi',
    'fi',
    'vi',
    'he',
    'uk',
    'el',
    'ms',
    'cs',
    'ro',
    'da',
    'hu',
    'ta',
    'no',
    'th',
    'ur',
    'hr',
    'bg',
    'lt',
    'la',
    'mi',
    'ml',
    'cy',
    'sk',
    'te',
    'fa',
    'lv',
    'bn',
    'sr',
    'az',
    'sl',
    'kn',
    'et',
    'mk',
    'br',
    'eu',
    'is',
    'hy',
    'ne',
    'mn',
    'bs',
    'kk',
    'sq',
    'sw',
    'gl',
    'mr',
    'pa',
    'si',
    'km',
    'sn',
    'yo',
    'so',
    'af',
    'oc',
    'ka',
    'be',
    'tg',
    'sd',
    'gu',
    'am',
    'yi',
    'lo',
    'uz',
    'fo',
    'ht',
    'ps',
    'tk',
    'nn',
    'mt',
    'sa',
    'lb',
    'my',
    'bo',
    'tl',
    'mg',
    'as',
    'tt',
    'haw',
    'ln',
    'ha',
    'ba',
    'jw',
    'su',
  ];

  /// Token id for a language code, or null when unsupported.
  int? languageToken(String code) {
    final i = languages.indexOf(code.toLowerCase());
    return i < 0 ? null : firstLanguage + i;
  }

  /// Language code for a language token id, or null.
  String? languageOf(int token) {
    final i = token - firstLanguage;
    return i >= 0 && i < languages.length ? languages[i] : null;
  }

  bool isTimestamp(int token) => token >= timestampBegin && token < vocabSize;
  bool isSpecial(int token) => token >= eot && token < timestampBegin;

  /// Seconds for a timestamp token (0.02 s resolution).
  double timestampSeconds(int token) => (token - timestampBegin) * 0.02;

  /// Decoder prompt: `<|startoftranscript|>[<|lang|>]<|transcribe|>` plus
  /// `<|notimestamps|>` when [timestamps] is false.
  List<int> prompt({String? language, bool timestamps = true}) => [
    sot,
    if (language != null && languageToken(language) != null) languageToken(language)!,
    transcribe,
    if (!timestamps) noTimestamps,
  ];
}

/// One decoder step: given every token so far, return next-token logits
/// (length [WhisperTokens.vocabSize]). Implementations may keep a KV cache
/// keyed on the prefix length.
abstract interface class WhisperDecoderStep {
  Future<Float32List> logits(List<int> tokens);
}

/// GPT-2 byte <-> unicode table used by Whisper's byte-level BPE.
final Map<String, int> _unicodeToByte = () {
  final bs = <int>[
    for (var b = 33; b <= 126; b++) b,
    for (var b = 161; b <= 172; b++) b,
    for (var b = 174; b <= 255; b++) b,
  ];
  final cs = List<int>.of(bs);
  var n = 0;
  for (var b = 0; b < 256; b++) {
    if (!bs.contains(b)) {
      bs.add(b);
      cs.add(256 + n);
      n++;
    }
  }
  return {for (var i = 0; i < bs.length; i++) String.fromCharCode(cs[i]): bs[i]};
}();

/// Decodes text token ids to a string through a vocab of byte-level BPE
/// pieces. Specials and timestamps are skipped; invalid UTF-8 (a character
/// split across tokens at the window edge) becomes U+FFFD, never throws.
String decodeTextTokens(List<int> tokens, Map<int, String> vocab, WhisperTokens t) {
  final bytes = <int>[];
  for (final id in tokens) {
    if (id >= t.eot) continue;
    final piece = vocab[id];
    if (piece == null) continue;
    for (final ch in piece.split('')) {
      final b = _unicodeToByte[ch];
      if (b != null) bytes.add(b);
    }
  }
  return utf8.decode(bytes, allowMalformed: true);
}

/// Result of decoding one 30 s window.
class WhisperWindowResult {
  const WhisperWindowResult({required this.tokens, required this.language, required this.truncated});

  /// Generated tokens (no prompt, no trailing eot).
  final List<int> tokens;
  final String? language;

  /// True when the loop hit the token cap or the repetition guard.
  final bool truncated;
}

/// Greedy decode with the reference timestamp rules:
/// * never emit `<|notimestamps|>`, sot, translate or transcribe again;
/// * timestamps come in pairs: after one timestamp the next token is a
///   timestamp or eot, after a pair the next is text or eot;
/// * timestamps never go backwards;
/// * at the start, a timestamp is forced (no text before the first one);
/// * if the summed probability of timestamps beats the best text token,
///   a timestamp is forced.
/// A repetition guard stops loops (same token 12 times in a row).
Future<WhisperWindowResult> greedyDecode(WhisperDecoderStep step, WhisperTokens t, {String? language, bool timestamps = true}) async {
  final prompt = t.prompt(language: language, timestamps: timestamps);
  final tokens = List<int>.of(prompt);
  var truncated = false;
  var run = 0;
  var prev = -1;
  while (tokens.length - prompt.length < t.maxTokens) {
    final logits = Float32List.fromList(await step.logits(tokens));
    if (logits.length < t.vocabSize) {
      throw StateError(
        'decoder returned ${logits.length} logits, '
        'expected ${t.vocabSize}',
      );
    }
    for (final id in [t.sot, t.translate, t.transcribe, t.noTimestamps]) {
      logits[id] = double.negativeInfinity;
    }
    if (timestamps) {
      final gen = tokens.sublist(prompt.length);
      final lastWasTs = gen.isNotEmpty && t.isTimestamp(gen.last);
      final penultTs = gen.length < 2 || t.isTimestamp(gen[gen.length - 2]);
      if (lastWasTs) {
        if (penultTs) {
          // pair complete: text or eot only
          for (var i = t.timestampBegin; i < t.vocabSize; i++) {
            logits[i] = double.negativeInfinity;
          }
        } else {
          // opened a timestamp: next is timestamp or eot
          for (var i = 0; i < t.eot; i++) {
            logits[i] = double.negativeInfinity;
          }
        }
      }
      final ts = gen.where(t.isTimestamp).toList();
      if (ts.isNotEmpty) {
        final floor = lastWasTs && !penultTs ? ts.last : ts.last + 1;
        for (var i = t.timestampBegin; i < floor && i < t.vocabSize; i++) {
          logits[i] = double.negativeInfinity;
        }
      }
      if (gen.isEmpty) {
        for (var i = 0; i < t.timestampBegin; i++) {
          logits[i] = double.negativeInfinity;
        }
      } else {
        // timestamp-vs-text probability rule
        var maxAll = double.negativeInfinity;
        for (final v in logits) {
          if (v > maxAll) maxAll = v;
        }
        var tsSum = 0.0;
        for (var i = t.timestampBegin; i < t.vocabSize; i++) {
          if (logits[i].isFinite) tsSum += math.exp(logits[i] - maxAll);
        }
        var maxText = double.negativeInfinity;
        for (var i = 0; i < t.timestampBegin; i++) {
          if (logits[i] > maxText) maxText = logits[i];
        }
        final textP = maxText.isFinite ? math.exp(maxText - maxAll) : 0.0;
        if (tsSum > textP && tsSum > 0) {
          for (var i = 0; i < t.timestampBegin; i++) {
            logits[i] = double.negativeInfinity;
          }
        }
      }
    }
    var best = -1;
    var bestV = double.negativeInfinity;
    for (var i = 0; i < t.vocabSize; i++) {
      if (logits[i] > bestV) {
        bestV = logits[i];
        best = i;
      }
    }
    if (best < 0 || best == t.eot) break;
    run = best == prev ? run + 1 : 1;
    prev = best;
    tokens.add(best);
    if (run >= 12) {
      truncated = true;
      break;
    }
  }
  if (tokens.length - prompt.length >= t.maxTokens) truncated = true;
  return WhisperWindowResult(tokens: tokens.sublist(prompt.length), language: language, truncated: truncated);
}

/// Converts timestamped tokens to segments (times relative to the window).
/// Text tokens between a timestamp pair form one segment. If the window ends
/// mid-segment (no closing timestamp) the segment runs to [windowMs].
List<CaptionSegment> segmentsFromTokens(
  List<int> tokens,
  Map<int, String> vocab,
  WhisperTokens t, {
  required int windowMs,
  String? language,
}) {
  final out = <CaptionSegment>[];
  int? start;
  final buf = <int>[];
  void flush(int endMs) {
    final text = decodeTextTokens(buf, vocab, t).trim();
    if (text.isNotEmpty && start != null) {
      final s = start.clamp(0, windowMs);
      final e = endMs.clamp(s, windowMs);
      out.add(CaptionSegment(startMs: s, endMs: e, text: text, language: language));
    }
    buf.clear();
  }

  for (final id in tokens) {
    if (t.isTimestamp(id)) {
      final ms = (t.timestampSeconds(id) * 1000).round();
      if (start == null) {
        start = ms;
      } else if (buf.isEmpty) {
        start = ms; // empty pair: restart
      } else {
        flush(ms);
        start = null;
      }
    } else if (id < t.eot) {
      start ??= 0;
      buf.add(id);
    }
  }
  if (buf.isNotEmpty) flush(windowMs);
  return out;
}
