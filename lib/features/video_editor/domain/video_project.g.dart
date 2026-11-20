// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_project.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_VideoClip _$VideoClipFromJson(Map<String, dynamic> json) => _VideoClip(
  id: json['id'] as String,
  path: json['path'] as String,
  sourceDurationMs: (json['sourceDurationMs'] as num).toInt(),
  outMs: (json['outMs'] as num).toInt(),
  inMs: (json['inMs'] as num?)?.toInt() ?? 0,
  speed: (json['speed'] as num?)?.toDouble() ?? 1,
  reversed: json['reversed'] as bool? ?? false,
  volume: (json['volume'] as num?)?.toDouble() ?? 1,
  hasAudio: json['hasAudio'] as bool? ?? true,
  sourceWidth: (json['sourceWidth'] as num?)?.toInt() ?? 0,
  sourceHeight: (json['sourceHeight'] as num?)?.toInt() ?? 0,
  crop:
      (json['crop'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList() ??
      const [0, 0, 1, 1],
  quarterTurns: (json['quarterTurns'] as num?)?.toInt() ?? 0,
  transitionOut:
      $enumDecodeNullable(_$TransitionKindEnumMap, json['transitionOut']) ??
      TransitionKind.none,
  transitionMs: (json['transitionMs'] as num?)?.toInt() ?? 500,
  stabilize: json['stabilize'] as bool? ?? false,
  stabilizeStrength: (json['stabilizeStrength'] as num?)?.toDouble() ?? 0.5,
);

Map<String, dynamic> _$VideoClipToJson(_VideoClip instance) =>
    <String, dynamic>{
      'id': instance.id,
      'path': instance.path,
      'sourceDurationMs': instance.sourceDurationMs,
      'outMs': instance.outMs,
      'inMs': instance.inMs,
      'speed': instance.speed,
      'reversed': instance.reversed,
      'volume': instance.volume,
      'hasAudio': instance.hasAudio,
      'sourceWidth': instance.sourceWidth,
      'sourceHeight': instance.sourceHeight,
      'crop': instance.crop,
      'quarterTurns': instance.quarterTurns,
      'transitionOut': _$TransitionKindEnumMap[instance.transitionOut]!,
      'transitionMs': instance.transitionMs,
      'stabilize': instance.stabilize,
      'stabilizeStrength': instance.stabilizeStrength,
    };

const _$TransitionKindEnumMap = {
  TransitionKind.none: 'none',
  TransitionKind.fade: 'fade',
  TransitionKind.dissolve: 'dissolve',
  TransitionKind.wipeLeft: 'wipeLeft',
  TransitionKind.wipeRight: 'wipeRight',
  TransitionKind.slideLeft: 'slideLeft',
  TransitionKind.slideUp: 'slideUp',
  TransitionKind.circleOpen: 'circleOpen',
  TransitionKind.zoomIn: 'zoomIn',
  TransitionKind.pixelize: 'pixelize',
};

_VideoText _$VideoTextFromJson(Map<String, dynamic> json) => _VideoText(
  id: json['id'] as String,
  text: json['text'] as String,
  startMs: (json['startMs'] as num?)?.toInt() ?? 0,
  endMs: (json['endMs'] as num?)?.toInt() ?? 3000,
  x: (json['x'] as num?)?.toDouble() ?? 0.5,
  y: (json['y'] as num?)?.toDouble() ?? 0.8,
  fontSize: (json['fontSize'] as num?)?.toDouble() ?? 0.07,
  color: (json['color'] as num?)?.toInt() ?? 0xFFFFFFFF,
  backgroundColor: (json['backgroundColor'] as num?)?.toInt(),
  bold: json['bold'] as bool? ?? true,
);

Map<String, dynamic> _$VideoTextToJson(_VideoText instance) =>
    <String, dynamic>{
      'id': instance.id,
      'text': instance.text,
      'startMs': instance.startMs,
      'endMs': instance.endMs,
      'x': instance.x,
      'y': instance.y,
      'fontSize': instance.fontSize,
      'color': instance.color,
      'backgroundColor': instance.backgroundColor,
      'bold': instance.bold,
    };

_AudioTrack _$AudioTrackFromJson(Map<String, dynamic> json) => _AudioTrack(
  path: json['path'] as String,
  startOffsetMs: (json['startOffsetMs'] as num?)?.toInt() ?? 0,
  volume: (json['volume'] as num?)?.toDouble() ?? 0.8,
  fadeInMs: (json['fadeInMs'] as num?)?.toInt() ?? 1000,
  fadeOutMs: (json['fadeOutMs'] as num?)?.toInt() ?? 1500,
  loop: json['loop'] as bool? ?? true,
);

Map<String, dynamic> _$AudioTrackToJson(_AudioTrack instance) =>
    <String, dynamic>{
      'path': instance.path,
      'startOffsetMs': instance.startOffsetMs,
      'volume': instance.volume,
      'fadeInMs': instance.fadeInMs,
      'fadeOutMs': instance.fadeOutMs,
      'loop': instance.loop,
    };

_LookKeyframe _$LookKeyframeFromJson(Map<String, dynamic> json) =>
    _LookKeyframe(
      timeMs: (json['timeMs'] as num).toInt(),
      intensity: (json['intensity'] as num?)?.toDouble() ?? 1,
    );

Map<String, dynamic> _$LookKeyframeToJson(_LookKeyframe instance) =>
    <String, dynamic>{
      'timeMs': instance.timeMs,
      'intensity': instance.intensity,
    };

_VideoProject _$VideoProjectFromJson(Map<String, dynamic> json) =>
    _VideoProject(
      clips:
          (json['clips'] as List<dynamic>?)
              ?.map((e) => VideoClip.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <VideoClip>[],
      texts:
          (json['texts'] as List<dynamic>?)
              ?.map((e) => VideoText.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <VideoText>[],
      music: json['music'] == null
          ? null
          : AudioTrack.fromJson(json['music'] as Map<String, dynamic>),
      originalVolume: (json['originalVolume'] as num?)?.toDouble() ?? 1,
      look: json['look'] == null
          ? const Adjustments()
          : Adjustments.fromJson(json['look'] as Map<String, dynamic>),
      presetId: json['presetId'] as String?,
      lookIntensity: (json['lookIntensity'] as num?)?.toDouble() ?? 1,
      lookKeyframes:
          (json['lookKeyframes'] as List<dynamic>?)
              ?.map((e) => LookKeyframe.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <LookKeyframe>[],
      aspect:
          $enumDecodeNullable(_$VideoAspectEnumMap, json['aspect']) ??
          VideoAspect.landscape,
      resolution:
          $enumDecodeNullable(_$VideoResolutionEnumMap, json['resolution']) ??
          VideoResolution.p1080,
      fps: (json['fps'] as num?)?.toInt() ?? 30,
    );

Map<String, dynamic> _$VideoProjectToJson(_VideoProject instance) =>
    <String, dynamic>{
      'clips': instance.clips.map((e) => e.toJson()).toList(),
      'texts': instance.texts.map((e) => e.toJson()).toList(),
      'music': instance.music?.toJson(),
      'originalVolume': instance.originalVolume,
      'look': instance.look.toJson(),
      'presetId': instance.presetId,
      'lookIntensity': instance.lookIntensity,
      'lookKeyframes': instance.lookKeyframes.map((e) => e.toJson()).toList(),
      'aspect': _$VideoAspectEnumMap[instance.aspect]!,
      'resolution': _$VideoResolutionEnumMap[instance.resolution]!,
      'fps': instance.fps,
    };

const _$VideoAspectEnumMap = {
  VideoAspect.landscape: 'landscape',
  VideoAspect.portrait: 'portrait',
  VideoAspect.square: 'square',
  VideoAspect.classic: 'classic',
  VideoAspect.social: 'social',
};

const _$VideoResolutionEnumMap = {
  VideoResolution.p480: 'p480',
  VideoResolution.p720: 'p720',
  VideoResolution.p1080: 'p1080',
  VideoResolution.p2160: 'p2160',
};
