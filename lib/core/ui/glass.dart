import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:lumora/core/ui/lumora_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Paints a hairline gradient border around a rounded rectangle (or a
/// circle when [circle] is set).
class GradientBorderPainter extends CustomPainter {
  const GradientBorderPainter({required this.colors, this.radius = 24, this.width = 1, this.circle = false});

  final List<Color> colors;
  final double radius;
  final double width;
  final bool circle;

  @override
  void paint(Canvas canvas, Size size) {
    if (colors.isEmpty || size.isEmpty) return;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors.length == 1 ? [colors.first, colors.first] : colors,
      ).createShader(rect);
    final inset = rect.deflate(width / 2);
    if (circle) {
      canvas.drawOval(inset, paint);
    } else {
      canvas.drawRRect(RRect.fromRectAndRadius(inset, Radius.circular(math.max(0, radius - width / 2))), paint);
    }
  }

  @override
  bool shouldRepaint(GradientBorderPainter old) =>
      old.radius != radius || old.width != width || old.circle != circle || !_same(old.colors, colors);

  static bool _same(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// A frosted glass surface: translucent fill, a hairline gradient border,
/// an optional backdrop blur and an optional (subtle) outer glow.
///
/// Keep [blur] for bars and sheets that float over content. In scrolling
/// lists leave it off – the pre-tinted [fill] looks the same over the calm
/// background and costs nothing.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    this.child,
    this.radius = 24,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.blur = false,
    this.fill,
    this.gradient,
    this.borderColors,
    this.borderWidth = 1,
    this.glow = false,
    this.active = false,
    this.circle = false,
    this.clip = true,
  });

  final Widget? child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final bool blur;
  final Color? fill;
  final Gradient? gradient;
  final List<Color>? borderColors;
  final double borderWidth;

  /// Soft outer glow (use only for the active element or main CTA).
  final bool glow;

  /// Uses the brighter "selected" border.
  final bool active;
  final bool circle;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final t = context.lumora;
    final shape = circle ? null : BorderRadius.circular(radius);
    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? (fill ?? t.glassFill) : null,
        gradient: gradient,
        borderRadius: shape,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
      ),
      child: DecoratedBox(
        // Sheen: a faint highlight fading out from the top-left.
        decoration: BoxDecoration(
          borderRadius: shape,
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.center,
            colors: [t.glassHighlight, t.glassHighlight.withValues(alpha: 0)],
          ),
        ),
        child: padding == null ? child : Padding(padding: padding!, child: child),
      ),
    );
    if (blur) {
      content = BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: t.blurSigma, sigmaY: t.blurSigma),
        child: content,
      );
    }
    if (blur || clip) {
      content = circle ? ClipOval(child: content) : ClipRRect(borderRadius: shape!, child: content);
    }
    content = CustomPaint(
      foregroundPainter: GradientBorderPainter(
        colors: borderColors ?? (active ? t.borderActiveColors : t.borderColors),
        radius: radius,
        width: borderWidth,
        circle: circle,
      ),
      child: content,
    );
    if (glow) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: shape,
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          boxShadow: [BoxShadow(color: t.glow, blurRadius: 18, spreadRadius: -2, blurStyle: BlurStyle.outer)],
        ),
        child: content,
      );
    }
    if (width != null || height != null) content = SizedBox(width: width, height: height, child: content);
    if (margin != null) content = Padding(padding: margin!, child: content);
    return content;
  }
}

/// The calm navy page background with a few very faint static glows.
/// Painted once (no animation, no blur), behind a [RepaintBoundary].
class LumoraBackground extends StatelessWidget {
  const LumoraBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.lumora;
    return DecoratedBox(
      decoration: BoxDecoration(color: t.background),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: IgnorePointer(child: CustomPaint(painter: _BlobPainter(t.blobs))),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  const _BlobPainter(this.blobs);
  final List<GlowBlob> blobs;

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = size.shortestSide;
    for (final b in blobs) {
      final center = b.alignment.alongSize(size);
      final r = b.radius * shortest;
      final paint = Paint()..shader = ui.Gradient.radial(center, r, [b.color, b.color.withValues(alpha: 0)]);
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.blobs != blobs;
}

/// Scale-down-on-press feedback (skipped when the OS reduces motion).
class PressScale extends StatefulWidget {
  const PressScale({required this.child, super.key, this.enabled = true, this.scale = 0.96});

  final Widget child;
  final bool enabled;
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || context.reduceMotion) return widget.child;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
