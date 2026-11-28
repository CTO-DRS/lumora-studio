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

/// The clip-captions prefix of a caption id (`cap_<clipId>_`). Caption ids
/// never gain extra underscores after the index (split ids append letters
/// to the index instead), so the last underscore always ends the prefix.
String captionClipPrefix(String id) => id.substring(0, id.lastIndexOf('_') + 1);

/// Retimes caption [id] by [deltaMs]: both ends move, the duration stays.
/// The cue never starts before 0. Not a caption → unchanged list.
List<VideoText> shiftCaptionBy(List<VideoText> texts, String id, int deltaMs) => [
  for (final t in texts)
    if (t.id == id && isCaptionText(t))
      () {
        final start = math.max(0, t.startMs + deltaMs);
        return t.copyWith(startMs: start, endMs: start + (t.endMs - t.startMs));
      }()
    else
      t,
];

/// Merges caption [id] with the next caption of the SAME clip (timeline
/// order): the merged cue spans both, the texts join with a single space.
/// Unchanged when [id] is not a caption or has no same-clip successor.
List<VideoText> mergeCaptionWithNext(List<VideoText> texts, String id) {
  final caps = captionsOf(texts);
  final i = caps.indexWhere((t) => t.id == id);
  if (i < 0) return texts;
  final first = caps[i];
  final prefix = captionClipPrefix(id);
  VideoText? next;
  for (var j = i + 1; j < caps.length; j++) {
    if (caps[j].id.startsWith(prefix)) {
      next = caps[j];
      break;
    }
  }
  if (next == null) return texts;
  final merged = first.copyWith(
    text: '${first.text} ${next.text}'.trim(),
    startMs: math.min(first.startMs, next.startMs),
    endMs: math.max(first.endMs, next.endMs),
  );
  return [
    for (final t in texts)
      if (t.id == id) merged else if (t.id != next.id) t,
  ];
}

/// Splits caption [id] at [atMs] (timeline ms). The text breaks at the
/// whitespace nearest the split fraction so neither side starts mid-word.
/// No-op when [atMs] falls outside the cue, when either side would be
/// shorter than kMinCaptionMs, or when the text has no whitespace away
/// from its edges. The second half takes a fresh id (`${id}b`, `${id}c`…).
List<VideoText> splitCaptionAt(List<VideoText> texts, String id, int atMs) {
  final t = texts.where((x) => x.id == id && isCaptionText(x)).firstOrNull;
  if (t == null) return texts;
  if (atMs - t.startMs < kMinCaptionMs || t.endMs - atMs < kMinCaptionMs) return texts;
  final fraction = (atMs - t.startMs) / (t.endMs - t.startMs);
  final target = (t.text.length * fraction).round();
  var bestAt = -1;
  for (var i = 0; i < t.text.length; i++) {
    if (t.text.codeUnitAt(i) == 0x20 || t.text.codeUnitAt(i) == 0x0A) {
      if (i > 0 && i < t.text.length - 1 && (bestAt < 0 || (i - target).abs() < (bestAt - target).abs())) {
        bestAt = i;
      }
    }
  }
  if (bestAt < 0) return texts;
  final a = t.text.substring(0, bestAt).trim();
  final b = t.text.substring(bestAt + 1).trim();
  if (a.isEmpty || b.isEmpty) return texts;
  var suffix = 'b'.codeUnitAt(0);
  var newId = '$id${String.fromCharCode(suffix)}';
  while (texts.any((x) => x.id == newId)) {
    suffix++;
    newId = '$id${String.fromCharCode(suffix)}';
  }
  return [
    for (final x in texts)
      if (x.id == id) ...[x.copyWith(text: a, endMs: atMs), x.copyWith(id: newId, text: b, startMs: atMs)] else x,
  ];
}

/// Applies a style to every caption overlay; free texts stay untouched.
/// [clearBackground] wins over [backgroundColor].
List<VideoText> styleCaptionTexts(
  List<VideoText> texts, {
  double? fontSize,
  int? backgroundColor,
  bool clearBackground = false,
}) => [
  for (final t in texts)
    if (isCaptionText(t))
      t.copyWith(
        fontSize: fontSize ?? t.fontSize,
        backgroundColor: clearBackground ? null : (backgroundColor ?? t.backgroundColor),
      )
    else
      t,
];
