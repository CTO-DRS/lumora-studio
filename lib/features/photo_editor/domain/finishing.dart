import 'dart:math' as math;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'finishing.freezed.dart';
part 'finishing.g.dart';

/// How the photo is framed after every other edit.
enum FrameStyle {
  none,

  /// Even border on every side.
  border,

  /// Instant-film look: thin sides, deep bottom edge.
  polaroid,

  /// Pads the photo (no cropping) to a target aspect ratio, e.g. 1:1 or 4:5
  /// for Instagram, filling the empty space with a colour or a blur.
  fitAspect,
}

/// What fills the frame area.
enum FrameFill { color, blur }

/// Frame / border settings. Sizes are relative to the shorter side of the
/// photo so the result is resolution independent (preview == export).
@freezed
abstract class FrameSettings with _$FrameSettings {
  const factory FrameSettings({
    @Default(FrameStyle.none) FrameStyle style,

    /// Border thickness relative to the photo's shorter side.
    @Default(0.04) double width,
    @Default(0xFFFFFFFF) int color,
    @Default(FrameFill.color) FrameFill fill,

    /// Corner radius of the photo inside the frame, relative to its shorter side.
    @Default(0) double cornerRadius,

    /// Target aspect ratio (w / h) for [FrameStyle.fitAspect].
    @Default(1) double aspect,
  }) = _FrameSettings;

  const FrameSettings._();

  factory FrameSettings.fromJson(Map<String, dynamic> json) => _$FrameSettingsFromJson(json);

  bool get isNone => style == FrameStyle.none;
}

/// Result of laying out a frame around a `w`×`h` photo.
class FrameLayout {
  const FrameLayout({required this.width, required this.height, required this.imageRect});

  /// Final canvas size in pixels.
  final int width;
  final int height;

  /// Where the photo goes: left, top, width, height (pixels).
  final ({int left, int top, int width, int height}) imageRect;

  bool get isIdentity => imageRect.left == 0 && imageRect.top == 0 && imageRect.width == width;
}

/// Computes the canvas size and photo placement for [frame] around a photo
/// of [w]×[h] pixels. Pure and shared by the GPU preview and CPU export.
FrameLayout layoutFrame(int w, int h, FrameSettings frame) {
  final short = math.min(w, h);
  switch (frame.style) {
    case FrameStyle.none:
      return FrameLayout(width: w, height: h, imageRect: (left: 0, top: 0, width: w, height: h));
    case FrameStyle.border:
      final b = (frame.width.clamp(0.0, 0.5) * short).round();
      return FrameLayout(width: w + 2 * b, height: h + 2 * b, imageRect: (left: b, top: b, width: w, height: h));
    case FrameStyle.polaroid:
      final side = math.max(1, (frame.width.clamp(0.01, 0.3) * short).round());
      final bottom = side * 4;
      return FrameLayout(
        width: w + 2 * side,
        height: h + side + bottom,
        imageRect: (left: side, top: side, width: w, height: h),
      );
    case FrameStyle.fitAspect:
      final target = frame.aspect <= 0 ? 1.0 : frame.aspect;
      final margin = (frame.width.clamp(0.0, 0.3) * short).round();
      var cw = w + 2 * margin;
      var ch = h + 2 * margin;
      if (cw / ch > target) {
        ch = (cw / target).round();
      } else {
        cw = (ch * target).round();
      }
      return FrameLayout(
        width: cw,
        height: ch,
        imageRect: (left: (cw - w) ~/ 2, top: (ch - h) ~/ 2, width: w, height: h),
      );
  }
}

/// Nine anchor positions for a watermark.
enum WatermarkAnchor {
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  center,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

/// A text and/or logo watermark painted on the final image.
@freezed
abstract class WatermarkSettings with _$WatermarkSettings {
  const factory WatermarkSettings({
    @Default('') String text,

    /// Optional logo image (PNG with transparency works best).
    String? logoPath,
    @Default(WatermarkAnchor.bottomRight) WatermarkAnchor anchor,

    /// Text size / logo height relative to the shorter side of the image.
    @Default(0.045) double size,
    @Default(0.75) double opacity,
    @Default(0xFFFFFFFF) int color,

    /// Distance from the edges relative to the shorter side.
    @Default(0.03) double margin,
    @Default(true) bool shadow,
  }) = _WatermarkSettings;

  const WatermarkSettings._();

  factory WatermarkSettings.fromJson(Map<String, dynamic> json) => _$WatermarkSettingsFromJson(json);

  bool get isEmpty => text.trim().isEmpty && logoPath == null;
}

/// Top-left corner of a `boxW`×`boxH` watermark anchored in a `w`×`h` image.
(double, double) anchorWatermark(WatermarkAnchor anchor, double w, double h, double boxW, double boxH, double margin) {
  final col = anchor.index % 3;
  final row = anchor.index ~/ 3;
  final x = switch (col) {
    0 => margin,
    1 => (w - boxW) / 2,
    _ => w - margin - boxW,
  };
  final y = switch (row) {
    0 => margin,
    1 => (h - boxH) / 2,
    _ => h - margin - boxH,
  };
  return (x, y);
}
