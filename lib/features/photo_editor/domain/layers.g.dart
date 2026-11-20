// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'layers.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Stroke _$StrokeFromJson(Map<String, dynamic> json) => _Stroke(
  points: (json['points'] as List<dynamic>)
      .map((e) => (e as num).toDouble())
      .toList(),
  color: (json['color'] as num?)?.toInt() ?? 0xFFFFFFFF,
  width: (json['width'] as num?)?.toDouble() ?? 0.01,
  opacity: (json['opacity'] as num?)?.toDouble() ?? 1,
  eraser: json['eraser'] as bool? ?? false,
  softness: (json['softness'] as num?)?.toDouble() ?? 0,
);

Map<String, dynamic> _$StrokeToJson(_Stroke instance) => <String, dynamic>{
  'points': instance.points,
  'color': instance.color,
  'width': instance.width,
  'opacity': instance.opacity,
  'eraser': instance.eraser,
  'softness': instance.softness,
};

TextLayer _$TextLayerFromJson(Map<String, dynamic> json) => TextLayer(
  id: json['id'] as String,
  text: json['text'] as String,
  x: (json['x'] as num?)?.toDouble() ?? 0.5,
  y: (json['y'] as num?)?.toDouble() ?? 0.5,
  scale: (json['scale'] as num?)?.toDouble() ?? 1,
  rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
  opacity: (json['opacity'] as num?)?.toDouble() ?? 1,
  color: (json['color'] as num?)?.toInt() ?? 0xFFFFFFFF,
  backgroundColor: (json['backgroundColor'] as num?)?.toInt(),
  fontSize: (json['fontSize'] as num?)?.toDouble() ?? 0.07,
  bold: json['bold'] as bool? ?? false,
  italic: json['italic'] as bool? ?? false,
  align:
      $enumDecodeNullable(_$TextAlignmentEnumMap, json['align']) ??
      TextAlignment.center,
  shadow: json['shadow'] as bool? ?? true,
  fontFamily: json['fontFamily'] as String?,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$TextLayerToJson(TextLayer instance) => <String, dynamic>{
  'id': instance.id,
  'text': instance.text,
  'x': instance.x,
  'y': instance.y,
  'scale': instance.scale,
  'rotation': instance.rotation,
  'opacity': instance.opacity,
  'color': instance.color,
  'backgroundColor': instance.backgroundColor,
  'fontSize': instance.fontSize,
  'bold': instance.bold,
  'italic': instance.italic,
  'align': _$TextAlignmentEnumMap[instance.align]!,
  'shadow': instance.shadow,
  'fontFamily': instance.fontFamily,
  'type': instance.$type,
};

const _$TextAlignmentEnumMap = {
  TextAlignment.start: 'start',
  TextAlignment.center: 'center',
  TextAlignment.end: 'end',
};

StickerLayer _$StickerLayerFromJson(Map<String, dynamic> json) => StickerLayer(
  id: json['id'] as String,
  glyph: json['glyph'] as String? ?? '✨',
  imagePath: json['imagePath'] as String?,
  x: (json['x'] as num?)?.toDouble() ?? 0.5,
  y: (json['y'] as num?)?.toDouble() ?? 0.5,
  scale: (json['scale'] as num?)?.toDouble() ?? 1,
  rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
  opacity: (json['opacity'] as num?)?.toDouble() ?? 1,
  size: (json['size'] as num?)?.toDouble() ?? 0.2,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$StickerLayerToJson(StickerLayer instance) =>
    <String, dynamic>{
      'id': instance.id,
      'glyph': instance.glyph,
      'imagePath': instance.imagePath,
      'x': instance.x,
      'y': instance.y,
      'scale': instance.scale,
      'rotation': instance.rotation,
      'opacity': instance.opacity,
      'size': instance.size,
      'type': instance.$type,
    };

DrawingLayer _$DrawingLayerFromJson(Map<String, dynamic> json) => DrawingLayer(
  id: json['id'] as String,
  strokes:
      (json['strokes'] as List<dynamic>?)
          ?.map((e) => Stroke.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Stroke>[],
  opacity: (json['opacity'] as num?)?.toDouble() ?? 1,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$DrawingLayerToJson(DrawingLayer instance) =>
    <String, dynamic>{
      'id': instance.id,
      'strokes': instance.strokes.map((e) => e.toJson()).toList(),
      'opacity': instance.opacity,
      'type': instance.$type,
    };

_LocalAdjustment _$LocalAdjustmentFromJson(Map<String, dynamic> json) =>
    _LocalAdjustment(
      id: json['id'] as String,
      kind: $enumDecode(_$MaskKindEnumMap, json['kind']),
      adjustments: json['adjustments'] == null
          ? const Adjustments()
          : Adjustments.fromJson(json['adjustments'] as Map<String, dynamic>),
      geometry:
          (json['geometry'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [0.5, 0.3, 0.5, 0.7],
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      feather: (json['feather'] as num?)?.toDouble() ?? 0.35,
      invert: json['invert'] as bool? ?? false,
      amount: (json['amount'] as num?)?.toDouble() ?? 1,
      strokes:
          (json['strokes'] as List<dynamic>?)
              ?.map((e) => Stroke.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <Stroke>[],
      maskPath: json['maskPath'] as String?,
      enabled: json['enabled'] as bool? ?? true,
    );

Map<String, dynamic> _$LocalAdjustmentToJson(_LocalAdjustment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'kind': _$MaskKindEnumMap[instance.kind]!,
      'adjustments': instance.adjustments.toJson(),
      'geometry': instance.geometry,
      'rotation': instance.rotation,
      'feather': instance.feather,
      'invert': instance.invert,
      'amount': instance.amount,
      'strokes': instance.strokes.map((e) => e.toJson()).toList(),
      'maskPath': instance.maskPath,
      'enabled': instance.enabled,
    };

const _$MaskKindEnumMap = {
  MaskKind.brush: 'brush',
  MaskKind.linear: 'linear',
  MaskKind.radial: 'radial',
  MaskKind.subject: 'subject',
};
