import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/video_editor/domain/subtitles.dart';

/// Roadmap §6 fuzz gate for the SRT/VTT writers and the subtitle JSON
/// layer (parsers are gated by subtitle_fuzz_test.dart). Two contracts:
/// writers never throw or hang on arbitrary cue data, and a sanitised
/// track round-trips through both formats exactly.
void main() {
  final rng = Random(20261128);

  const alphabet = 'abz ABZ019 \n.,:;!-»–\tأبجدحخWEBVTarrow-->WEBVTT';

  String garbage(int maxLen) {
    final len = rng.nextInt(maxLen);
    return String.fromCharCodes(List.generate(len, (_) => alphabet.codeUnitAt(rng.nextInt(alphabet.length))));
  }

  /// Arbitrary cue: possibly negative or inverted times, hostile text.
  /// Times stay under 100 hours — the writer contract is 3-digit hours.
  SubtitleCue anyCue() {
    final a = rng.nextInt(360000000) - 5000;
    final b = rng.nextInt(360000000) - 5000;
    return SubtitleCue(startMs: a, endMs: b, text: garbage(120));
  }

  SubtitleTrack anyTrack() => SubtitleTrack(
    language: rng.nextBool() ? 'ar' : 'en',
    durationMs: rng.nextBool() ? rng.nextInt(360000000) : 0,
    cues: [for (var i = 0; i < rng.nextInt(8); i++) anyCue()],
  );

  test('400 hostile tracks: writers never throw and output stays bounded', () {
    for (var i = 0; i < 400; i++) {
      final t = anyTrack();
      final srt = writeSrt(t);
      final vtt = writeVtt(t);
      final textLen = t.cues.fold<int>(0, (a, c) => a + c.text.length);
      // Each cue adds one timing line + numbering; nothing may balloon.
      expect(srt.length, lessThan(textLen + 200 * (t.cues.length + 1)));
      expect(vtt.length, lessThan(textLen + 200 * (t.cues.length + 1) + 10));
      expect(vtt.startsWith('WEBVTT\n'), isTrue);
    }
  });

  test('sanitised tracks round-trip through SRT exactly', () {
    for (var i = 0; i < 400; i++) {
      final s = anyTrack().sanitised();
      final parsed = parseSrt(writeSrt(s), language: s.language);
      expect(parsed.cues.length, s.cues.length, reason: 'case $i lost a cue');
      for (var j = 0; j < s.cues.length; j++) {
        expect(parsed.cues[j].startMs, s.cues[j].startMs, reason: 'case $i cue $j start');
        expect(parsed.cues[j].endMs, s.cues[j].endMs, reason: 'case $i cue $j end');
        expect(parsed.cues[j].text, s.cues[j].text, reason: 'case $i cue $j text');
      }
    }
  });

  test('sanitised tracks round-trip through VTT exactly', () {
    for (var i = 0; i < 400; i++) {
      final s = anyTrack().sanitised();
      final parsed = parseVtt(writeVtt(s), language: s.language);
      expect(parsed.cues.length, s.cues.length, reason: 'case $i lost a cue');
      for (var j = 0; j < s.cues.length; j++) {
        expect(parsed.cues[j].startMs, s.cues[j].startMs, reason: 'case $i cue $j start');
        expect(parsed.cues[j].endMs, s.cues[j].endMs, reason: 'case $i cue $j end');
        expect(parsed.cues[j].text, s.cues[j].text, reason: 'case $i cue $j text');
      }
    }
  });

  test('subtitle JSON: hostile maps never crash fromJson', () {
    for (var i = 0; i < 300; i++) {
      final map = <String, dynamic>{
        'language': rng.nextBool() ? garbage(8) : rng.nextInt(100),
        'durationMs': rng.nextBool() ? garbage(6) : rng.nextInt(1000000),
        'cues': rng.nextBool()
            ? garbage(20)
            : [
                for (var j = 0; j < rng.nextInt(4); j++)
                  rng.nextBool()
                      ? garbage(10)
                      : <String, dynamic>{
                          'startMs': rng.nextBool() ? garbage(5) : rng.nextInt(100000),
                          'endMs': rng.nextBool() ? rng.nextInt(100000) : null,
                          'text': rng.nextBool() ? garbage(30) : rng.nextInt(50),
                        },
              ],
      };
      // Bounded rejection (TypeError/FormatException — the recipe loader
      // catches them) or a parse; never a hang, RangeError or worse.
      expect(
        () => SubtitleTrack.fromJson(map),
        anyOf(returnsNormally, throwsA(isA<TypeError>()), throwsA(isA<FormatException>())),
      );
    }
  });

  test('subtitle JSON round-trips arbitrary valid tracks', () {
    for (var i = 0; i < 200; i++) {
      final t = anyTrack();
      final back = SubtitleTrack.fromJson(t.toJson());
      expect(back.cues.length, t.cues.length, reason: 'case $i');
      expect(back.language, t.language);
      expect(back.durationMs, t.durationMs);
      for (var j = 0; j < t.cues.length; j++) {
        expect(back.cues[j].startMs, t.cues[j].startMs, reason: 'case $i cue $j');
        expect(back.cues[j].endMs, t.cues[j].endMs, reason: 'case $i cue $j');
        expect(back.cues[j].text, t.cues[j].text, reason: 'case $i cue $j');
      }
    }
  });
}
