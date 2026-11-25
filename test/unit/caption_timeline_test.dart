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
