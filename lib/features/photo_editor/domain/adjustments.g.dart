// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'adjustments.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CurvePoint _$CurvePointFromJson(Map<String, dynamic> json) =>
    _CurvePoint((json['x'] as num).toDouble(), (json['y'] as num).toDouble());

Map<String, dynamic> _$CurvePointToJson(_CurvePoint instance) =>
    <String, dynamic>{'x': instance.x, 'y': instance.y};

_CurveSet _$CurveSetFromJson(Map<String, dynamic> json) => _CurveSet(
  master:
      (json['master'] as List<dynamic>?)
          ?.map((e) => CurvePoint.fromJson(e as Map<String, dynamic>))
          .toList() ??
      kIdentityCurve,
  red:
      (json['red'] as List<dynamic>?)
          ?.map((e) => CurvePoint.fromJson(e as Map<String, dynamic>))
          .toList() ??
      kIdentityCurve,
  green:
      (json['green'] as List<dynamic>?)
          ?.map((e) => CurvePoint.fromJson(e as Map<String, dynamic>))
          .toList() ??
      kIdentityCurve,
  blue:
      (json['blue'] as List<dynamic>?)
          ?.map((e) => CurvePoint.fromJson(e as Map<String, dynamic>))
          .toList() ??
      kIdentityCurve,
);

Map<String, dynamic> _$CurveSetToJson(_CurveSet instance) => <String, dynamic>{
  'master': instance.master.map((e) => e.toJson()).toList(),
  'red': instance.red.map((e) => e.toJson()).toList(),
  'green': instance.green.map((e) => e.toJson()).toList(),
  'blue': instance.blue.map((e) => e.toJson()).toList(),
};

_HslAdjustments _$HslAdjustmentsFromJson(Map<String, dynamic> json) =>
    _HslAdjustments(
      hue:
          (json['hue'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          kZeroBands,
      saturation:
          (json['saturation'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          kZeroBands,
      luminance:
          (json['luminance'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          kZeroBands,
    );

Map<String, dynamic> _$HslAdjustmentsToJson(_HslAdjustments instance) =>
    <String, dynamic>{
      'hue': instance.hue,
      'saturation': instance.saturation,
      'luminance': instance.luminance,
    };

_SplitTone _$SplitToneFromJson(Map<String, dynamic> json) => _SplitTone(
  shadowHue: (json['shadowHue'] as num?)?.toDouble() ?? 0.58,
  shadowSaturation: (json['shadowSaturation'] as num?)?.toDouble() ?? 0,
  highlightHue: (json['highlightHue'] as num?)?.toDouble() ?? 0.08,
  highlightSaturation: (json['highlightSaturation'] as num?)?.toDouble() ?? 0,
  balance: (json['balance'] as num?)?.toDouble() ?? 0,
);

Map<String, dynamic> _$SplitToneToJson(_SplitTone instance) =>
    <String, dynamic>{
      'shadowHue': instance.shadowHue,
      'shadowSaturation': instance.shadowSaturation,
      'highlightHue': instance.highlightHue,
      'highlightSaturation': instance.highlightSaturation,
      'balance': instance.balance,
    };

_Duotone _$DuotoneFromJson(Map<String, dynamic> json) => _Duotone(
  strength: (json['strength'] as num?)?.toDouble() ?? 0,
  shadowColor: (json['shadowColor'] as num?)?.toInt() ?? 0xFF1B1035,
  highlightColor: (json['highlightColor'] as num?)?.toInt() ?? 0xFFFFC46B,
);

Map<String, dynamic> _$DuotoneToJson(_Duotone instance) => <String, dynamic>{
  'strength': instance.strength,
  'shadowColor': instance.shadowColor,
  'highlightColor': instance.highlightColor,
};

_Adjustments _$AdjustmentsFromJson(Map<String, dynamic> json) => _Adjustments(
  exposure: (json['exposure'] as num?)?.toDouble() ?? 0,
  contrast: (json['contrast'] as num?)?.toDouble() ?? 0,
  highlights: (json['highlights'] as num?)?.toDouble() ?? 0,
  shadows: (json['shadows'] as num?)?.toDouble() ?? 0,
  whites: (json['whites'] as num?)?.toDouble() ?? 0,
  blacks: (json['blacks'] as num?)?.toDouble() ?? 0,
  temperature: (json['temperature'] as num?)?.toDouble() ?? 0,
  tint: (json['tint'] as num?)?.toDouble() ?? 0,
  vibrance: (json['vibrance'] as num?)?.toDouble() ?? 0,
  saturation: (json['saturation'] as num?)?.toDouble() ?? 0,
  hsl: json['hsl'] == null
      ? const HslAdjustments()
      : HslAdjustments.fromJson(json['hsl'] as Map<String, dynamic>),
  splitTone: json['splitTone'] == null
      ? const SplitTone()
      : SplitTone.fromJson(json['splitTone'] as Map<String, dynamic>),
  curves: json['curves'] == null
      ? const CurveSet()
      : CurveSet.fromJson(json['curves'] as Map<String, dynamic>),
  fade: (json['fade'] as num?)?.toDouble() ?? 0,
  sharpen: (json['sharpen'] as num?)?.toDouble() ?? 0,
  clarity: (json['clarity'] as num?)?.toDouble() ?? 0,
  structure: (json['structure'] as num?)?.toDouble() ?? 0,
  dehaze: (json['dehaze'] as num?)?.toDouble() ?? 0,
  blur: (json['blur'] as num?)?.toDouble() ?? 0,
  vignette: (json['vignette'] as num?)?.toDouble() ?? 0,
  vignetteMidpoint: (json['vignetteMidpoint'] as num?)?.toDouble() ?? 0.5,
  vignetteRoundness: (json['vignetteRoundness'] as num?)?.toDouble() ?? 0,
  vignetteFeather: (json['vignetteFeather'] as num?)?.toDouble() ?? 0.5,
  grain: (json['grain'] as num?)?.toDouble() ?? 0,
  grainSize: (json['grainSize'] as num?)?.toDouble() ?? 0.5,
  chromaticAberration: (json['chromaticAberration'] as num?)?.toDouble() ?? 0,
  glitch: (json['glitch'] as num?)?.toDouble() ?? 0,
  duotone: json['duotone'] == null
      ? const Duotone()
      : Duotone.fromJson(json['duotone'] as Map<String, dynamic>),
  lutId: json['lutId'] as String?,
  lutIntensity: (json['lutIntensity'] as num?)?.toDouble() ?? 1,
);

Map<String, dynamic> _$AdjustmentsToJson(_Adjustments instance) =>
    <String, dynamic>{
      'exposure': instance.exposure,
      'contrast': instance.contrast,
      'highlights': instance.highlights,
      'shadows': instance.shadows,
      'whites': instance.whites,
      'blacks': instance.blacks,
      'temperature': instance.temperature,
      'tint': instance.tint,
      'vibrance': instance.vibrance,
      'saturation': instance.saturation,
      'hsl': instance.hsl.toJson(),
      'splitTone': instance.splitTone.toJson(),
      'curves': instance.curves.toJson(),
      'fade': instance.fade,
      'sharpen': instance.sharpen,
      'clarity': instance.clarity,
      'structure': instance.structure,
      'dehaze': instance.dehaze,
      'blur': instance.blur,
      'vignette': instance.vignette,
      'vignetteMidpoint': instance.vignetteMidpoint,
      'vignetteRoundness': instance.vignetteRoundness,
      'vignetteFeather': instance.vignetteFeather,
      'grain': instance.grain,
      'grainSize': instance.grainSize,
      'chromaticAberration': instance.chromaticAberration,
      'glitch': instance.glitch,
      'duotone': instance.duotone.toJson(),
      'lutId': instance.lutId,
      'lutIntensity': instance.lutIntensity,
    };
