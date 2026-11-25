import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/video_editor/domain/whisper_decoding.dart';

const t = WhisperTokens();

/// Scripted decoder: emits `script[n]` as the argmax at step n.
class _Script implements WhisperDecoderStep {
  _Script(this.script);
  final List<int> script;
  int calls = 0;
  @override
  Future<Float32List> logits(List<int> tokens) async {
    final l = Float32List(t.vocabSize)..fillRange(0, t.vocabSize, -10);
    final i = calls++;
    l[i < script.length ? script[i] : t.eot] = 10;
    return l;
  }
}

int ts(double s) => t.timestampBegin + (s / 0.02).round();

void main() {
  group('tokens', () {
    test('layout and language lookup', () {
      expect(t.languageToken('en'), 50259);
      expect(t.languageToken('ar'), 50272);
      expect(t.languageOf(50272), 'ar');
      expect(t.languageToken('xx'), isNull);
      expect(t.isTimestamp(ts(1)), isTrue);
      expect(t.isSpecial(t.sot), isTrue);
      expect(t.timestampSeconds(ts(2.5)), closeTo(2.5, 1e-9));
    });

    test('prompt variants', () {
      expect(t.prompt(language: 'ar'), [50258, 50272, 50359]);
      expect(t.prompt(timestamps: false), [50258, 50359, 50363]);
      expect(t.prompt(language: 'zz'), [50258, 50359]);
    });
  });

  group('text decoding', () {
    // Byte-level pieces: 'Ġ' (U+0120) is the space byte; Arabic "م" is
    // bytes D9 85 which map to two unicode chars.
    final vocab = <int, String>{
      1: 'Hello',
      2: '\u0120world',
      3: '\u00d9',
      4: '\u0127', // 0x85
    };
    test('spaces and ascii', () {
      expect(decodeTextTokens([1, 2], vocab, t), 'Hello world');
    });
    test('multibyte character split across tokens', () {
      expect(decodeTextTokens([3, 4], vocab, t), 'م');
    });
    test('half a character does not throw', () {
      expect(decodeTextTokens([3], vocab, t), contains('\uFFFD'));
    });
    test('specials and unknown ids are skipped', () {
      expect(decodeTextTokens([1, t.eot, ts(1), 999], vocab, t), 'Hello');
    });
  });

  group('greedy decode', () {
    test('forces a timestamp first, pairs, then stops at eot', () async {
      final d = _Script([ts(0), 1, ts(1.5), t.eot]);
      final r = await greedyDecode(d, t, language: 'en');
      expect(r.tokens, [ts(0), 1, ts(1.5)]);
      expect(r.truncated, isFalse);
      expect(r.language, 'en');
    });

    test('text before the first timestamp is suppressed', () async {
      final step = _FixedLogits((tokens) {
        final l = Float32List(t.vocabSize)..fillRange(0, t.vocabSize, -10);
        if (tokens.length == 3) {
          l[5] = 9; // text wins on raw logits
          l[ts(0.4)] = 1;
        } else {
          l[t.eot] = 9;
        }
        return l;
      });
      final r = await greedyDecode(step, t, language: 'en');
      expect(r.tokens, [ts(0.4)]);
    });

    test('timestamps never go backwards', () async {
      final d = _FixedLogits((tokens) {
        final l = Float32List(t.vocabSize)..fillRange(0, t.vocabSize, -10);
        final n = tokens.length - 3;
        if (n == 0) {
          l[ts(2)] = 9;
        } else if (n == 1) {
          l[7] = 9;
        } else if (n == 2) {
          l[ts(1)] = 9; // earlier than 2 s: must be suppressed
          l[ts(3)] = 5;
        } else {
          l[t.eot] = 9;
        }
        return l;
      });
      final r = await greedyDecode(d, t, language: 'en');
      expect(r.tokens.last, ts(3));
    });

    test('special control tokens are never emitted', () async {
      final d = _FixedLogits((tokens) {
        final l = Float32List(t.vocabSize)..fillRange(0, t.vocabSize, -10);
        l[t.noTimestamps] = 50;
        l[t.transcribe] = 49;
        l[t.sot] = 48;
        if (tokens.length == 3) l[ts(0)] = 1;
        if (tokens.length > 3) l[t.eot] = 1;
        return l;
      });
      final r = await greedyDecode(d, t, language: 'en');
      expect(r.tokens, [ts(0)]);
    });

    test('repetition guard truncates a loop', () async {
      final d = _FixedLogits((tokens) {
        final l = Float32List(t.vocabSize)..fillRange(0, t.vocabSize, -10);
        l[tokens.length == 3 ? ts(0) : 42] = 9;
        return l;
      });
      final r = await greedyDecode(d, t, language: 'en');
      expect(r.truncated, isTrue);
      expect(r.tokens.length, lessThan(30));
    });

    test('token cap truncates', () async {
      const small = WhisperTokens(maxTokens: 6);
      var n = 0;
      final d = _FixedLogits((tokens) {
        final l = Float32List(small.vocabSize)..fillRange(0, small.vocabSize, -10);
        l[100 + (n++ % 2)] = 9;
        return l;
      });
      final r = await greedyDecode(d, small, timestamps: false);
      expect(r.tokens.length, 6);
      expect(r.truncated, isTrue);
    });

    test('wrong logits length is a StateError', () async {
      final d = _FixedLogits((_) => Float32List(10));
      await expectLater(greedyDecode(d, t), throwsStateError);
    });
  });

  group('segments', () {
    final vocab = <int, String>{1: 'Hi', 2: '\u0120there', 3: 'Bye'};
    test('pairs become segments', () {
      final s = segmentsFromTokens([ts(0), 1, 2, ts(1.5), ts(2), 3, ts(3)], vocab, t, windowMs: 30000, language: 'en');
      expect(s.length, 2);
      expect(s[0].text, 'Hi there');
      expect(s[0].startMs, 0);
      expect(s[0].endMs, 1500);
      expect(s[1].text, 'Bye');
      expect(s[1].startMs, 2000);
      expect(s[1].language, 'en');
    });

    test('unterminated segment runs to window end', () {
      final s = segmentsFromTokens([ts(4), 1], vocab, t, windowMs: 10000);
      expect(s.single.endMs, 10000);
    });

    test('times are clamped to the window', () {
      final s = segmentsFromTokens([ts(9), 1, ts(40)], vocab, t, windowMs: 10000);
      expect(s.single.endMs, 10000);
    });

    test('empty and text-only inputs are safe', () {
      expect(segmentsFromTokens([], vocab, t, windowMs: 1000), isEmpty);
      expect(segmentsFromTokens([1], vocab, t, windowMs: 1000).single.text, 'Hi');
      expect(segmentsFromTokens([ts(0), ts(1)], vocab, t, windowMs: 1000), isEmpty);
    });
  });
}

class _FixedLogits implements WhisperDecoderStep {
  _FixedLogits(this.fn);
  final Float32List Function(List<int>) fn;
  @override
  Future<Float32List> logits(List<int> tokens) async => fn(tokens);
}
