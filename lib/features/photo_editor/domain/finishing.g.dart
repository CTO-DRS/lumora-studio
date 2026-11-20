// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finishing.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FrameSettings _$FrameSettingsFromJson(Map<String, dynamic> json) =>
    _FrameSettings(
      style:
          $enumDecodeNullable(_$FrameStyleEnumMap, json['style']) ??
          FrameStyle.none,
      width: (json['width'] as num?)?.toDouble() ?? 0.04,
      color: (json['color'] as num?)?.toInt() ?? 0xFFFFFFFF,
      fill:
          $enumDecodeNullable(_$FrameFillEnumMap, json['fill']) ??
          FrameFill.color,
      cornerRadius: (json['cornerRadius'] as num?)?.toDouble() ?? 0,
      aspect: (json['aspect'] as num?)?.toDouble() ?? 1,
    );

Map<String, dynamic> _$FrameSettingsToJson(_FrameSettings instance) =>
    <String, dynamic>{
      'style': _$FrameStyleEnumMap[instance.style]!,
      'width': instance.width,
      'color': instance.color,
      'fill': _$FrameFillEnumMap[instance.fill]!,
      'cornerRadius': instance.cornerRadius,
      'aspect': instance.aspect,
    };

const _$FrameStyleEnumMap = {
  FrameStyle.none: 'none',
  FrameStyle.border: 'border',
  FrameStyle.polaroid: 'polaroid',
  FrameStyle.fitAspect: 'fitAspect',
};

const _$FrameFillEnumMap = {FrameFill.color: 'color', FrameFill.blur: 'blur'};

_WatermarkSettings _$WatermarkSettingsFromJson(Map<String, dynamic> json) =>
    _WatermarkSettings(
      text: json['text'] as String? ?? '',
      logoPath: json['logoPath'] as String?,
      anchor:
          $enumDecodeNullable(_$WatermarkAnchorEnumMap, json['anchor']) ??
          WatermarkAnchor.bottomRight,
      size: (json['size'] as num?)?.toDouble() ?? 0.045,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 0.75,
      color: (json['color'] as num?)?.toInt() ?? 0xFFFFFFFF,
      margin: (json['margin'] as num?)?.toDouble() ?? 0.03,
      shadow: json['shadow'] as bool? ?? true,
    );

Map<String, dynamic> _$WatermarkSettingsToJson(_WatermarkSettings instance) =>
    <String, dynamic>{
      'text': instance.text,
      'logoPath': instance.logoPath,
      'anchor': _$WatermarkAnchorEnumMap[instance.anchor]!,
      'size': instance.size,
      'opacity': instance.opacity,
      'color': instance.color,
      'margin': instance.margin,
      'shadow': instance.shadow,
    };

const _$WatermarkAnchorEnumMap = {
  WatermarkAnchor.topLeft: 'topLeft',
  WatermarkAnchor.topCenter: 'topCenter',
  WatermarkAnchor.topRight: 'topRight',
  WatermarkAnchor.centerLeft: 'centerLeft',
  WatermarkAnchor.center: 'center',
  WatermarkAnchor.centerRight: 'centerRight',
  WatermarkAnchor.bottomLeft: 'bottomLeft',
  WatermarkAnchor.bottomCenter: 'bottomCenter',
  WatermarkAnchor.bottomRight: 'bottomRight',
};
