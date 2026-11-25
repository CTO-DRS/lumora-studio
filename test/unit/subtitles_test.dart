/// Wave 2 W3-M1 tests: subtitle infrastructure — data model + JSON
/// round-trip, SRT/VTT writers and strict parsers (incl. fuzz gates),
/// sanitisation, and the Arabic dialect-tolerant caption pass.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/video_editor/domain/subtitles.dart';

void main() {
  group('data model', () {
    test('cues sort by start time', () {
      final track = SubtitleTrack(
        language: 'ar',
        cues: [
          const SubtitleCue(startMs: 5000, endMs: 6000, text: 'ثالث'),
          const SubtitleCue(startMs: 0, endMs: 1000, text: 'أول'),
          const SubtitleCue(startMs: 2000, endMs: 3000, text: 'ثان'),
        ],
      );
      expect(track.cues.map((c) => c.text).toList(), ['أول', 'ثان', 'ثالث']);
    });

    test('cueAt finds the visible caption', () {
      final track = SubtitleTrack(language: 'en', cues: const [
        SubtitleCue(startMs: 1000, endMs: 2000, text: 'hello'),
      ]);
      expect(track.cueAt(999), isNull);
      expect(track.cueAt(1000)?.text, 'hello');
      expect(track.cueAt(1500)?.text, 'hello');
      expect(track.cueAt(2000), isNull);
    });

    test('JSON round-trip keeps cues and word timings', () {
      final track = SubtitleTrack(
        language: 'ar',
        durationMs: 60000,
        cues: const [
          SubtitleCue(startMs: 100, endMs: 1500, text: 'مرحبا بالعالم', words: [
            SubtitleWord(text: 'مرحبا', startMs: 100, endMs: 800),
            SubtitleWord(text: 'بالعالم', startMs: 800, endMs: 1500),
          ]),
          SubtitleCue(startMs: 2000, endMs: 3600, text: 'سطران\nفي تسمية'),
        ],
      );
      final back = SubtitleTrack.fromJson(track.toJson());
      expect(back.language, 'ar');
      expect(back.durationMs, 60000);
      expect(back.length, 2);
      expect(back.cues.first.words.length, 2);
      expect(back.cues.first.words[1].text, 'بالعالم');
      expect(back.cues[1].text, 'سطران\nفي تسمية');
    });

    test('sanitised drops invalid cues and truncates overlaps', () {
      final track = SubtitleTrack(
        language: 'en',
        durationMs: 10000,
        cues: const [
          SubtitleCue(startMs: 500, endMs: 0, text: 'invalid'), // dropped
          SubtitleCue(startMs: 9000, endMs: 12000, text: 'clamped'), // clamped to 10000
          SubtitleCue(startMs: 1000, endMs: 3000, text: 'first'),
          SubtitleCue(startMs: 2000, endMs: 4000, text: 'second'), // overlap truncated
        ],
      ).sanitised();
      expect(track.length, 3);
      expect(track.cues[0].text, 'first');
      expect(track.cues[0].endMs, 2000); // yields to the next cue
      expect(track.cues[1].text, 'second');
      expect(track.cues[1].endMs, 4000);
      expect(track.cues[2].endMs, 10000); // clamped to duration
    });
  });

  group('SRT writer/parser', () {
    final track = SubtitleTrack(
      language: 'ar',
      cues: [
        const SubtitleCue(startMs: 1000, endMs: 3500, text: 'مرحباً بالعالم'),
        const SubtitleCue(startMs: 3600, endMs: 7250, text: 'سطر أول\nسطر ثانٍ'),
      ],
    );

    test('writer emits numbered blocks with comma clock', () {
      final srt = writeSrt(track);
      expect(srt, contains('00:00:01,000 --> 00:00:03,500'));
      expect(srt, contains('00:00:03,600 --> 00:00:07,250'));
      expect(srt, contains('مرحباً بالعالم'));
      expect(srt, startsWith('1\n'));
    });

    test('round-trip SRT → parse → identical cues', () {
      final back = parseSrt(writeSrt(track), language: 'ar');
      expect(back.length, 2);
      expect(back.cues[0].startMs, 1000);
      expect(back.cues[0].endMs, 3500);
      expect(back.cues[0].text, 'مرحباً بالعالم');
      expect(back.cues[1].text, 'سطر أول\nسطر ثانٍ');
    });

    test('parser accepts hours ≥ 100 and fractional seconds of any digit count', () {
      const srt = '1\n101:00:00,5 --> 101:00:02,50\nطويل\n';
      final back = parseSrt(srt);
      expect(back.cues.first.startMs, ((101 * 60 + 0) * 60 + 0) * 1000 + 500);
      expect(back.cues.first.endMs, ((101 * 60 + 0) * 60 + 2) * 1000 + 500);
    });

    test('fuzz: garbage input raises a bounded format error', () {
      expect(() => parseSrt('not a subtitle at all'), throwsA(isA<SubtitleFormatException>()));
      expect(() => parseSrt('1\n00:00:99,000 --> 00:00:01,000\ntext\n'), throwsA(isA<SubtitleFormatException>()));
      expect(
        () => parseSrt('1\n00:00:01,000 --> 00:00:02,000\n'),
        throwsA(isA<SubtitleFormatException>()), // empty cue
      );
    });

    test('fuzz: truncated file does not hang and yields what it read', () {
      const srt = '1\n00:00:01,000 --> 00:00:02,000\nنص مكتمل\n\n2\n00:00:03,000 --> ';
      final back = parseSrt(srt);
      expect(back.length, 1);
      expect(back.cues.first.text, 'نص مكتمل');
    });

    test('fuzz: pathological long input is bounded, not quadratic', () {
      final buf = StringBuffer();
      // One cue past the parser cap → explicit bounded error, no hang.
      for (var i = 0; i < 50001; i++) {
        buf.writeln('${i + 1}\n00:${(i ~/ 60) % 60}:${i % 60},000 --> 00:${(i ~/ 60) % 60}:${i % 60},500\nx\n');
      }
      expect(() => parseSrt(buf.toString()), throwsA(isA<SubtitleFormatException>()));
    });
  });

  group('VTT writer/parser', () {
    final track = SubtitleTrack(language: 'en', cues: [
      const SubtitleCue(startMs: 500, endMs: 2000, text: 'Hello world'),
      const SubtitleCue(startMs: 2500, endMs: 4000, text: 'Second caption'),
    ]);

    test('writer emits the WEBVTT header and dot clock', () {
      final vtt = writeVtt(track);
      expect(vtt, startsWith('WEBVTT\n'));
      expect(vtt, contains('00:00:00.500 --> 00:00:02.000'));
    });

    test('round-trip VTT → parse → identical cues', () {
      final back = parseVtt(writeVtt(track), language: 'en');
      expect(back.length, 2);
      expect(back.cues[0].startMs, 500);
      expect(back.cues[1].text, 'Second caption');
    });

    test('parser tolerates NOTE blocks and cue identifiers', () {
      const vtt = 'WEBVTT\n\nNOTE this is a comment\n\nintro\n00:00:01.000 --> 00:00:02.000\ncaption\n';
      final back = parseVtt(vtt);
      expect(back.length, 1);
      expect(back.cues.first.text, 'caption');
    });

    test('fuzz: missing header and garbage raise', () {
      expect(() => parseVtt(''), throwsA(isA<SubtitleFormatException>()));
      expect(() => parseVtt('WEBVTT\n\n00:61:00.000 --> 00:62:00.000\nx\n'), throwsA(isA<SubtitleFormatException>()));
    });

    test('SRT round-trips through the VTT parser (comma clock accepted)', () {
      // Interop: files saved as SRT must also load through the VTT parser
      // path used by imports.
      const vttish = 'WEBVTT\n\n00:00:01,000 --> 00:00:02,000\nمختلط\n';
      final back = parseVtt(vttish);
      expect(back.cues.first.startMs, 1000);
    });
  });

  group('Arabic caption post-processing', () {
    test('tatweel is stripped (display-safe by default)', () {
      expect(arabicCaptionCleanup('مرحــــباً بـــك'), 'مرحباً بك');
    });

    test('alef folding is opt-in (display text keeps its alef shapes)', () {
      const text = 'أهلاً بإبراهيم آل سعيد';
      expect(arabicCaptionCleanup(text), 'أهلاً بإبراهيم آل سعيد');
      expect(arabicCaptionCleanup(text, options: const ArabicCaptionOptions(foldAlef: true)), 'اهلاً بابراهيم ال سعيد');
    });

    test('punctuation spacing is repaired (no space before, one after)', () {
      expect(arabicCaptionCleanup('مرحبا ، بالعالم .كيف الحال؟'), 'مرحبا، بالعالم. كيف الحال؟');
    });

    test('whitespace runs collapse', () {
      expect(arabicCaptionCleanup('a   b\t\tc'), 'a b c');
    });

    test('wrapCaptionLines never breaks inside a word and bounds every line', () {
      final lines = wrapCaptionLines(
        'هذه جملة عربية طويلة نسبياً ويجب أن تنقسم عند حدود الكلمات فقط بدون كسر أي كلمة داخلية',
        maxChars: 30,
      );
      expect(lines.length, greaterThanOrEqualTo(2));
      for (final line in lines) {
        expect(line.length, lessThanOrEqualTo(30), reason: 'every line fits the frame');
      }
      // Rejoining the lines reproduces the words in order.
      final words = lines.join(' ').split(' ');
      expect(words, [
        'هذه',
        'جملة',
        'عربية',
        'طويلة',
        'نسبياً',
        'ويجب',
        'أن',
        'تنقسم',
        'عند',
        'حدود',
        'الكلمات',
        'فقط',
        'بدون',
        'كسر',
        'أي',
        'كلمة',
        'داخلية',
      ]);
    });

    test('pathological single word is hard-bounded, never loops forever', () {
      final lines = wrapCaptionLines('ك' * 200, maxChars: 20);
      expect(lines.length, greaterThanOrEqualTo(2));
      for (final line in lines) {
        expect(line.length, lessThanOrEqualTo(20));
      }
      expect(lines.join().length, 200); // no speech lost
    });

    test('full pipeline: cleanup + wrap inside sanitised track', () {
      final raw = SubtitleTrack(
        language: 'ar',
        durationMs: 60000,
        cues: const [
          SubtitleCue(startMs: 0, endMs: 4000, text: 'مرحــــباً ، هذه تسمية طويلة يجب أن تنقسم على أسطر قصيرة بدون فقدان الكلام المهم للمشاهد إطلاقاً'),
        ],
      ).sanitised();
      final text = raw.cues.first.text;
      expect(text.contains('ــــ'), isFalse, reason: 'tatweel stripped by the AR pass');
      expect(text.contains(' ،'), isFalse, reason: 'punctuation spacing repaired');
      final lines = text.split('\n');
      expect(lines.length, lessThanOrEqualTo(16));
      for (final line in lines) {
        expect(line.length, lessThanOrEqualTo(42));
      }
    });
  });
}
