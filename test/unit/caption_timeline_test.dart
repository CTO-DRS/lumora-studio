import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/video_editor/domain/caption_timeline.dart';
import 'package:lumora/features/video_editor/domain/subtitles.dart';
import 'package:lumora/features/video_editor/domain/video_project.dart';

VideoClip _clip({int inMs = 0, int outMs = 10000, double speed = 1, bool reversed = false}) => VideoClip(
  id: 'c1',
  path: '/v.mp4',
  sourceDurationMs: 10000,
  outMs: outMs,
  inMs: inMs,
  speed: speed,
  reversed: reversed,
);

SubtitleTrack _track(List<(int, int, String)> cues) => SubtitleTrack(
  language: 'en',
  cues: [for (final c in cues) SubtitleCue(startMs: c.$1, endMs: c.$2, text: c.$3)],
);

void main() {
  test('maps source times onto the timeline with the clip offset', () {
    final out = captionTexts(_track([(1000, 2000, 'hi')]), _clip(), 5000);
    expect(out.single.startMs, 6000);
    expect(out.single.endMs, 7000);
    expect(out.single.id, 'cap_c1_0');
    expect(isCaptionText(out.single), isTrue);
  });

  test('trim drops and clamps cues; speed scales times', () {
    final out = captionTexts(
      _track([(0, 500, 'gone'), (1500, 3000, 'clamped'), (4000, 5000, 'in')]),
      _clip(inMs: 2000, outMs: 8000, speed: 2),
      0,
    );
    expect(out.map((t) => t.text), ['clamped', 'in']);
    expect(out[0].startMs, 0);
    expect(out[0].endMs, 500);
    expect(out[1].startMs, 1000);
    expect(out[1].endMs, 1500);
  });

  test('reversed clips mirror the cue times', () {
    final out = captionTexts(_track([(1000, 2000, 'x')]), _clip(reversed: true), 0);
    expect(out.single.startMs, 8000);
    expect(out.single.endMs, 9000);
  });

  test('replace only touches this clip captions', () {
    const other = VideoText(id: 'cap_c2_0', text: 'o');
    const plain = VideoText(id: 'abc', text: 'p');
    const old = VideoText(id: 'cap_c1_0', text: 'old');
    final fresh = captionTexts(_track([(0, 1000, 'new')]), _clip(), 0);
    final merged = replaceClipCaptions([other, plain, old], 'c1', fresh);
    expect(merged.map((t) => t.text), ['o', 'p', 'new']);
  });

  group('caption editor ops (A4)', () {
    const a = VideoText(id: 'cap_c1_0', text: 'one two', startMs: 1000, endMs: 2000);
    const b = VideoText(id: 'cap_c1_1', text: 'three four', startMs: 2500, endMs: 3500);
    const other = VideoText(id: 'cap_c2_0', text: 'other clip', startMs: 3000, endMs: 4000);
    const free = VideoText(id: 'free', text: 'keep', startMs: 500, endMs: 900);

    test('shift moves both ends, keeps duration, never before 0', () {
      final later = shiftCaptionBy([a], 'cap_c1_0', 250);
      expect(later.single.startMs, 1250);
      expect(later.single.endMs, 2250);
      final earlier = shiftCaptionBy([a], 'cap_c1_0', -5000);
      expect(earlier.single.startMs, 0);
      expect(earlier.single.endMs, 1000, reason: 'duration kept');
      // Free texts and unknown ids are untouched.
      expect(shiftCaptionBy([free], 'free', 250).single.startMs, 500);
      expect(shiftCaptionBy([a], 'nope', 250), [a]);
    });

    test('merge joins the next same-clip caption only', () {
      final out = mergeCaptionWithNext([a, b, other, free], 'cap_c1_0');
      final merged = out.firstWhere((t) => t.id == 'cap_c1_0');
      expect(merged.text, 'one two three four');
      expect(merged.startMs, 1000);
      expect(merged.endMs, 3500);
      expect(out.any((t) => t.id == 'cap_c1_1'), isFalse, reason: 'second cue consumed');
      expect(out.any((t) => t.id == 'cap_c2_0'), isTrue, reason: 'other clip untouched');
      expect(out.any((t) => t.id == 'free'), isTrue);
    });

    test('merge does not cross clips and no-ops on the last caption', () {
      final out = mergeCaptionWithNext([a, other], 'cap_c1_0');
      expect(out, [a, other], reason: 'next caption belongs to another clip');
      expect(mergeCaptionWithNext([a, b], 'cap_c1_1'), [a, b]);
      expect(mergeCaptionWithNext([free], 'free'), [free]);
    });

    test('split breaks at the word boundary nearest the middle', () {
      final out = splitCaptionAt([a, free], 'cap_c1_0', 1500);
      expect(out.length, 3);
      final first = out.firstWhere((t) => t.id == 'cap_c1_0');
      final second = out.firstWhere((t) => t.id == 'cap_c1_0b');
      expect(first.text, 'one');
      expect(first.endMs, 1500);
      expect(second.text, 'two');
      expect(second.startMs, 1500);
      expect(second.endMs, 2000);
      expect(out.any((t) => t.id == 'free'), isTrue);
    });

    test('split no-ops near edges, outside the cue, or without a boundary', () {
      expect(splitCaptionAt([a], 'cap_c1_0', 1050), [a], reason: 'side under 100 ms');
      expect(splitCaptionAt([a], 'cap_c1_0', 5000), [a], reason: 'outside the cue');
      const single = VideoText(id: 'cap_c1_9', text: 'oneword', startMs: 1000, endMs: 2000);
      expect(splitCaptionAt([single], 'cap_c1_9', 1500), [single], reason: 'no whitespace');
    });

    test('split ids stay unique and keep the clip prefix intact', () {
      var out = splitCaptionAt([a], 'cap_c1_0', 1500);
      out = splitCaptionAt(out, 'cap_c1_0', 1250);
      final ids = out.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'no duplicate ids');
      for (final t in out) {
        expect(captionClipPrefix(t.id), 'cap_c1_', reason: '${t.id} keeps its clip prefix');
      }
    });

    test('style applies to captions only and can clear the background', () {
      final styled = styleCaptionTexts([a, free], fontSize: 0.06);
      expect(styled.firstWhere((t) => t.id == 'cap_c1_0').fontSize, 0.06);
      expect(styled.firstWhere((t) => t.id == 'free').fontSize, free.fontSize);
      final cleared = styleCaptionTexts([a], clearBackground: true);
      expect(cleared.single.backgroundColor, isNull);
      final bg = styleCaptionTexts([a], backgroundColor: 0xFF112233);
      expect(bg.single.backgroundColor, 0xFF112233);
    });
  });

  test('captionTrack lists only captions in time order', () {
    final texts = [
      const VideoText(id: 'cap_c1_1', text: 'b', startMs: 3000, endMs: 4000),
      const VideoText(id: 'free', text: 'x'),
      const VideoText(id: 'cap_c1_0', text: 'a', startMs: 1000, endMs: 2000),
    ];
    final t = captionTrack(texts);
    expect(t.cues.map((c) => c.text), ['a', 'b']);
  });
}
