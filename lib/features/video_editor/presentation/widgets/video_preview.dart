import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumora/core/providers.dart';
import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/photo_editor/engine/photo_renderer.dart';
import 'package:lumora/features/video_editor/domain/timeline_ops.dart';
import 'package:lumora/features/video_editor/domain/video_project.dart';
import 'package:lumora/features/video_editor/presentation/video_editor_controller.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

/// Plays the timeline clip by clip and previews the look in real time with
/// a fragment shader applied through `ImageFilter.shader` (Impeller).
class VideoPreview extends ConsumerStatefulWidget {
  const VideoPreview({super.key});

  @override
  ConsumerState<VideoPreview> createState() => VideoPreviewState();
}

class VideoPreviewState extends ConsumerState<VideoPreview> {
  VideoPlayerController? _player;
  int _clipIndex = -1;
  bool playing = false;
  ui.Image? _lut;
  int _lutSize = 2;
  String? _lutId;
  ui.Image? _dummy;

  @override
  void dispose() {
    _player?.dispose();
    _lut?.dispose();
    _dummy?.dispose();
    super.dispose();
  }

  Future<void> _ensureLut(Adjustments look) async {
    _dummy ??= await imageFromRgba(Uint8List.fromList([0, 0, 0, 255]), 1, 1);
    if (look.lutId == _lutId) return;
    _lutId = look.lutId;
    _lut?.dispose();
    _lut = null;
    if (look.lutId != null) {
      final lut = await ref.read(lutRepositoryProvider).load(look.lutId!);
      _lut = await imageFromRgba(lut.toAtlasRgba(), lut.atlasWidth, lut.atlasHeight);
      _lutSize = lut.size;
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadClip(int index, {int localMs = 0, bool autoplay = false}) async {
    final project = ref.read(videoEditorControllerProvider).project;
    if (index < 0 || index >= project.clips.length) return;
    final clip = project.clips[index];
    final old = _player;
    final player = VideoPlayerController.file(File(clip.path));
    _player = player;
    _clipIndex = index;
    await player.initialize();
    await old?.dispose();
    await player.setPlaybackSpeed(clip.speed);
    await player.setVolume(clip.volume * project.originalVolume);
    await player.seekTo(Duration(milliseconds: clip.inMs + (localMs * clip.speed).round()));
    player.addListener(_onTick);
    if (autoplay) await player.play();
    if (mounted) setState(() {});
  }

  void _onTick() {
    final player = _player;
    if (player == null || !playing) return;
    final ctrl = ref.read(videoEditorControllerProvider.notifier);
    final project = ref.read(videoEditorControllerProvider).project;
    if (_clipIndex >= project.clips.length) return;
    final clip = project.clips[_clipIndex];
    final pos = player.value.position.inMilliseconds;
    final local = ((pos - clip.inMs) / clip.speed).round();
    ctrl.seek(project.clipStarts[_clipIndex] + local);
    if (pos >= clip.outMs - 30 || player.value.isCompleted) {
      player.removeListener(_onTick);
      if (_clipIndex + 1 < project.clips.length) {
        unawaited(_loadClip(_clipIndex + 1, autoplay: true));
      } else {
        unawaited(player.pause());
        setState(() => playing = false);
      }
    }
  }

  Future<void> togglePlay() async {
    if (playing) {
      await _player?.pause();
      setState(() => playing = false);
      return;
    }
    final s = ref.read(videoEditorControllerProvider);
    final hit = s.project.clipAt(s.playheadMs >= s.project.totalDurationMs - 50 ? 0 : s.playheadMs);
    if (hit == null) return;
    setState(() => playing = true);
    await _loadClip(hit.$1, localMs: hit.$2, autoplay: true);
  }

  /// Shows the frame under the playhead (when paused).
  Future<void> scrubTo(int ms) async {
    if (playing) return;
    final s = ref.read(videoEditorControllerProvider);
    final hit = s.project.clipAt(ms);
    if (hit == null) return;
    final (index, local) = hit;
    final clip = s.project.clips[index];
    if (index != _clipIndex || _player == null) {
      await _loadClip(index, localMs: local);
    } else {
      await _player!.seekTo(Duration(milliseconds: clip.inMs + (local * clip.speed).round()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(videoEditorControllerProvider);
    final shaders = ref.watch(shaderLibraryProvider).value;
    final project = s.project;
    unawaited(_ensureLut(project.look));
    final player = _player;
    if (player == null && project.clips.isNotEmpty) {
      unawaited(_loadClip(0));
    }
    final aspect = project.aspect.w / project.aspect.h;
    final clip = _clipIndex >= 0 && _clipIndex < project.clips.length ? project.clips[_clipIndex] : null;

    Widget video = player != null && player.value.isInitialized
        ? FittedBox(
            child: SizedBox(
              width: player.value.size.width,
              height: player.value.size.height,
              child: RotatedBox(quarterTurns: clip?.quarterTurns ?? 0, child: VideoPlayer(player)),
            ),
          )
        : const Center(child: CircularProgressIndicator());

    if (shaders != null && ui.ImageFilter.isShaderFilterSupported && _dummy != null && !project.look.isNeutral) {
      final a = project.look;
      final shader = shaders.videoFilter.fragmentShader()
        ..getUniformVec4('uTone').set(a.exposure, a.contrast, a.highlights, a.shadows)
        ..getUniformVec4('uColor').set(a.temperature, a.tint, a.vibrance, a.saturation)
        ..getUniformVec4('uFx').set(a.fade, -a.vignette.clamp(-1.0, 0.0), a.grain, s.playheadMs / 1000)
        ..getUniformVec4('uLutInfo').set(_lut != null ? 1 : 0, _lutSize.toDouble(), a.lutIntensity, 0)
        ..setImageSampler(1, _lut ?? _dummy!, filterQuality: FilterQuality.low);
      video = ImageFiltered(imageFilter: ui.ImageFilter.shader(shader), child: video);
    }

    final visibleTexts = project.texts.where((t) => s.playheadMs >= t.startMs && s.playheadMs <= t.endMs);

    return Center(
      child: AspectRatio(
        aspectRatio: aspect,
        child: ClipRect(
          child: ColoredBox(
            color: Colors.black,
            child: LayoutBuilder(
              builder: (context, c) => Stack(
                fit: StackFit.expand,
                children: [
                  video,
                  for (final t in visibleTexts) _TextPreview(text: t, size: c.biggest),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TextPreview extends StatelessWidget {
  const _TextPreview({required this.text, required this.size});
  final VideoText text;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final minDim = size.shortestSide;
    return Align(
      alignment: Alignment(text.x * 2 - 1, text.y * 2 - 1),
      child: Container(
        padding: EdgeInsets.all(minDim * 0.015),
        decoration: text.backgroundColor == null
            ? null
            : BoxDecoration(color: Color(text.backgroundColor!), borderRadius: BorderRadius.circular(minDim * 0.015)),
        child: Text(
          text.text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(text.color),
            fontSize: text.fontSize * minDim,
            fontWeight: text.bold ? FontWeight.w700 : FontWeight.w400,
            shadows: const [Shadow(blurRadius: 6, color: Color(0x88000000), offset: Offset(0, 2))],
          ),
        ),
      ),
    );
  }
}
