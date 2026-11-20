import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:lumora/features/photo_editor/domain/adjustments.dart';

part 'video_project.freezed.dart';
part 'video_project.g.dart';

enum TransitionKind {
  none('none'),
  fade('fade'),
  dissolve('dissolve'),
  wipeLeft('wipeleft'),
  wipeRight('wiperight'),
  slideLeft('slideleft'),
  slideUp('slideup'),
  circleOpen('circleopen'),
  zoomIn('zoomin'),
  pixelize('pixelize');

  const TransitionKind(this.ffmpegName);

  /// Name of the matching FFmpeg `xfade` transition.
  final String ffmpegName;
}

/// One clip on the timeline. Times are in milliseconds of the *source*.
@freezed
abstract class VideoClip with _$VideoClip {
  const factory VideoClip({
    required String id,
    required String path,
    required int sourceDurationMs,
    required int outMs,
    @Default(0) int inMs,
    @Default(1) double speed,
    @Default(false) bool reversed,
    @Default(1) double volume,
    @Default(true) bool hasAudio,
    @Default(0) int sourceWidth,
    @Default(0) int sourceHeight,

    /// Crop rect normalized to the source frame (l, t, r, b).
    @Default([0, 0, 1, 1]) List<double> crop,
    @Default(0) int quarterTurns,
    @Default(TransitionKind.none) TransitionKind transitionOut,
    @Default(500) int transitionMs,
  }) = _VideoClip;

  const VideoClip._();

  factory VideoClip.fromJson(Map<String, dynamic> json) => _$VideoClipFromJson(json);

  /// Length on the timeline (after trim and speed).
  int get durationMs => ((outMs - inMs) / speed).round();

  bool get isCropped => crop[0] != 0 || crop[1] != 0 || crop[2] != 1 || crop[3] != 1;
}

/// A text overlay shown between [startMs] and [endMs] on the timeline. It
/// is rasterised by Flutter (full Arabic shaping & RTL) and composited by
/// FFmpeg's overlay filter.
@freezed
abstract class VideoText with _$VideoText {
  const factory VideoText({
    required String id,
    required String text,
    @Default(0) int startMs,
    @Default(3000) int endMs,
    @Default(0.5) double x,
    @Default(0.8) double y,
    @Default(0.07) double fontSize,
    @Default(0xFFFFFFFF) int color,
    int? backgroundColor,
    @Default(true) bool bold,
  }) = _VideoText;

  factory VideoText.fromJson(Map<String, dynamic> json) => _$VideoTextFromJson(json);
}

@freezed
abstract class AudioTrack with _$AudioTrack {
  const factory AudioTrack({
    required String path,
    @Default(0) int startOffsetMs,
    @Default(0.8) double volume,
    @Default(1000) int fadeInMs,
    @Default(1500) int fadeOutMs,
    @Default(true) bool loop,
  }) = _AudioTrack;

  factory AudioTrack.fromJson(Map<String, dynamic> json) => _$AudioTrackFromJson(json);
}

enum VideoResolution {
  p480(854, 480),
  p720(1280, 720),
  p1080(1920, 1080),
  p2160(3840, 2160);

  const VideoResolution(this.width, this.height);
  final int width;
  final int height;
}

enum VideoAspect {
  landscape(16, 9),
  portrait(9, 16),
  square(1, 1),
  classic(4, 3),
  social(4, 5);

  const VideoAspect(this.w, this.h);
  final int w;
  final int h;
}

@freezed
abstract class VideoProject with _$VideoProject {
  const factory VideoProject({
    @Default(<VideoClip>[]) List<VideoClip> clips,
    @Default(<VideoText>[]) List<VideoText> texts,
    AudioTrack? music,
    @Default(1) double originalVolume,

    /// Look applied to every frame (same engine as photos).
    @Default(Adjustments()) Adjustments look,
    String? presetId,
    @Default(VideoAspect.landscape) VideoAspect aspect,
    @Default(VideoResolution.p1080) VideoResolution resolution,
    @Default(30) int fps,
  }) = _VideoProject;

  factory VideoProject.fromJson(Map<String, dynamic> json) => _$VideoProjectFromJson(json);
}
