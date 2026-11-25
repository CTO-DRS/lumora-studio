import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/video_editor/domain/captioning.dart';
import 'package:lumora/features/video_editor/domain/subtitles.dart';
import 'package:lumora/features/video_editor/engine/caption_service.dart';

class _Fake implements AutoTranscriber {
  int calls = 0;
  @override
  String get name => 'fake';
  @override
  Future<List<CaptionSegment>> transcribe(CaptionWindow w) async {
    calls++;
    return [CaptionSegment(startMs: 100, endMs: 900, text: 'window ${w.index}')];
  }
}

class _Handle implements CaptionTranscriberHandle {
  _Handle(this.transcriber);
  @override
  final AutoTranscriber transcriber;
  bool closed = false;
  @override
  Future<void> close() async => closed = true;
}

Int16List _pcm(double seconds) => Int16List((16000 * seconds).round())..fillRange(0, (16000 * seconds).round(), 1000);

void main() {
  group('CaptionService.caption', () {
    test('runs the job, reports progress and closes the model', () async {
      final fake = _Fake();
      final handle = _Handle(fake);
      final progress = <double>[];
      final svc = CaptionService(decodeAudio: (_) async => _pcm(65), openTranscriber: () async => handle);
      final r = await svc.caption(
        '/v.mp4',
        videoDurationMs: 65000,
        language: 'ar',
        onProgress: (p) => progress.add(p.fraction),
      );
      expect(r.succeeded, isTrue);
      expect(r.track.language, 'ar');
      expect(r.track.length, 3); // 65 s = 30 + 30 + 5 s windows
      expect(r.track.cues[1].startMs, 30100);
      expect(progress, [1 / 3, 2 / 3, 1.0]);
      expect(handle.closed, isTrue);
    });

    test('no audio throws NoAudioException before the model opens', () async {
      var opened = false;
      final svc = CaptionService(
        decodeAudio: (_) async => null,
        openTranscriber: () async {
          opened = true;
          return _Handle(_Fake());
        },
      );
      await expectLater(svc.caption('/v.mp4'), throwsA(isA<NoAudioException>()));
      expect(opened, isFalse);
    });

    test('cancel keeps partial results and still closes the model', () async {
      final fake = _Fake();
      final handle = _Handle(fake);
      final svc = CaptionService(decodeAudio: (_) async => _pcm(65), openTranscriber: () async => handle);
      final r = await svc.caption('/v.mp4', isCancelled: () => fake.calls >= 1);
      expect(r.cancelled, isTrue);
      expect(r.track.length, 1);
      expect(handle.closed, isTrue);
      expect(r.track.language, 'und');
    });

    test('cancelled before start never opens the model', () async {
      var opened = false;
      final svc = CaptionService(
        decodeAudio: (_) async => _pcm(5),
        openTranscriber: () async {
          opened = true;
          return _Handle(_Fake());
        },
      );
      final r = await svc.caption('/v.mp4', isCancelled: () => true);
      expect(r.cancelled, isTrue);
      expect(opened, isFalse);
    });

    test('a transcriber failure is a partial result and the model closes', () async {
      final handle = _Handle(_Throwing());
      final svc = CaptionService(decodeAudio: (_) async => _pcm(40), openTranscriber: () async => handle);
      final r = await svc.caption('/v.mp4');
      expect(r.error, isNotNull);
      expect(r.track.length, 1);
      expect(handle.closed, isTrue);
    });

    test('closes the model even when the job itself throws', () async {
      final handle = _Handle(_Fake());
      final svc = CaptionService(decodeAudio: (_) async => _pcm(5), openTranscriber: () async => handle);
      await svc.caption('/v.mp4', onProgress: (_) => throw StateError('ui blew up')).then((_) {}, onError: (_) {});
      expect(handle.closed, isTrue);
    });
  });

  group('exportSidecars', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('lumora_caps'));
    tearDown(() => tmp.deleteSync(recursive: true));

    final track = SubtitleTrack(
      language: 'en',
      cues: [const SubtitleCue(startMs: 0, endMs: 1500, text: 'Hello')],
    );
    final svc = CaptionService(decodeAudio: (_) async => null, openTranscriber: () => throw UnimplementedError());

    test('writes SRT and VTT that parse back', () async {
      final paths = await svc.exportSidecars(track, Directory('${tmp.path}/out'), 'My Clip.mp4');
      expect(paths.map((p) => p.split('/').last), ['My_Clip.srt', 'My_Clip.vtt']);
      expect(parseSrt(File(paths[0]).readAsStringSync()).cues.single.text, 'Hello');
      expect(parseVtt(File(paths[1]).readAsStringSync()).cues.single.endMs, 1500);
    });

    test('format flags are honoured', () async {
      final paths = await svc.exportSidecars(track, tmp, 'a', vtt: false);
      expect(paths, hasLength(1));
      expect(paths.single, endsWith('a.srt'));
    });

    test('file stems are safe', () {
      expect(CaptionService.safeFileStem('../../etc/passwd'), 'passwd');
      expect(CaptionService.safeFileStem(r'C:\x\clip 1.final.mov'), 'clip_1.final');
      expect(CaptionService.safeFileStem('...'), 'captions');
      expect(CaptionService.safeFileStem('فيديو رمضان.mp4'), 'فيديو_رمضان');
    });
  });
}

class _Throwing implements AutoTranscriber {
  int n = 0;
  @override
  String get name => 'throwing';
  @override
  Future<List<CaptionSegment>> transcribe(CaptionWindow w) async {
    if (n++ == 0) return [const CaptionSegment(startMs: 0, endMs: 500, text: 'ok')];
    throw StateError('model crashed');
  }
}
