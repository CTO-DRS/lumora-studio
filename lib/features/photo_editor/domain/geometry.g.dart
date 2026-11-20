// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'geometry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GeometryState _$GeometryStateFromJson(Map<String, dynamic> json) =>
    _GeometryState(
      cropLeft: (json['cropLeft'] as num?)?.toDouble() ?? 0,
      cropTop: (json['cropTop'] as num?)?.toDouble() ?? 0,
      cropRight: (json['cropRight'] as num?)?.toDouble() ?? 1,
      cropBottom: (json['cropBottom'] as num?)?.toDouble() ?? 1,
      quarterTurns: (json['quarterTurns'] as num?)?.toInt() ?? 0,
      straightenDegrees: (json['straightenDegrees'] as num?)?.toDouble() ?? 0,
      flipHorizontal: json['flipHorizontal'] as bool? ?? false,
      flipVertical: json['flipVertical'] as bool? ?? false,
      perspectiveVertical:
          (json['perspectiveVertical'] as num?)?.toDouble() ?? 0,
      perspectiveHorizontal:
          (json['perspectiveHorizontal'] as num?)?.toDouble() ?? 0,
      aspectRatio: (json['aspectRatio'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$GeometryStateToJson(_GeometryState instance) =>
    <String, dynamic>{
      'cropLeft': instance.cropLeft,
      'cropTop': instance.cropTop,
      'cropRight': instance.cropRight,
      'cropBottom': instance.cropBottom,
      'quarterTurns': instance.quarterTurns,
      'straightenDegrees': instance.straightenDegrees,
      'flipHorizontal': instance.flipHorizontal,
      'flipVertical': instance.flipVertical,
      'perspectiveVertical': instance.perspectiveVertical,
      'perspectiveHorizontal': instance.perspectiveHorizontal,
      'aspectRatio': instance.aspectRatio,
    };
