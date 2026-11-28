import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart';
import 'package:flutter/services.dart';
import 'package:lumora/features/photo_editor/domain/edit_state.dart';
import 'package:lumora/features/photo_editor/engine/photo_renderer.dart';
import 'package:lumora/features/video_editor/domain/audio_analysis.dart';
import 'package:lumora/features/video_editor/domain/look_keyframes.dart';
import 'package:lumora/features/video_editor/domain/timeline_ops.dart';
import 'package:lumora/features/video_editor/domain/video_project.dart';
import 'package:lumora/features/video_editor/engine/ffmpeg_command_builder.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class MediaInfo {
  const MediaInfo({
    required this.durationMs,
    required this.width,
    required this.height,
    required this.hasAudio,
    this.rotation = 0,
  });

  final int durationMs;
  final int width;
  final int height;
  final bool hasAudio;
  final int rotation;
}

class VideoExportException implements Exception {
  VideoExportException(this.message, [this.log]);
  final String message;
  final String? log;
  @override
  String toString() => 'VideoExportException: $message';
}

enum VideoExportQuality {
  /// Look mapped to native FFmpeg filters – real-time speed.
  fast,

  /// Every frame rendered through the GPU shader pipeline – exact match
  /// with the photo editor (HSL, split toning, duotone, glitch…), slower.
  studio,
}

/// FFmpeg backed video engine: probing, thumbnails and export.
class VideoEngine {
  VideoEngine({this.builder = const FfmpegCommandBuilder()});

  final FfmpegCommandBuilder builder;

  Future<Directory> _work(String name) async {
    final dir = Directory(p.join((await getTemporaryDirectory()).path, 'lumora', name));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  Future<MediaInfo> probe(String path) async {
    final session = await FFprobeKit.getMediaInformation(path);
    final info = session.getMediaInformation();
    if (info == null) throw VideoExportException('Cannot read media: $path');
    final durationS = double.tryParse(info.getDuration() ?? '') ?? 0;
    var w = 0;
    var h = 0;
    var rotation = 0;
    var audio = false;
    for (final s in info.getStreams()) {
      final type = s.getType();
      if (type == 'video' && w == 0) {
        w = s.getWidth() ?? 0;
        h = s.getHeight() ?? 0;
        final tags = s.getTags();
        rotation = int.tryParse('${tags?['rotate'] ?? 0}') ?? 0;
      } else if (type == 'audio') {
        audio = true;
      }
    }
    if (rotation % 180 != 0) {
      final t = w;
      w = h;
      h = t;
    }
    return MediaInfo(durationMs: (durationS * 1000).round(), width: w, height: h, hasAudio: audio, rotation: rotation);
  }

  /// Extracts [count] evenly spaced JPEG thumbnails (160 px high).
  Future<List<String>> thumbnails(String path, int durationMs, {int count = 8}) async {
    final dir = await _work('thumbs_${path.hashCode.abs()}');
    final out = <String>[];
    for (var i = 0; i < count; i++) {
      final file = p.join(dir.path, 't$i.jpg');
      if (!File(file).existsSync()) {
        final t = (durationMs * (i + 0.5) / count / 1000).toStringAsFixed(3);
        await FFmpegKit.executeWithArguments([
          '-y',
          '-ss',
          t,
          '-i',
          path,
          '-frames:v',
          '1',
          '-vf',
          'scale=-2:160',
          '-q:v',
          '5',
          file,
        ]);
      }
      if (File(file).existsSync()) out.add(file);
    }
    return out;
  }

  /// Decodes the audio of [path] once and builds its waveform + beat grid.
  /// Returns null when the file has no audio stream. The raw PCM is cached
  /// in the temp directory, so repeated calls re-use the same decode.
  Future<ClipAudio?> analyseAudio(String path, {int bucketMs = 100, int sampleRate = 22050}) async {
    final dir = await _work('audio_${path.hashCode.abs()}');
    final pcmFile = File(p.join(dir.path, 'audio.pcm'));
    if (!pcmFile.existsSync()) {
      await _run(FfmpegCommandBuilder.audioPcmArgs(path, pcmFile.path, sampleRate: sampleRate), 0, null);
      if (!pcmFile.existsSync()) return null;
    }
    final bytes = await pcmFile.readAsBytes();
    final waveform = AudioAnalysis.buildWaveform(bytes, sampleRate, bucketMs: bucketMs);
    final beats = AudioAnalysis.detectBeats(bytes, sampleRate);
    return ClipAudio(waveform: waveform, beats: beats);
  }

  /// Decodes the audio of [path] to mono 16 kHz PCM16 for speech
  /// recognition (Whisper's native rate, so no resampling is needed).
  /// Returns null when the file has no audio stream. Cached like
  /// [analyseAudio], in its own file so the analysis decode is untouched.
  Future<Int16List?> decodeSpeechAudio(String path) async {
    final dir = await _work('speech_${path.hashCode.abs()}');
    final pcmFile = File(p.join(dir.path, 'audio16k.pcm'));
    if (!pcmFile.existsSync()) {
      await _run(FfmpegCommandBuilder.audioPcmArgs(path, pcmFile.path, sampleRate: 16000), 0, null);
      if (!pcmFile.existsSync()) return null;
    }
    final bytes = await pcmFile.readAsBytes();
    if (bytes.length < 2) return null;
    final even = bytes.length - (bytes.length % 2);
    return Int16List.view(bytes.buffer, bytes.offsetInBytes, even ~/ 2);
  }

  /// Exports [project] to an MP4 and returns its path.
  Future<String> export(
    VideoProject project, {
    VideoExportQuality quality = VideoExportQuality.fast,
    PhotoRenderer? renderer,
    void Function(double progress)? onProgress,
    String? outputPath,
  }) async {
    final dir = await _work('export');
    final outDir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'exports'));
    if (!outDir.existsSync()) await outDir.create(recursive: true);
    final output = outputPath ?? p.join(outDir.path, 'Lumora_${DateTime.now().millisecondsSinceEpoch}.mp4');
    final (w, h) = FfmpegCommandBuilder.outputSize(project);
    final total = project.totalDurationMs;

    final texts = <String, String>{};
    for (final t in project.texts) {
      texts[t.id] = await renderTextOverlay(t, w, h, p.join(dir.path, 'text_${t.id}.png'));
    }
    final luts = <String, String>{};
    final lutId = project.look.lutId;
    if (lutId != null) luts[lutId] = await _materializeLut(lutId, dir);
    // vid.stab pass 1 for every stabilised clip.
    final stab = <String, String>{};
    final toStabilize = project.clips.where((c) => c.stabilize).toList();
    for (var i = 0; i < toStabilize.length; i++) {
      final c = toStabilize[i];
      final trf = p.join(dir.path, 'stab_${c.id.hashCode.abs()}.trf');
      try {
        await _run(
          FfmpegCommandBuilder.stabilizeDetectArgs(c, trf),
          c.outMs - c.inMs,
          (v) => onProgress?.call(0.2 * (i + v) / toStabilize.length),
        );
      } on VideoExportException catch (e) {
        throw VideoExportException('Stabilisation is not available in this FFmpeg build: ${e.message}', e.log);
      }
      stab[c.id] = trf;
    }
    final assets = ExportAssets(textOverlayPngs: texts, lutFiles: luts, stabilizeFiles: stab);
    final base0 = toStabilize.isEmpty ? 0.0 : 0.2;
    void progress(double v) => onProgress?.call(base0 + (1 - base0) * v);

    if (quality == VideoExportQuality.fast || renderer == null) {
      final args = builder.build(project, output, assets: assets);
      await _run(args, total, progress);
      return output;
    }

    // ---- Studio: base cut → frames → GPU look → encode.
    final base = p.join(dir.path, 'base.mp4');
    await _run(builder.build(project, base, assets: assets, includeLook: false), total, (v) => progress(v * 0.25));
    final framesDir = Directory(p.join(dir.path, 'frames'));
    if (framesDir.existsSync()) await framesDir.delete(recursive: true);
    await framesDir.create();
    await _run(
      ['-y', '-i', base, '-vsync', '0', p.join(framesDir.path, 'f%06d.png')],
      total,
      (v) => progress(0.25 + v * 0.15),
    );
    final frames = framesDir.listSync().whereType<File>().toList()..sort((a, b) => a.path.compareTo(b.path));
    final animated = project.lookKeyframes.isNotEmpty || project.lookIntensity < 0.999;
    var state = EditState(adjustments: project.look);
    await renderer.prepare(state);
    for (var i = 0; i < frames.length; i++) {
      if (animated) {
        // Frame i is shown at i / fps seconds on the timeline.
        final k = project.lookIntensityAt((i * 1000 / project.fps).round());
        final next = EditState(adjustments: scaleLook(project.look, k));
        if (next != state) {
          state = next;
          await renderer.prepare(state);
        }
      }
      final bytes = await frames[i].readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final src = (await codec.getNextFrame()).image;
      final out = renderer.render(src, state);
      final png = await out.toByteData(format: ui.ImageByteFormat.png);
      await frames[i].writeAsBytes(png!.buffer.asUint8List());
      src.dispose();
      out.dispose();
      progress(0.4 + 0.45 * (i + 1) / frames.length);
    }
    await _run(
      [
        '-y',
        '-framerate',
        '${project.fps}',
        '-i',
        p.join(framesDir.path, 'f%06d.png'),
        '-i',
        base,
        '-map',
        '0:v',
        '-map',
        '1:a?',
        '-c:v',
        builder.encoder.ffmpegName,
        if (builder.encoder == VideoEncoder.x264) ...['-crf', '${builder.crf}', '-preset', builder.preset],
        '-pix_fmt',
        'yuv420p',
        '-c:a',
        'copy',
        '-movflags',
        '+faststart',
        output,
      ],
      total,
      (v) => progress(0.85 + v * 0.15),
    );
    await framesDir.delete(recursive: true);
    return output;
  }

  Future<void> cancel() => FFmpegKit.cancel();

  /// Saves the frame shown [localMs] into [clip] as a JPEG and returns it.
  Future<String> extractFrame(VideoClip clip, int localMs) async {
    final outDir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'exports'));
    if (!outDir.existsSync()) await outDir.create(recursive: true);
    final out = p.join(outDir.path, 'Lumora_frame_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await _run(FfmpegCommandBuilder.frameArgs(clip.path, sourceTimeAt(clip, localMs), out), 0, null);
    if (!File(out).existsSync()) throw VideoExportException('Frame extraction failed');
    return out;
  }

  /// Renders the project (fast mode, small size) and converts it to an
  /// animated GIF with an optimised palette.
  Future<String> exportGif(
    VideoProject project, {
    int width = 480,
    int fps = 12,
    int? maxMs,
    void Function(double progress)? onProgress,
  }) async {
    final dir = await _work('gif');
    final mp4 = p.join(dir.path, 'gif_source.mp4');
    await export(
      project.copyWith(resolution: VideoResolution.p480, music: null),
      outputPath: mp4,
      onProgress: (v) => onProgress?.call(v * 0.7),
    );
    final outDir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'exports'));
    if (!outDir.existsSync()) await outDir.create(recursive: true);
    final gif = p.join(outDir.path, 'Lumora_${DateTime.now().millisecondsSinceEpoch}.gif');
    await _run(
      FfmpegCommandBuilder.gifArgs(mp4, gif, width: width, fps: fps, maxMs: maxMs),
      maxMs ?? project.totalDurationMs,
      (v) => onProgress?.call(0.7 + v * 0.3),
    );
    return gif;
  }

  Future<void> _run(List<String> args, int totalMs, void Function(double)? onProgress) async {
    final done = Completer<void>();
    await FFmpegKit.executeWithArgumentsAsync(
      args,
      (session) async {
        final rc = await session.getReturnCode();
        if (ReturnCode.isSuccess(rc)) {
          done.complete();
        } else if (ReturnCode.isCancel(rc)) {
          done.completeError(VideoExportException('cancelled'));
        } else {
          done.completeError(
            VideoExportException('FFmpeg failed (${rc?.getValue()})', await session.getAllLogsAsString()),
          );
        }
      },
      null,
      (stats) {
        if (totalMs > 0) onProgress?.call(math.min(1, stats.getTime() / totalMs));
      },
    );
    await done.future;
  }

  Future<String> _materializeLut(String id, Directory dir) async {
    if (id.startsWith('user:')) {
      final support = await getApplicationSupportDirectory();
      return p.join(support.path, 'luts', '${id.substring(5)}.cube');
    }
    final name = id.substring('builtin:'.length);
    final file = File(p.join(dir.path, '$name.cube'));
    if (!file.existsSync()) {
      await file.writeAsString(await rootBundle.loadString('assets/luts/$name.cube'));
    }
    return file.path;
  }

  /// Rasterises a text overlay as a full frame transparent PNG. Flutter's
  /// text stack gives correct Arabic shaping, bidi and emoji – something
  /// FFmpeg's drawtext cannot guarantee on mobile builds.
  static Future<String> renderTextOverlay(VideoText t, int w, int h, String path, {String? fontFamily}) async {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    final minDim = math.min(w, h).toDouble();
    final tp = TextPainter(
      text: TextSpan(
        text: t.text,
        style: TextStyle(
          color: Color(t.color),
          fontSize: t.fontSize * minDim,
          fontWeight: t.bold ? FontWeight.w700 : FontWeight.w400,
          // Null in production: the device's system font. Tests pass a
          // bundled family so goldens are reproducible off-device.
          fontFamily: fontFamily,
          shadows: const [Shadow(blurRadius: 6, color: Color(0x88000000), offset: Offset(0, 2))],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: RegExp(r'[\u0590-\u08FF]').hasMatch(t.text) ? TextDirection.rtl : TextDirection.ltr,
    )..layout(maxWidth: w * 0.9);
    final pos = Offset(t.x * w - tp.width / 2, t.y * h - tp.height / 2);
    if (t.backgroundColor != null) {
      final pad = minDim * 0.015;
      canvas.drawRRect(
        RRect.fromRectAndRadius((pos & tp.size).inflate(pad), Radius.circular(pad)),
        Paint()..color = Color(t.backgroundColor!),
      );
    }
    tp.paint(canvas, pos);
    final pic = rec.endRecording();
    final image = await pic.toImage(w, h);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    pic.dispose();
    await File(path).writeAsBytes(bytes!.buffer.asUint8List());
    return path;
  }
}
