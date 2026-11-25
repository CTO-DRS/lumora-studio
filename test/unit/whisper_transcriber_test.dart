import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:lumora/features/video_editor/domain/captioning.dart';
import 'package:lumora/features/video_editor/domain/whisper_decoding.dart';
import 'package:lumora/features/video_editor/domain/whisper_transcriber.dart';

const t = WhisperTokens();
int ts(double s) => t.timestampBegin + (s / 0.02).round();

/// Fake merged-decoder graph. Emits `script[n]` as argmax at call n and
/// returns present tensors whose decoder length grows like the real graph.
class _FakeGraph implements WhisperDecoderGraph {
  _FakeGraph(this.script);
  final List<int> script;
  final int layers = 4;
  final List<Map<String, WhisperTensor>> seen = [];
  int _total = 0; // tokens consumed by the "model"

  @override
  Future<Map<String, WhisperTensor>> run(Map<String, WhisperTensor> inputs) async {
    seen.add(inputs);
    final n = inputs['input_ids']!.shape[1];
    final cached = inputs['use_cache_branch']!.flag!;
    if (!cached) _total = 0;
    final pastLen = inputs['past_key_values.0.decoder.key']!.shape[2];
    expect(pastLen, cached ? _total : 0);
    _total += n;
    final call = seen.length - 1;
    final logits = Float32List(n * t.vocabSize)..fillRange(0, n * t.vocabSize, -10);
    final target = call < script.length ? script[call] : t.eot;
    logits[(n - 1) * t.vocabSize + target] = 10;
    final out = <String, WhisperTensor>{
      'logits': WhisperTensor.float(logits, [1, n, t.vocabSize]),
    };
    for (var i = 0; i < layers; i++) {
      for (final kv in ['key', 'value']) {
        out['present.$i.decoder.$kv'] = WhisperTensor.float(Float32List(6 * _total * 64), [1, 6, _total, 64]);
        // Real graph returns fresh encoder K/V only on the uncached run.
        out['present.$i.encoder.$kv'] = WhisperTensor.float(Float32List(6 * 1500 * 64), [1, 6, cached ? 1 : 1500, 64]);
      }
    }
    return out;
  }
}

class _FakeEncoder implements WhisperEncoder {
  int calls = 0;
  @override
  Future<WhisperTensor> encode(Float32List logMel) async {
    calls++;
    expect(logMel.length, 80 * 3000);
    return WhisperTensor.float(Float32List(0), const [1, 1500, 384]);
  }
}

WhisperTensor get _hidden => WhisperTensor.float(Float32List(0), const [1, 1500, 384]);

Int16List _tone(int rate, double seconds) {
  final p = Int16List((rate * seconds).round());
  for (var i = 0; i < p.length; i++) {
    p[i] = (8000 * math.sin(2 * math.pi * 440 * i / rate)).round();
  }
  return p;
}

void main() {
  group('CachedWhisperDecoderStep', () {
    test('first call feeds the whole prompt, later calls only the newest token', () async {
      final g = _FakeGraph([ts(0), 10, ts(1)]);
      final step = CachedWhisperDecoderStep(g, _hidden);
      final prompt = t.prompt(language: 'en');
      await step.logits(prompt);
      await step.logits([...prompt, ts(0)]);
      await step.logits([...prompt, ts(0), 10]);
      expect(g.seen[0]['input_ids']!.ints!.length, 3);
      expect(g.seen[0]['use_cache_branch']!.flag, isFalse);
      expect(g.seen[1]['input_ids']!.ints!.toList(), [ts(0)]);
      expect(g.seen[1]['use_cache_branch']!.flag, isTrue);
      expect(g.seen[2]['input_ids']!.ints!.toList(), [10]);
      // decoder cache grows 3 -> 4 -> 5, encoder cache reused from run 1
      expect(g.seen[2]['past_key_values.0.decoder.key']!.shape[2], 4);
      expect(g.seen[2]['past_key_values.3.encoder.value']!.shape[2], 1500);
      expect(step.runs, 3);
    });

    test('a changed prefix resets the cache', () async {
      final g = _FakeGraph([1, 2]);
      final step = CachedWhisperDecoderStep(g, _hidden);
      await step.logits([t.sot]);
      await step.logits([t.sot, t.transcribe, 5]); // jumped ahead
      expect(g.seen[1]['use_cache_branch']!.flag, isFalse);
      expect(g.seen[1]['input_ids']!.ints!.length, 3);
    });

    test('missing logits or present tensors are errors', () async {
      final bad = _BadGraph(dropLogits: true);
      await expectLater(CachedWhisperDecoderStep(bad, _hidden).logits([t.sot]), throwsStateError);
      final bad2 = _BadGraph(dropLogits: false);
      await expectLater(CachedWhisperDecoderStep(bad2, _hidden).logits([t.sot]), throwsStateError);
      await expectLater(CachedWhisperDecoderStep(_FakeGraph([]), _hidden).logits([]), throwsArgumentError);
    });

    test('works end to end with greedyDecode', () async {
      final g = _FakeGraph([ts(0), 10, 11, ts(2), t.eot]);
      final r = await greedyDecode(CachedWhisperDecoderStep(g, _hidden), t, language: 'ar');
      expect(r.tokens, [ts(0), 10, 11, ts(2)]);
      expect(g.seen.length, 5);
    });
  });

  group('tensor lifetime', () {
    test('caches are released: replaced tensors and close()', () async {
      var live = 0;
      final g = _TrackingGraph(() => live++, () => live--);
      final step = CachedWhisperDecoderStep(g, _hidden);
      await step.logits([t.sot]);
      final afterFirst = live;
      await step.logits([t.sot, 5]);
      await step.logits([t.sot, 5, 6]);
      // steady state: no leak across cached steps
      expect(live, afterFirst);
      await step.close();
      expect(live, 0);
    });
  });

  group('registry', () {
    test('Whisper specs are pinned, checksummed and listed with a v1.5 mirror', () {
      expect(ModelRegistry.speech.length, 3);
      final ids = <String>{};
      for (final m in ModelRegistry.speech) {
        expect(ids.add(m.id), isTrue);
        expect(m.task, AiTask.speechRecognition);
        expect(m.url, startsWith('https://huggingface.co/onnx-community/whisper-tiny/resolve/'));
        expect(m.url, isNot(contains('/resolve/main/')), reason: 'revision-pinned');
        expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(m.sha256), isTrue);
        expect(m.license, contains('Apache-2.0'));
        expect(ModelRegistry.all, contains(m));
        expect(m.mirrorUrl, startsWith('https://github.com/CTO-DRS/lumora-studio/releases/download/models-v1.5/'));
      }
      expect(ModelRegistry.whisperTinyEncoder.fileName, endsWith('.onnx'));
      expect(ModelRegistry.whisperTinyVocab.fileName, 'whisper_tiny_vocab.json');
      // ~41 MB of graphs, in line with the roadmap's 40 MB budget.
      final graphMb = ModelRegistry.whisperTinyEncoder.sizeMb + ModelRegistry.whisperTinyDecoder.sizeMb;
      expect(graphMb, inInclusiveRange(38, 45));
    });
  });

  group('vocab', () {
    test('parseWhisperVocab inverts the file', () {
      final m = {for (var i = 0; i < 50300; i++) 'tok$i': i};
      final v = parseWhisperVocab(jsonEncode(m));
      expect(v[7], 'tok7');
    });
    test('rejects junk', () {
      expect(() => parseWhisperVocab('[]'), throwsFormatException);
      expect(() => parseWhisperVocab('{"a":1}'), throwsFormatException);
    });
  });

  group('WhisperTranscriber', () {
    final vocab = <int, String>{10: 'Hello', 11: '\u0120world'};
    CaptionWindow win(Int16List s, int rate) => CaptionWindow(index: 0, startMs: 0, samples: s, sampleRate: rate);

    test('silence is skipped without touching the model', () async {
      final enc = _FakeEncoder();
      final tr = WhisperTranscriber(encoder: enc, decoder: _FakeGraph([]), vocab: vocab, language: 'en');
      expect(await tr.transcribe(win(Int16List(16000), 16000)), isEmpty);
      expect(enc.calls, 0);
    });

    test('transcribes a window into timed segments', () async {
      final enc = _FakeEncoder();
      final tr = WhisperTranscriber(
        encoder: enc,
        decoder: _FakeGraph([ts(0.5), 10, 11, ts(2.5), t.eot]),
        vocab: vocab,
        language: 'en',
      );
      final seg = await tr.transcribe(win(_tone(16000, 3), 16000));
      expect(enc.calls, 1);
      expect(seg.length, 1);
      expect(seg.single.text, 'Hello world');
      expect(seg.single.startMs, 500);
      expect(seg.single.endMs, 2500);
      expect(seg.single.language, 'en');
    });

    test('resamples other rates and clamps to the window', () async {
      final tr = WhisperTranscriber(
        encoder: _FakeEncoder(),
        decoder: _FakeGraph([ts(0), 10, ts(20), t.eot]),
        vocab: vocab,
        language: 'en',
      );
      final seg = await tr.transcribe(win(_tone(22050, 2), 22050));
      expect(seg.single.endMs, lessThanOrEqualTo(2000));
    });

    test('auto-detects the language from the first step', () async {
      // Call 0 is the detection step and must pick Arabic (50272).
      final g = _FakeGraph([50272, ts(0), 10, ts(1), t.eot]);
      final tr = WhisperTranscriber(encoder: _FakeEncoder(), decoder: g, vocab: vocab);
      final seg = await tr.transcribe(win(_tone(16000, 2), 16000));
      expect(seg.single.language, 'ar');
      // Detection used [sot] only, the real decode then started with the
      // Arabic prompt.
      expect(g.seen[0]['input_ids']!.ints!.toList(), [t.sot]);
      expect(g.seen[1]['input_ids']!.ints!.toList(), [t.sot, 50272, t.transcribe]);
    });

    test('exposes a display name', () async {
      final tr = WhisperTranscriber(
        encoder: _FakeEncoder(),
        decoder: _FakeGraph([ts(0), 10, ts(1), t.eot]),
        vocab: vocab,
        language: 'en',
      );
      final seg = await tr.transcribe(win(_tone(16000, 2), 16000));
      expect(seg, isNotEmpty);
      expect(tr.name, contains('Whisper'));
    });
  });
}

class _BadGraph implements WhisperDecoderGraph {
  _BadGraph({required this.dropLogits});
  final bool dropLogits;
  @override
  Future<Map<String, WhisperTensor>> run(Map<String, WhisperTensor> inputs) async {
    if (dropLogits) return {};
    return {
      'logits': WhisperTensor.float(Float32List(t.vocabSize), [1, 1, t.vocabSize]),
    };
  }
}

/// Graph returning opaque tensors that count live handles.
class _TrackingGraph implements WhisperDecoderGraph {
  _TrackingGraph(this.onCreate, this.onFree);
  final void Function() onCreate;
  final void Function() onFree;
  int _n = 0;

  WhisperTensor _opaque(List<int> shape) {
    onCreate();
    var freed = false;
    return WhisperTensor.opaque(
      Object(),
      shape,
      onDispose: () async {
        if (!freed) {
          freed = true;
          onFree();
        }
      },
    );
  }

  @override
  Future<Map<String, WhisperTensor>> run(Map<String, WhisperTensor> inputs) async {
    final n = inputs['input_ids']!.shape[1];
    _n += n;
    final logits = Float32List(n * t.vocabSize);
    final out = <String, WhisperTensor>{
      'logits': WhisperTensor.float(logits, [1, n, t.vocabSize]),
    };
    for (var i = 0; i < 4; i++) {
      for (final kind in ['decoder', 'encoder']) {
        for (final kv in ['key', 'value']) {
          out['present.$i.$kind.$kv'] = _opaque([1, 6, _n, 64]);
        }
      }
    }
    return out;
  }
}
