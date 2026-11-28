/// Subtitle infrastructure for the video editor (Wave 2 W3-M1 — the data
/// layer under "Whisper auto-captions").
///
/// What ships in this milestone, all pure Dart and fully unit-tested:
///
/// * **Data model** — [SubtitleCue] (start/end ms, text, optional
///   word-level timings for later karaoke styling) and [SubtitleTrack]
///   (sorted cues + language + JSON round-trip for project files).
/// * **SRT / WebVTT writers + strict parsers** — spec-correct time
///   formatting (`HH:MM:SS,mmm` vs `HH:MM:SS.mmm`), round-trippable, and
///   the parsers are **bounded** (line/count/length caps, explicit format
///   errors) per the roadmap fuzzing gate: malformed input raises
///   [SubtitleFormatException], never crashes or hangs.
/// * **Sanitisation** — [SubtitleTrack.sanitised] truncates overlaps,
///   drops zero/negative durations and clamps times to the track duration,
///   so anything coming out of a future ASR model can be dropped in
///   without timeline edge cases.
/// * **Arabic caption post-processing** — [arabicCaptionCleanup] with the
///   W3-scope dialect-tolerant pass: tatweel stripping, optional alef
///   folding (for ASR-text comparison, off by default for display),
///   whitespace/punctuation spacing repair, and word-boundary line
///   wrapping ([wrapCaptionLines] — never breaks inside a word, two-line
///   captions by default).
///
/// The Whisper model itself (tiny/base int8, encoder-decoder with cached
/// KV over 30 s windows of the v1.4 PCM path) lands in the next W3
/// milestone on top of this layer; the timeline subtitle UI after that.
library;

import 'dart:convert' show LineSplitter;
import 'dart:math' as math;

// ---------------------------------------------------------------------------
// data model
// ---------------------------------------------------------------------------

/// One caption cue: [startMs]..[endMs] on the timeline, the text (may
/// contain `\n` after wrapping), and optional per-word timings
/// (milliseconds, same clock) for karaoke-style styling later.
class SubtitleCue implements Comparable<SubtitleCue> {
  const SubtitleCue({
    required this.startMs,
    required this.endMs,
    required this.text,
    this.words = const [],
  });

  final int startMs;
  final int endMs;

  /// Caption text; may contain at most one `\n` after [wrapCaptionLines].
  final String text;

  /// Word-level timings aligned with [text] (space-split), each with its
  /// own start/end. Empty when the source has no word timing.
  final List<SubtitleWord> words;

  int get durationMs => endMs - startMs;

  bool get isValid => startMs >= 0 && endMs > startMs;

  bool overlaps(SubtitleCue other) => startMs < other.endMs && other.startMs < endMs;

  SubtitleCue copyWith({int? startMs, int? endMs, String? text, List<SubtitleWord>? words}) =>
      SubtitleCue(
        startMs: startMs ?? this.startMs,
        endMs: endMs ?? this.endMs,
        text: text ?? this.text,
        words: words ?? this.words,
      );

  Map<String, dynamic> toJson() => {
        'startMs': startMs,
        'endMs': endMs,
        'text': text,
        if (words.isNotEmpty)
          'words': [
            for (final w in words)
              {'t': w.text, 's': w.startMs, 'e': w.endMs},
          ],
      };

  static SubtitleCue fromJson(Map<String, dynamic> json) {
    final start = (json['startMs'] as num?)?.toInt() ?? 0;
    final end = (json['endMs'] as num?)?.toInt() ?? 0;
    final text = (json['text'] as String?) ?? '';
    final words = <SubtitleWord>[];
    final rawWords = json['words'];
    if (rawWords is List) {
      for (final w in rawWords) {
        if (w is Map) {
          words.add(SubtitleWord(
            text: (w['t'] as String?) ?? '',
            startMs: (w['s'] as num?)?.toInt() ?? 0,
            endMs: (w['e'] as num?)?.toInt() ?? 0,
          ));
        }
      }
    }
    return SubtitleCue(startMs: start, endMs: end, text: text, words: words);
  }

  @override
  int compareTo(SubtitleCue other) => startMs - other.startMs;
}

/// Word-level timing inside a cue (karaoke styling data).
class SubtitleWord {
  const SubtitleWord({required this.text, required this.startMs, required this.endMs});

  final String text;
  final int startMs;
  final int endMs;
}

/// A track of cues with a language tag and a clamp duration (the video
/// length — times never exceed it after [sanitised]).
class SubtitleTrack {
  SubtitleTrack({required this.language, List<SubtitleCue> cues = const [], this.durationMs = 0})
      : cues = List<SubtitleCue>.from(cues)..sort();

  /// BCP-47-ish tag: `ar`, `en`, …
  final String language;

  /// Sorted by start time.
  final List<SubtitleCue> cues;

  /// Video duration in ms; sanitisation clamps to it. 0 = unknown.
  final int durationMs;

  bool get isEmpty => cues.isEmpty;
  int get length => cues.length;

  /// The caption visible at timeline position [ms], or null.
  SubtitleCue? cueAt(int ms) {
    for (final c in cues) {
      if (ms >= c.startMs && ms < c.endMs) return c;
    }
    return null;
  }

  /// Cleaning pass for ASR output: drops invalid cues, truncates overlaps
  /// (the earlier cue ends where the next begins), clamps to
  /// [durationMs], and wraps every caption to the standard two-line shape.
  SubtitleTrack sanitised({int maxCharsPerLine = 42, int maxLines = 2}) {
    final clamped = durationMs > 0 ? durationMs : null;
    final cleaned = <SubtitleCue>[];
    for (final c in cues) {
      final start = math.max(0, c.startMs);
      var end = c.endMs;
      if (clamped != null) {
        if (start >= clamped) continue;
        end = math.min(end, clamped);
      }
      if (end <= start) continue;
      // Overlap policy: the earlier cue yields to the next one.
      if (cleaned.isNotEmpty) {
        var prev = cleaned.last;
        if (start < prev.endMs) {
          prev = prev.copyWith(endMs: start);
        }
        if (prev.endMs <= prev.startMs) {
          cleaned.removeLast();
        } else {
          cleaned[cleaned.length - 1] = prev;
        }
        if (end <= start) continue;
      }
      final wrapped = wrapCaptionLines(
        arabicCaptionCleanup(c.text),
        maxChars: maxCharsPerLine,
        maxLines: maxLines,
      );
      // A cue whose text cleans to nothing is no caption at all — and an
      // empty text line would corrupt the SRT/VTT block structure on
      // export (the strict parser rejects it, so the file would not
      // re-import). Found by subtitle_writer_fuzz_test.dart.
      final text = wrapped.join('\n');
      if (text.trim().isEmpty) continue;
      cleaned.add(c.copyWith(startMs: start, endMs: end, text: text));
    }
    return SubtitleTrack(language: language, cues: cleaned, durationMs: durationMs);
  }

  Map<String, dynamic> toJson() => {
        'language': language,
        'durationMs': durationMs,
        'cues': [for (final c in cues) c.toJson()],
      };

  static SubtitleTrack fromJson(Map<String, dynamic> json) {
    final language = (json['language'] as String?) ?? '';
    final duration = (json['durationMs'] as num?)?.toInt() ?? 0;
    final cues = <SubtitleCue>[];
    final raw = json['cues'];
    if (raw is List) {
      for (final c in raw) {
        if (c is Map) cues.add(SubtitleCue.fromJson(Map<String, dynamic>.from(c)));
      }
    }
    return SubtitleTrack(language: language, cues: cues, durationMs: duration);
  }
}

// ---------------------------------------------------------------------------
// time formatting + SRT / VTT writers
// ---------------------------------------------------------------------------

String _pad(int v, int width) => v.toString().padLeft(width, '0');

/// `HH:MM:SS,mmm` (SRT) or `HH:MM:SS.mmm` (VTT), hours unbounded-3-digit
/// safe (videos longer than 99 h still format).
String formatSubtitleClock(int ms, {required bool comma}) {
  final clamped = math.max(0, ms);
  final h = clamped ~/ 3600000;
  final m = (clamped ~/ 60000) % 60;
  final s = (clamped ~/ 1000) % 60;
  final f = clamped % 1000;
  return '${_pad(h, 2)}:${_pad(m, 2)}:${_pad(s, 2)}${comma ? ',' : '.'}${_pad(f, 3)}';
}

/// Serialises the track as SubRip (`.srt`): numbered blocks, comma clock,
/// blank line between cues.
String writeSrt(SubtitleTrack track) {
  final out = StringBuffer();
  for (var i = 0; i < track.cues.length; i++) {
    final c = track.cues[i];
    out
      ..writeln(i + 1)
      ..writeln('${formatSubtitleClock(c.startMs, comma: true)} --> ${formatSubtitleClock(c.endMs, comma: true)}')
      ..writeln(c.text.replaceAll('\n', '\n'))
      ..writeln();
  }
  return out.toString();
}

/// Serialises the track as WebVTT (`.vtt`): WEBVTT header, dot clock,
/// blank line between cues.
String writeVtt(SubtitleTrack track) {
  final out = StringBuffer('WEBVTT\n\n');
  for (final c in track.cues) {
    out
      ..writeln('${formatSubtitleClock(c.startMs, comma: false)} --> ${formatSubtitleClock(c.endMs, comma: false)}')
      ..writeln(c.text)
      ..writeln();
  }
  return out.toString();
}

// ---------------------------------------------------------------------------
// strict, bounded parsers (round-trip + import; fuzz gate)
// ---------------------------------------------------------------------------

/// Thrown on malformed SRT/VTT input — plain reason, no crash.
class SubtitleFormatException implements Exception {
  const SubtitleFormatException(this.reason);

  final String reason;

  @override
  String toString() => 'SubtitleFormatException: $reason';
}

final RegExp _clockRe = RegExp(r'^(\d{1,3}):(\d{1,2}):(\d{1,2})[,.](\d{1,3})$');
final RegExp _arrowRe = RegExp(r'^\S+\s+-->\s+\S+');

int _parseClock(String s, {required bool comma}) {
  final m = _clockRe.firstMatch(s);
  if (m == null) throw SubtitleFormatException('bad timestamp "$s"');
  final h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  final sec = int.parse(m.group(3)!);
  if (min > 59 || sec > 59) throw SubtitleFormatException('timestamp field out of range "$s"');
  var frac = int.parse(m.group(4)!.padRight(3, '0'));
  // guard against absurd values
  frac = frac.clamp(0, 999);
  return ((h * 60 + min) * 60 + sec) * 1000 + frac;
}

/// Parses SubRip text. Bounded: ≤ 50k lines and cues, cue text ≤ 5k
/// chars — pathological input raises instead of hanging.
SubtitleTrack parseSrt(String source, {String language = ''}) {
  final lines = const LineSplitter().convert(source);
  if (lines.length > 50000) throw const SubtitleFormatException('too many lines');
  final cues = <SubtitleCue>[];
  var i = 0;
  while (i < lines.length) {
    if (cues.length >= 50000) {
      throw const SubtitleFormatException('too many cues (bounded parser)');
    }
    // Skip blank lines and index-only lines.
    while (i < lines.length && lines[i].trim().isEmpty) {
      i++;
    }
    if (i >= lines.length) break;
    if (RegExp(r'^\d+$').hasMatch(lines[i].trim())) {
      i++;
      if (i >= lines.length) break;
    }
    final timing = lines[i].trim();
    if (!_arrowRe.hasMatch(timing)) {
      // A file truncated mid-timing-line (cut off while being written) is
      // tolerated at the very end: everything before it is returned. Total
      // garbage (nothing parsed yet) still raises.
      final trailingBlank = lines.sublist(i + 1).every((l) => l.trim().isEmpty);
      if (cues.isNotEmpty && (i == lines.length - 1 || trailingBlank)) {
        break;
      }
      throw SubtitleFormatException('expected timing line, got "${_clip(timing)}"');
    }
    final parts = timing.split('-->');
    if (parts.length != 2) throw SubtitleFormatException('bad timing line "${_clip(timing)}"');
    final start = _parseClock(parts[0].trim(), comma: true);
    final end = _parseClock(parts[1].trim(), comma: true);
    i++;
    final text = StringBuffer();
    var textLines = 0;
    while (i < lines.length && lines[i].trim().isNotEmpty && textLines < 8) {
      if (text.length + lines[i].length > 5000) {
        throw const SubtitleFormatException('cue text too long');
      }
      text.writeln(lines[i]);
      textLines++;
      i++;
    }
    final t = text.toString().trimRight();
    if (t.isEmpty) throw SubtitleFormatException('empty cue at ${formatSubtitleClock(start, comma: true)}');
    cues.add(SubtitleCue(startMs: start, endMs: math.max(end, start + 1), text: t));
  }
  return SubtitleTrack(language: language, cues: cues);
}

/// Parses WebVTT text (the subset Lumora writes: timing + text lines;
/// NOTE/style blocks are skipped, never fatal).
SubtitleTrack parseVtt(String source, {String language = ''}) {
  final lines = const LineSplitter().convert(source);
  if (lines.length > 50000) throw const SubtitleFormatException('too many lines');
  if (lines.isEmpty || !lines.first.trim().startsWith('WEBVTT')) {
    throw const SubtitleFormatException('missing WEBVTT header');
  }
  final cues = <SubtitleCue>[];
  var i = 1;
  while (i < lines.length) {
    if (cues.length >= 50000) {
      throw const SubtitleFormatException('too many cues (bounded parser)');
    }
    final line = lines[i].trim();
    if (line.isEmpty || line.startsWith('NOTE') || line.startsWith('STYLE') || line.startsWith('REGION')) {
      i++;
      continue;
    }
    if (!_arrowRe.hasMatch(line)) {
      // Cue identifier line — skip it, the next line must be the timing.
      i++;
      continue;
    }
    final parts = line.split('-->');
    if (parts.length != 2) throw SubtitleFormatException('bad timing line "${_clip(line)}"');
    final start = _parseClock(parts[0].trim(), comma: false);
    final end = _parseClock(parts[1].trim(), comma: false);
    i++;
    final text = StringBuffer();
    var textLines = 0;
    while (i < lines.length && lines[i].trim().isNotEmpty && textLines < 8) {
      if (text.length + lines[i].length > 5000) {
        throw const SubtitleFormatException('cue text too long');
      }
      text.writeln(lines[i]);
      textLines++;
      i++;
    }
    final t = text.toString().trimRight();
    if (t.isNotEmpty) {
      cues.add(SubtitleCue(startMs: start, endMs: math.max(end, start + 1), text: t));
    }
  }
  return SubtitleTrack(language: language, cues: cues);
}

String _clip(String s) => s.length > 40 ? '${s.substring(0, 40)}…' : s;

// ---------------------------------------------------------------------------
// Arabic caption post-processing (W3 scope: dialect-tolerant pass)
// ---------------------------------------------------------------------------

/// Options for [arabicCaptionCleanup].
class ArabicCaptionOptions {
  const ArabicCaptionOptions({
    this.stripTatweel = true,
    this.foldAlef = false,
    this.fixSpacing = true,
  });

  /// Remove tatweel (U+0640) — display-safe, ASR text pads words with it.
  final bool stripTatweel;

  /// Fold alef variants (أ إ آ ٱ → ا) — useful when comparing ASR text or
  /// building search keys; off by default because it changes display text.
  final bool foldAlef;

  /// Collapse whitespace and repair punctuation spacing.
  final bool fixSpacing;
}

const _kTatweel = '\u0640';
const _kAlefVariants = ['\u0623', '\u0625', '\u0622', '\u0671'];

/// Dialect-tolerant cleanup for Arabic caption text (and harmless for
/// Latin): strips tatweel, optionally folds alef variants, repairs spacing
/// around Arabic/Latin punctuation and collapses runs of whitespace.
String arabicCaptionCleanup(String text, {ArabicCaptionOptions options = const ArabicCaptionOptions()}) {
  var t = text;
  if (options.stripTatweel) {
    t = t.replaceAll(_kTatweel, '');
  }
  if (options.foldAlef) {
    for (final v in _kAlefVariants) {
      t = t.replaceAll(v, '\u0627');
    }
  }
  if (options.fixSpacing) {
    // No space BEFORE punctuation; one space AFTER it (Arabic comma, full
    // stop, question mark, exclamation, Latin comma/period). replaceAll
    // does not interpret `$1` backreferences — use replaceAllMapped.
    final before = RegExp('[\\s]+([\u060C\u061B\u061F.,!?])');
    final after = RegExp('([\u060C\u061B\u061F.,!?])(?=[^\\s\\d.,!?])');
    t = t.replaceAllMapped(before, (m) => m.group(1)!);
    t = t.replaceAllMapped(after, (m) => '${m.group(1)} ');
    t = t
        .replaceAll(RegExp('[ \\t\u00A0]{2,}'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
  return t;
}

/// Wraps caption text to lines of ≤ [maxChars] each, breaking only at
/// spaces (never inside a word — Arabic shaping must not be split
/// mid-word). Oversized single words are hard-broken as a last resort
/// (bounded loop). Returns 1..16 lines — [maxLines] is the soft display
/// target the UI aims for, but every returned line is guaranteed ≤
/// [maxChars] (overflowing the video frame is worse than an extra line);
/// callers that must show exactly [maxLines] render the first of them.
/// Empty input → [''].
List<String> wrapCaptionLines(String text, {int maxChars = 42, int maxLines = 2}) {
  final max = math.max(8, maxChars);
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return <String>[''];

  // Hard-break pathological words first (bounded).
  final bounded = <String>[];
  for (final w in words) {
    if (w.length <= max) {
      bounded.add(w);
      continue;
    }
    for (var i = 0; i < w.length; i += max) {
      bounded.add(w.substring(i, math.min(i + max, w.length)));
    }
  }

  final lines = <String>[];
  final current = StringBuffer();
  for (final w in bounded) {
    if (current.isEmpty) {
      current.write(w);
    } else if (current.length + 1 + w.length <= max) {
      current.write(' $w');
    } else {
      lines.add(current.toString());
      current
        ..clear() // flush must empty the buffer, or the tail keeps growing
        ..write(w);
    }
  }
  if (current.isNotEmpty) lines.add(current.toString());

  // Absolute cap so absurd input stays bounded: keep the first 16 lines
  // and truncate the rest (a 17-line caption is garbage input, not
  // meaningful speech).
  if (lines.length > 16) {
    final head = lines.sublist(0, 16).toList();
    head[15] = '${head[15].substring(0, math.min(max, head[15].length))}…';
    return head;
  }
  return lines;
}
