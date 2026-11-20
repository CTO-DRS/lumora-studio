// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'edit_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EditState _$EditStateFromJson(Map<String, dynamic> json) => _EditState(
  adjustments: json['adjustments'] == null
      ? const Adjustments()
      : Adjustments.fromJson(json['adjustments'] as Map<String, dynamic>),
  geometry: json['geometry'] == null
      ? const GeometryState()
      : GeometryState.fromJson(json['geometry'] as Map<String, dynamic>),
  layers:
      (json['layers'] as List<dynamic>?)
          ?.map((e) => OverlayLayer.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <OverlayLayer>[],
  localAdjustments:
      (json['localAdjustments'] as List<dynamic>?)
          ?.map((e) => LocalAdjustment.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <LocalAdjustment>[],
  presetId: json['presetId'] as String?,
  presetIntensity: (json['presetIntensity'] as num?)?.toDouble() ?? 1,
  rasterPath: json['rasterPath'] as String?,
);

Map<String, dynamic> _$EditStateToJson(
  _EditState instance,
) => <String, dynamic>{
  'adjustments': instance.adjustments.toJson(),
  'geometry': instance.geometry.toJson(),
  'layers': instance.layers.map((e) => e.toJson()).toList(),
  'localAdjustments': instance.localAdjustments.map((e) => e.toJson()).toList(),
  'presetId': instance.presetId,
  'presetIntensity': instance.presetIntensity,
  'rasterPath': instance.rasterPath,
};
