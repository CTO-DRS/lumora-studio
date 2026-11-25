import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:lumora/features/video_editor/domain/captioning.dart';
import 'package:lumora/features/video_editor/domain/subtitles.dart';

/// A ready-to-use transcriber plus the means to release its native
/// resources (Wave 2 W3-M6a). The ONNX implementation lives in
/// `features/ai/data/whisper_transcriber_factory.dart`.
abstract interface class CaptionTranscriberHandle {
  AutoTranscriber get transcriber;
  Future<void> close();
}

/// The file has no usable audio track.
class NoAudioException implements Exception {
  const NoAudioException();
  @override
  String toString() => 'NoAudioException: the video has no audio to caption';
}

/// Orchestrates one captioning run: decode speech audio, open the model,
/// run the cancellable [CaptionJob], always release the model, and write
/// SRT/VTT sidecars. UI-free and platform-free: the audio decoder and the
/// transcriber factory are injected, so it is unit-tested with fakes.
class CaptionService {
  CaptionService({required this.decodeAudio, required this.openTranscriber});

  /// Mono 16 kHz PCM16 of the video's audio, or null when there is none.
  final Future<Int16List?> Function(String videoPath) decodeAudio;

  /// Opens the model (downloaded already) and returns the handle.
  final Future<CaptionTranscriberHandle> Function() openTranscriber;

  static const int sampleRate = 16000;

  /// Captions [videoPath]. [language] is the label stored on the track
  /// (null = auto, stored as `und`); the transcriber decides what it hears.
  Future<CaptionJobResult> caption(
    String videoPath, {
    int videoDurationMs = 0,
    String? language,
    void Function(CaptionProgress progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final pcm = await decodeAudio(videoPath);
    if (pcm == null || pcm.isEmpty) throw const NoAudioException();
    if (isCancelled?.call() ?? false) {
      return CaptionJobResult(
        track: SubtitleTrack(language: language ?? 'und', durationMs: videoDurationMs),
        cancelled: true,
        elapsedMs: 0,
      );
    }
    final handle = await openTranscriber();
    try {
      final job = CaptionJob(transcriber: handle.transcriber, language: language ?? 'und', onProgress: onProgress)
        ..isCancelled = isCancelled;
      return await job.run(pcm, sampleRate, videoDurationMs: videoDurationMs);
    } finally {
      await handle.close();
    }
  }

  /// Writes [track] next to [directory] as `<baseName>.srt` and/or `.vtt`
  /// and returns the written paths. Names are reduced to a safe file stem.
  Future<List<String>> exportSidecars(
    SubtitleTrack track,
    Directory directory,
    String baseName, {
    bool srt = true,
    bool vtt = true,
  }) async {
    final stem = safeFileStem(baseName);
    if (!directory.existsSync()) await directory.create(recursive: true);
    final out = <String>[];
    if (srt) {
      final f = File('${directory.path}/$stem.srt');
      await f.writeAsString(writeSrt(track));
      out.add(f.path);
    }
    if (vtt) {
      final f = File('${directory.path}/$stem.vtt');
      await f.writeAsString(writeVtt(track));
      out.add(f.path);
    }
    return out;
  }

  /// Letters, digits, dash, underscore, dot (and Arabic letters) only; never
  /// empty, never a path.
  static String safeFileStem(String name) {
    final base = name.split(RegExp(r'[\\/]')).last;
    final noExt = base.contains('.') ? base.substring(0, base.lastIndexOf('.')) : base;
    final cleaned = noExt.replaceAll(RegExp(r'[^\w\u0600-\u06FF.-]+'), '_').replaceAll(RegExp(r'^[._]+|[._]+$'), '');
    return cleaned.isEmpty ? 'captions' : cleaned;
  }
}
