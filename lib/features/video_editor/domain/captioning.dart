/// Captioning job pipeline (Wave 2 W3-M2): turns a decoded PCM audio track
/// into a sanitised [SubtitleTrack] through a pluggable on-device
/// transcriber — the seam where the Whisper tiny/base int8 model lands in
/// the next W3 milestone.
///
/// Design, straight from the W3 roadmap row:
///
/// * **30 s windows** ([CaptionWindows.split]) slide over the audio the
///   v1.4 FFmpeg PCM path already decodes (mono s16le at 22.05 kHz for
///   analysis; any sample rate works — times are computed from
///   `sampleRate`).
/// * **Never blocks editing** — [CaptionJob] runs sequentially on its own
///   isolate-facing queue, reports progress per window, and is
///   **cancellable** mid-window: the next cancellation check aborts the
///   job and the partial result is still returned (nothing is lost).
/// * **The transcriber is an interface** ([AutoTranscriber]) — tests use a
///   deterministic fake; the real Whisper transcriber implements the same
///   contract, so no call site changes when the model arrives.
/// * Segments come back with their absolute window-relative times, are
///   cleaned through [SubtitleTrack.sanitised] (the W3-M1 layer), so the
///   output is timeline-safe by construction.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumora/features/video_editor/domain/subtitles.dart';

// ---------------------------------------------------------------------------
// windowing
// ---------------------------------------------------------------------------

/// One 30-second analysis window over the decoded PCM.
class CaptionWindow {
  const CaptionWindow({
    required this.index,
    required this.startMs,
    required this.samples,
    required this.sampleRate,
  });

  /// 0-based window index.
  final int index;

  /// Absolute start on the timeline.
  final int startMs;

  /// PCM samples (mono, native endianness Int16 after [decode]).
  final Int16List samples;

  final int sampleRate;

  int get durationMs => sampleRate <= 0 ? 0 : (samples.length * 1000) ~/ sampleRate;

  int get endMs => startMs + durationMs;
}

/// Splits decoded audio into fixed windows (30 s by default; Whisper's
/// native context). The last window carries the remainder, whatever its
/// length (a ≥ 1 s remainder is kept; a shorter tail is folded into the
/// previous window to avoid a caption window shorter than one word).
List<CaptionWindow> splitIntoWindows(
  Int16List samples,
  int sampleRate, {
  int windowMs = 30000,
  int minTailMs = 1000,
}) {
  if (sampleRate <= 0) return const [];
  final windowLen = (sampleRate * windowMs) ~/ 1000;
  if (windowLen <= 0 || samples.isEmpty) return const [];
  final minTail = math.max(1, (sampleRate * minTailMs) ~/ 1000);

  final windows = <CaptionWindow>[];
  var start = 0;
  var index = 0;
  while (start < samples.length) {
    var end = start + windowLen;
    // Fold a too-short tail into this window instead of a sliver window.
    final remaining = samples.length - end;
    if (remaining > 0 && remaining < minTail) {
      end = samples.length;
    }
    windows.add(CaptionWindow(
      index: index,
      startMs: (start * 1000) ~/ sampleRate,
      samples: Int16List.sublistView(samples, start, math.min(end, samples.length)),
      sampleRate: sampleRate,
    ));
    start = end;
    index++;
  }
  return windows;
}

/// One transcription result with absolute timeline times.
class CaptionSegment {
  const CaptionSegment({required this.startMs, required this.endMs, required this.text, this.language});

  final int startMs;
  final int endMs;
  final String text;

  /// Language detected for this segment ( Whisper emits per-window); null
  /// when the transcriber does not detect language.
  final String? language;
}

/// The pluggable ASR seam. The real Whisper transcriber (tiny/base int8,
/// encoder-decoder with cached KV) implements this in the next W3
/// milestone; tests inject a deterministic fake. Implementations must be
/// safe to call from a background job and must translate their own
/// failures into an empty segment list (or throw — the job records it).
abstract interface class AutoTranscriber {
  /// Transcribes one window; returns segments with times **relative to the
  /// window start** (the job shifts them to absolute timeline times).
  Future<List<CaptionSegment>> transcribe(CaptionWindow window);

  /// Display name for diagnostics.
  String get name;
}

// ---------------------------------------------------------------------------
// the job
// ---------------------------------------------------------------------------

/// Progress snapshot for the UI.
class CaptionProgress {
  const CaptionProgress({required this.windowsDone, required this.windowsTotal, required this.msProcessed});

  final int windowsDone;
  final int windowsTotal;

  /// Audio milliseconds transcribed so far (absolute timeline time).
  final int msProcessed;

  double get fraction => windowsTotal == 0 ? 1.0 : windowsDone / windowsTotal;
}

/// Outcome of [CaptionJob.run].
class CaptionJobResult {
  const CaptionJobResult({
    required this.track,
    required this.cancelled,
    required this.elapsedMs,
    this.error,
  });

  /// Sanitised, timeline-safe captions (possibly partial when cancelled).
  final SubtitleTrack track;

  /// True when the job stopped early because cancellation was requested.
  final bool cancelled;

  final int elapsedMs;

  /// Set when a transcriber threw; the job still returns whatever
  /// completed before the failure (honest partial results).
  final Object? error;

  bool get succeeded => error == null && !cancelled;
}

/// Background captioning job: windows → transcriber → absolute-time
/// segments → sanitised track. Sequential by design (one model at a time,
/// the v1.5 memory budget), cancellable between and inside windows via
/// [isCancelled] (checked before every window and between transcriber
/// calls the transcriber itself supports — a job cannot interrupt a
/// single native call, only abandon its results).
class CaptionJob {
  CaptionJob({
    required this.transcriber,
    required this.language,
    this.windowMs = 30000,
    this.onProgress,
  });

  final AutoTranscriber transcriber;
  final String language;
  final int windowMs;
  final void Function(CaptionProgress progress)? onProgress;

  /// Called between windows; return true to abort (partial results kept).
  bool Function()? isCancelled;

  Future<CaptionJobResult> run(
    Int16List samples,
    int sampleRate, {
    int videoDurationMs = 0,
  }) async {
    final sw = Stopwatch()..start();
    final windows = splitIntoWindows(samples, sampleRate, windowMs: windowMs);
    final segments = <CaptionSegment>[];
    Object? error;
    var cancelled = false;

    for (final w in windows) {
      if (isCancelled?.call() ?? false) {
        cancelled = true;
        break;
      }
      try {
        final segs = await transcriber.transcribe(w);
        for (final s in segs) {
          segments.add(CaptionSegment(
            startMs: w.startMs + s.startMs,
            endMs: w.startMs + s.endMs,
            text: s.text,
            language: s.language ?? language,
          ));
        }
      } on Object catch (e) {
        error = e;
        break;
      }
      onProgress?.call(CaptionProgress(
        windowsDone: w.index + 1,
        windowsTotal: windows.length,
        msProcessed: w.endMs,
      ));
    }

    final track = SubtitleTrack(
      language: language,
      durationMs: videoDurationMs,
      cues: [
        for (final s in segments)
          SubtitleCue(startMs: s.startMs, endMs: s.endMs, text: s.text),
      ],
    ).sanitised();

    return CaptionJobResult(
      track: track,
      cancelled: cancelled,
      elapsedMs: sw.elapsedMilliseconds,
      error: error,
    );
  }
}
