import 'package:material_ui/material_ui.dart';

/// Thin rounded track: a muted inactive part and a gradient active part.
///
/// With [origin] (0..1 along the track, from the start edge) the active part
/// runs from the origin to the thumb – used for bipolar sliders such as
/// exposure, where the neutral value sits in the middle.
class GlowSliderTrackShape extends SliderTrackShape with BaseSliderTrackShape {
  const GlowSliderTrackShape({required this.colors, required this.inactive, this.origin});

  final List<Color> colors;
  final Color inactive;
  final double? origin;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final rect = getPreferredRect(parentBox: parentBox, offset: offset, sliderTheme: sliderTheme);
    if (rect.width <= 0) return;
    final canvas = context.canvas;
    final h = rect.height;
    final radius = Radius.circular(h / 2);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), Paint()..color = inactive);

    final rtl = textDirection == TextDirection.rtl;
    double atFraction(double f) => rtl ? rect.right - f * rect.width : rect.left + f * rect.width;
    final start = origin == null ? (rtl ? rect.right : rect.left) : atFraction(origin!);
    final left = start < thumbCenter.dx ? start : thumbCenter.dx;
    final right = start < thumbCenter.dx ? thumbCenter.dx : start;
    final active = Rect.fromLTRB(left, rect.top - 0.5, right, rect.bottom + 0.5);
    final opacity = isEnabled ? 1.0 : 0.4;
    if (active.width > 0.5) {
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [for (final c in colors) c.withValues(alpha: c.a * opacity)],
        ).createShader(rtl ? Rect.fromLTRB(rect.left, rect.top, rect.right, rect.bottom) : rect);
      canvas.drawRRect(RRect.fromRectAndRadius(active, radius), paint);
    }
    if (origin != null) {
      // Tick at the neutral value.
      final x = atFraction(origin!);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, rect.center.dy), width: 2, height: h + 6), radius),
        Paint()..color = inactive.withValues(alpha: (inactive.a * 2.4).clamp(0, 1)),
      );
    }
  }
}

/// Gradient orb thumb with a light rim and a soft glow while dragged.
class GlowSliderThumbShape extends SliderComponentShape {
  const GlowSliderThumbShape({required this.colors, required this.glow, this.radius = 10});

  final List<Color> colors;
  final Color glow;
  final double radius;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size.fromRadius(radius + 2);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final r = radius + activationAnimation.value * 2;
    final enabled = enableAnimation.value > 0.5;
    canvas.drawCircle(
      center,
      r + 4,
      Paint()
        ..color = glow.withValues(alpha: glow.a * (0.45 + 0.55 * activationAnimation.value))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    final rect = Rect.fromCircle(center: center, radius: r);
    canvas
      ..drawCircle(
        center,
        r,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: enabled ? colors : [const Color(0xFF8A8FA8), const Color(0xFF6A6F88)],
          ).createShader(rect),
      )
      ..drawCircle(
        center,
        r - 0.75,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xCCFFFFFF),
      );
  }
}
