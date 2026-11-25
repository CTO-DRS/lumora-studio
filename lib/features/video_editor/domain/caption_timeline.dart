/// Maps a captioning result (times in the SOURCE file) onto the project
/// timeline as [VideoText] overlays, so the existing text export path burns
/// them in (W3-M6b). Pure Dart: no Flutter, fully unit-tested.
library;

import 'dart:math' as math;

import 'package:lumora/features/video_editor/domain/subtitles.dart';
import 'package:lumora/features/video_editor/domain/video_project.dart';

/// Caption overlay ids start with this, then the clip id, then `_<index>`.
const String kCaptionIdPrefix = 'cap_';

bool isCaptionText(VideoText t) => t.id.startsWith(kCaptionIdPrefix);

String _clipPrefix(String clipId) => '$kCaptionIdPrefix${clipId}_';

/// Cues shorter than this after trimming are dropped.
const int kMinCaptionMs = 100;

/// Converts [track] (source-file times of [clip]) into timeline overlays.
/// [clipStartMs] is where the clip begins on the timeline. Honours trim,
/// speed and reverse; cues outside the trimmed range are dropped and
/// partially inside ones are clamped.
List<VideoText> captionTexts(SubtitleTrack track, VideoClip clip, int clipStartMs) {
  final out = <VideoText>[];
  final prefix = _clipPrefix(clip.id);
  var n = 0;
  for (final cue in track.cues) {
    final a = math.max(cue.startMs, clip.inMs);
    final b = math.min(cue.endMs, clip.outMs);
    if (b - a < kMinCaptionMs) continue;
    final int s;
    final int e;
    if (clip.reversed) {
      s = clipStartMs + ((clip.outMs - b) / clip.speed).round();
      e = clipStartMs + ((clip.outMs - a) / clip.speed).round();
    } else {
      s = clipStartMs + ((a - clip.inMs) / clip.speed).round();
      e = clipStartMs + ((b - clip.inMs) / clip.speed).round();
    }
    if (e - s < 1) continue;
    out.add(
      VideoText(
        id: '$prefix${n++}',
        text: cue.text,
        startMs: s,
        endMs: e,
        y: 0.86,
        fontSize: 0.05,
        backgroundColor: 0xAA000000,
      ),
    );
  }
  return out;
}

/// [existing] with every caption of [clipId] replaced by [fresh]; other
/// texts and other clips' captions are untouched.
List<VideoText> replaceClipCaptions(List<VideoText> existing, String clipId, List<VideoText> fresh) {
  final prefix = _clipPrefix(clipId);
  return [
    for (final t in existing)
      if (!t.id.startsWith(prefix)) t,
    ...fresh,
  ];
}

/// All caption overlays, ordered by start time.
List<VideoText> captionsOf(List<VideoText> texts) =>
    texts.where(isCaptionText).toList()..sort((a, b) => a.startMs.compareTo(b.startMs));

/// Timeline-time subtitle track from the caption overlays, for SRT/VTT.
SubtitleTrack captionTrack(List<VideoText> texts, {String language = 'und', int durationMs = 0}) => SubtitleTrack(
  language: language,
  durationMs: durationMs,
  cues: [for (final t in captionsOf(texts)) SubtitleCue(startMs: t.startMs, endMs: t.endMs, text: t.text)],
);
