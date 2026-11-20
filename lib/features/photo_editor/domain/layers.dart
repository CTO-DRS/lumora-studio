import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:lumora/features/photo_editor/domain/adjustments.dart';

part 'layers.freezed.dart';
part 'layers.g.dart';

/// A free-hand stroke. Points are stored flattened (x0, y0, x1, y1, …) in
/// coordinates normalized to the output (cropped) image.
@freezed
abstract class Stroke with _$Stroke {
  const factory Stroke({
    required List<double> points,
    @Default(0xFFFFFFFF) int color,

    /// Width relative to the shorter image side.
    @Default(0.01) double width,
    @Default(1) double opacity,
    @Default(false) bool eraser,

    /// Softness 0..1, used by mask brushes.
    @Default(0) double softness,
  }) = _Stroke;

  factory Stroke.fromJson(Map<String, dynamic> json) => _$StrokeFromJson(json);
}

enum TextAlignment { start, center, end }

/// Overlay layers composited on top of the developed photo.
@Freezed(unionKey: 'type')
sealed class OverlayLayer with _$OverlayLayer {
  const factory OverlayLayer.text({
    required String id,
    required String text,
    @Default(0.5) double x,
    @Default(0.5) double y,
    @Default(1) double scale,
    @Default(0) double rotation,
    @Default(1) double opacity,
    @Default(0xFFFFFFFF) int color,
    int? backgroundColor,

    /// Font size relative to the shorter image side.
    @Default(0.07) double fontSize,
    @Default(false) bool bold,
    @Default(false) bool italic,
    @Default(TextAlignment.center) TextAlignment align,
    @Default(true) bool shadow,
    String? fontFamily,
  }) = TextLayer;

  const factory OverlayLayer.sticker({
    required String id,

    /// Emoji / glyph sticker. Ignored when [imagePath] is set.
    @Default('✨') String glyph,
    String? imagePath,
    @Default(0.5) double x,
    @Default(0.5) double y,
    @Default(1) double scale,
    @Default(0) double rotation,
    @Default(1) double opacity,

    /// Size relative to the shorter image side.
    @Default(0.2) double size,
  }) = StickerLayer;

  const factory OverlayLayer.drawing({
    required String id,
    @Default(<Stroke>[]) List<Stroke> strokes,
    @Default(1) double opacity,
  }) = DrawingLayer;

  factory OverlayLayer.fromJson(Map<String, dynamic> json) => _$OverlayLayerFromJson(json);
}

enum MaskKind { brush, linear, radial, subject }

/// A masked local adjustment (brush, linear gradient, radial gradient or an
/// AI generated subject mask).
@freezed
abstract class LocalAdjustment with _$LocalAdjustment {
  const factory LocalAdjustment({
    required String id,
    required MaskKind kind,
    @Default(Adjustments()) Adjustments adjustments,

    /// linear: x0, y0, x1, y1 – radial: cx, cy, rx, ry (normalized).
    @Default([0.5, 0.3, 0.5, 0.7]) List<double> geometry,
    @Default(0) double rotation,
    @Default(0.35) double feather,
    @Default(false) bool invert,
    @Default(1) double amount,
    @Default(<Stroke>[]) List<Stroke> strokes,

    /// Grayscale mask PNG for [MaskKind.subject].
    String? maskPath,
    @Default(true) bool enabled,
  }) = _LocalAdjustment;

  factory LocalAdjustment.fromJson(Map<String, dynamic> json) => _$LocalAdjustmentFromJson(json);
}
