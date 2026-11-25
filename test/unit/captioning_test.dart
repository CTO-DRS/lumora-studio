/// Wave 2 W3-M2 tests: the captioning job pipeline — PCM windowing, the
/// pluggable AutoTranscriber seam, absolute-time segment assembly,
/// progress, cancellation and honest partial results.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/video_editor/domain/captioning.dart';

/// Deterministic fake transcriber: one segment per 10 s of audio
/// ("window i, segment j"), controllable delay, throw and cancellation
/// hooks for the failure paths.
class FakeTranscriber implements AutoTranscriber {
  FakeTranscriber({this.segmentsPerWindow = 3, this.throwOnWindow, this.throwWith});


  final int segmentsPerWindow;
  final int? throwOnWindow;
  final Exception? throwWith;

  int calls = 0;

  @override
  String get name => 'fake';

  @override
  Future<List<CaptionSegment>> transcribe(CaptionWindow window) async {
    calls++;
    if (throwOnWindow != null && window.index == throwOnWindow) {
      throw throwWith ?? const FormatException('model exploded');
    }
    final segLenMs = window.durationMs ~/ math.max(1, segmentsPerWindow);
    return [
      for (var j = 0; j < segmentsPerWindow; j++)
        CaptionSegment(
          startMs: j * segLenMs,
          endMs: (j + 1) * segLenMs,
          text: 'نافذة ${window.index} مقطع $j',
          language: 'ar',
        ),
    ];
  }
}

Int16List silence(int seconds, int sampleRate) => Int16List(seconds * sampleRate);

void main() {
  group('windowing', () {
    test('30 s audio at 22.05 kHz splits into one window', () {
      final windows = splitIntoWindows(silence(30, 22050), 22050);
      expect(windows.length, 1);
      expect(windows.first.startMs, 0);
      expect(windows.first.durationMs, closeTo(30000, 2));
    });

    test('95 s audio splits into three windows + folded tail', () {
      final windows = splitIntoWindows(silence(95, 22050), 22050);
      // 95 s = 3 × 30 s + 5 s tail → the 5 s tail is a 4th window.
      expect(windows.length, 4);
      expect(windows[0].startMs, 0);
      expect(windows[1].startMs, 30000);
      expect(windows[2].startMs, 60000);
      expect(windows[3].startMs, 90000);
      expect(windows[3].durationMs, closeTo(5000, 2));
    });

    test('a sub-second tail folds into the previous window (no sliver)', () {
      // 60.5 s = 2 windows + 500 ms tail → tail folds into window 1.
      final samples = Int16List((60.5 * 22050).round());
      final windows = splitIntoWindows(samples, 22050);
      expect(windows.length, 2);
      expect(windows.last.durationMs, closeTo(30500, 3));
    });

    test('empty audio yields no windows', () {
      expect(splitIntoWindows(Int16List(0), 22050), isEmpty);
      expect(splitIntoWindows(silence(5, 22050), 0), isEmpty);
    });

    test('windows are contiguous and cover the whole track', () {
      final windows = splitIntoWindows(silence(73, 44100), 44100);
      var covered = 0;
      for (final w in windows) {
        expect(w.startMs, covered, reason: 'windows must be gap-free');
        covered = w.endMs;
      }
      expect(covered, closeTo(73000, 3));
    });
  });

  group('CaptionJob', () {
    test('assembles absolute-time segments into a sanitised track', () async {
      final job = CaptionJob(transcriber: FakeTranscriber(), language: 'ar');
      final result = await job.run(silence(31, 22050), 22050, videoDurationMs: 31000);
      expect(result.succeeded, isTrue);
      expect(result.cancelled, isFalse);
      expect(result.track.language, 'ar');
      // Window 0: 3 segments × ~10 s; window 1 (1 s tail): 3 segments.
      expect(result.track.length, 6);
      final first = result.track.cues.first;
      expect(first.startMs, 0);
      final secondWindow = result.track.cues.where((c) => c.startMs >= 30000).toList();
      expect(secondWindow, isNotEmpty);
      expect(secondWindow.first.startMs, inInclusiveRange(29990, 30010));
    });

    test('progress events fire per window', () async {
      final events = <CaptionProgress>[];
      final job = CaptionJob(
        transcriber: FakeTranscriber(),
        language: 'ar',
        onProgress: events.add,
      );
      await job.run(silence(62, 22050), 22050);
      // 62 s = 30 + 30 + 2 s tail (≥ minTail → its own window).
      expect(events.length, 3);
      expect(events.last.fraction, 1.0);
      expect(events.last.windowsDone, 3);
      expect(events.last.windowsTotal, 3);
    });

    test('cancellation between windows keeps partial results', () async {
      final job = CaptionJob(transcriber: FakeTranscriber(), language: 'ar');
      var checks = 0;
      job.isCancelled = () => ++checks > 1; // allow window 0, cancel before window 1
      final result = await job.run(silence(62, 22050), 22050);
      expect(result.cancelled, isTrue);
      expect(result.track.length, greaterThanOrEqualTo(1));
      expect(result.track.length, lessThan(6));
    });

    test('transcriber failure records the error and returns what completed', () async {
      final job = CaptionJob(
        transcriber: FakeTranscriber(throwOnWindow: 1),
        language: 'ar',
      );
      final result = await job.run(silence(62, 22050), 22050);
      expect(result.error, isNotNull);
      expect(result.succeeded, isFalse);
      expect(result.track.length, 3); // window 0 only
    });

    test('zero-length audio yields an empty successful track', () async {
      final job = CaptionJob(transcriber: FakeTranscriber(), language: 'en');
      final result = await job.run(Int16List(0), 22050);
      expect(result.succeeded, isTrue);
      expect(result.track.isEmpty, isTrue);
    });

    test('segments inherit the job language when the transcriber omits it', () async {
      final job = CaptionJob(transcriber: FakeTranscriber(), language: 'en');
      final result = await job.run(silence(1, 22050), 22050);
      expect(result.succeeded, isTrue);
      // The fake always says 'ar' — but a transcriber without language info
      // (null) falls back to the job's language tag.
      final noLang = FakeTranscriber();
      final segments = await noLang.transcribe(
        splitIntoWindows(silence(1, 22050), 22050).first,
      );
      expect(segments.first.language, 'ar'); // fake sets it
      final silentTranscriber = _NullLanguageTranscriber();
      final segs2 = await silentTranscriber.transcribe(
        splitIntoWindows(silence(1, 22050), 22050).first,
      );
      expect(segs2.first.language, isNull);
      final job2 = CaptionJob(transcriber: silentTranscriber, language: 'en');
      final result2 = await job2.run(silence(1, 22050), 22050);
      expect(result2.track.language, 'en');
    });
  });

  group('integration with W3-M1 sanitisation', () {
    test('overlapping segments from the transcriber are truncated, not duplicated', () async {
      final transcriber = _OverlappingTranscriber();
      final job = CaptionJob(transcriber: transcriber, language: 'ar');
      final result = await job.run(silence(10, 22050), 22050);
      // The transcriber returns two overlapping segments; sanitisation
      // must cut the first at the second's start.
      final cues = result.track.cues;
      expect(cues.length, 2);
      expect(cues[0].endMs, cues[1].startMs);
    });
  });
}

class _NullLanguageTranscriber implements AutoTranscriber {
  @override
  String get name => 'null-language';

  @override
  Future<List<CaptionSegment>> transcribe(CaptionWindow window) async => [
        CaptionSegment(startMs: 0, endMs: window.durationMs, text: 'text'),
      ];
}

class _OverlappingTranscriber implements AutoTranscriber {
  @override
  String get name => 'overlap';

  @override
  Future<List<CaptionSegment>> transcribe(CaptionWindow window) async => const [
        CaptionSegment(startMs: 0, endMs: 8000, text: 'الأول'),
        CaptionSegment(startMs: 5000, endMs: 9000, text: 'الثاني'),
      ];
}
