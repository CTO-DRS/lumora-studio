import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/video_editor/domain/subtitles.dart';

/// C3 fuzz gate for the subtitle importers, mirroring the RAW importer gate:
/// random garbage, every truncation point and single-character mutations of
/// valid SRT/VTT files must raise only the bounded SubtitleFormatException —
/// never a crash, and never hang.
void main() {
  const srt =
      '1\n00:00:00,500 --> 00:00:02,000\nHello world\n\n'
      '2\n00:00:02,500 --> 00:00:04,000\nنص عربي ثانٍ\n';
  const vtt =
      'WEBVTT\n\n'
      'intro\n00:00:00.500 --> 00:00:02.000\nHello world\n\n'
      '00:00:02.500 --> 00:00:04.000\nSecond caption\n';

  const corpus = 400;

  void expectBoundedSrt(void Function() body, String label) {
    try {
      body();
    } on SubtitleFormatException {
      // expected
    } catch (e) {
      fail('SRT $label threw an unbounded error: $e');
    }
  }

  void expectBoundedVtt(void Function() body, String label) {
    try {
      body();
    } on SubtitleFormatException {
      // expected
    } catch (e) {
      fail('VTT $label threw an unbounded error: $e');
    }
  }

  group('SRT fuzz sweep', () {
    test('random garbage stays bounded', () {
      final rnd = Random(20261128);
      const alphabet = '0123456789:,.-> \n\tabcWEBVTنص';
      for (var i = 0; i < corpus; i++) {
        final len = rnd.nextInt(120);
        final s = String.fromCharCodes(List.generate(len, (_) => alphabet.codeUnitAt(rnd.nextInt(alphabet.length))));
        expectBoundedSrt(() => parseSrt(s), 'random#$i');
      }
    });

    test('every truncation point of a valid file stays bounded', () {
      expect(parseSrt(srt).length, 2);
      for (var cut = 0; cut <= srt.length; cut++) {
        expectBoundedSrt(() => parseSrt(srt.substring(0, cut)), 'cut#$cut');
      }
    });

    test('single-character mutations stay bounded', () {
      final rnd = Random(9);
      const swaps = '09:,.-X>\n ';
      for (var i = 0; i < corpus; i++) {
        final chars = srt.split('');
        chars[rnd.nextInt(chars.length)] = swaps[rnd.nextInt(swaps.length)];
        final mutated = chars.join();
        expectBoundedSrt(() => parseSrt(mutated), 'mut#$i');
      }
    });
  });

  group('VTT fuzz sweep', () {
    test('random garbage stays bounded', () {
      final rnd = Random(20261129);
      const alphabet = '0123456789:,.-> \n\tabcWEBVTنص';
      for (var i = 0; i < corpus; i++) {
        final len = rnd.nextInt(120);
        final s = String.fromCharCodes(List.generate(len, (_) => alphabet.codeUnitAt(rnd.nextInt(alphabet.length))));
        expectBoundedVtt(() => parseVtt(s), 'random#$i');
      }
    });

    test('every truncation point of a valid file stays bounded', () {
      expect(parseVtt(vtt).length, 2);
      for (var cut = 0; cut <= vtt.length; cut++) {
        expectBoundedVtt(() => parseVtt(vtt.substring(0, cut)), 'cut#$cut');
      }
    });

    test('single-character mutations stay bounded', () {
      final rnd = Random(13);
      const swaps = '09:,.-X>\n ';
      for (var i = 0; i < corpus; i++) {
        final chars = vtt.split('');
        chars[rnd.nextInt(chars.length)] = swaps[rnd.nextInt(swaps.length)];
        final mutated = chars.join();
        expectBoundedVtt(() => parseVtt(mutated), 'mut#$i');
      }
    });
  });
}
