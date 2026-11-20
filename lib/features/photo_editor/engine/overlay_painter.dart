import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:lumora/features/photo_editor/domain/layers.dart';
import 'package:material_ui/material_ui.dart';

/// Paints overlay layers (text, stickers, drawings) in output-image space.
/// Used both by the GPU preview and the full resolution exporter, so the
/// export is pixel-identical to what the user sees.
class OverlayPainter {
  const OverlayPainter({this.stickerImages = const {}});

  /// Decoded image stickers keyed by path.
  final Map<String, ui.Image> stickerImages;

  /// Paints [layers] for an output of [fullSize]. When rendering a tile,
  /// [tileOffset] is the tile's top-left corner in output pixels.
  void paint(Canvas canvas, Size fullSize, List<OverlayLayer> layers, {Offset tileOffset = Offset.zero}) {
    canvas.save();
    canvas.translate(-tileOffset.dx, -tileOffset.dy);
    final minDim = math.min(fullSize.width, fullSize.height);
    for (final layer in layers) {
      switch (layer) {
        case TextLayer():
          _paintText(canvas, fullSize, minDim, layer);
        case StickerLayer():
          _paintSticker(canvas, fullSize, minDim, layer);
        case DrawingLayer():
          paintStrokes(canvas, fullSize, layer.strokes, opacity: layer.opacity);
      }
    }
    canvas.restore();
  }

  static TextPainter buildTextPainter(TextLayer l, double minDim) {
    final shadow = l.shadow
        ? [
            Shadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: minDim * 0.01,
              offset: Offset(0, minDim * 0.004),
            ),
          ]
        : null;
    final style = TextStyle(
      color: Color(l.color).withValues(alpha: Color(l.color).a * l.opacity),
      fontSize: l.fontSize * minDim * l.scale,
      fontWeight: l.bold ? FontWeight.w700 : FontWeight.w400,
      fontStyle: l.italic ? FontStyle.italic : FontStyle.normal,
      fontFamily: l.fontFamily,
      shadows: shadow,
      height: 1.15,
    );
    final align = switch (l.align) {
      TextAlignment.start => TextAlign.start,
      TextAlignment.center => TextAlign.center,
      TextAlignment.end => TextAlign.end,
    };
    return TextPainter(
      text: TextSpan(text: l.text, style: style),
      textAlign: align,
      textDirection: _isRtl(l.text) ? TextDirection.rtl : TextDirection.ltr,
    )..layout();
  }

  static bool _isRtl(String s) => RegExp(r'[\u0590-\u08FF\uFB1D-\uFEFC]').hasMatch(s);

  void _paintText(Canvas canvas, Size size, double minDim, TextLayer l) {
    final tp = buildTextPainter(l, minDim);
    canvas.save();
    canvas.translate(l.x * size.width, l.y * size.height);
    canvas.rotate(l.rotation);
    final topLeft = Offset(-tp.width / 2, -tp.height / 2);
    if (l.backgroundColor != null) {
      final pad = minDim * 0.015 * l.scale;
      final r = RRect.fromRectAndRadius((topLeft & tp.size).inflate(pad), Radius.circular(pad * 1.5));
      canvas.drawRRect(r, Paint()..color = Color(l.backgroundColor!).withValues(alpha: l.opacity));
    }
    tp.paint(canvas, topLeft);
    canvas.restore();
  }

  void _paintSticker(Canvas canvas, Size size, double minDim, StickerLayer l) {
    final side = l.size * minDim * l.scale;
    canvas.save();
    canvas.translate(l.x * size.width, l.y * size.height);
    canvas.rotate(l.rotation);
    final img = l.imagePath == null ? null : stickerImages[l.imagePath];
    if (img != null) {
      final aspect = img.width / img.height;
      final w = aspect >= 1 ? side : side * aspect;
      final h = aspect >= 1 ? side / aspect : side;
      paintImage(
        canvas: canvas,
        rect: Rect.fromCenter(center: Offset.zero, width: w, height: h),
        image: img,
        opacity: l.opacity,
        filterQuality: FilterQuality.high,
      );
    } else {
      final tp = TextPainter(
        text: TextSpan(
          text: l.glyph,
          style: TextStyle(
            fontSize: side,
            color: Colors.white.withValues(alpha: l.opacity),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    }
    canvas.restore();
  }

  /// Paints free-hand strokes. Eraser strokes clear what was drawn below
  /// them within the same layer.
  static void paintStrokes(Canvas canvas, Size size, List<Stroke> strokes, {double opacity = 1, bool asMask = false}) {
    if (strokes.isEmpty) return;
    final minDim = math.min(size.width, size.height);
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final s in strokes) {
      final pts = s.points;
      if (pts.length < 2) continue;
      final width = s.width * minDim;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = width
        ..isAntiAlias = true;
      if (s.eraser) {
        paint.blendMode = asMask ? BlendMode.srcOver : BlendMode.clear;
        paint.color = asMask ? Colors.black : Colors.transparent;
      } else {
        paint.color = asMask
            ? Colors.white.withValues(alpha: s.opacity)
            : Color(s.color).withValues(alpha: s.opacity * opacity);
      }
      if (s.softness > 0) {
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, width * s.softness);
      }
      final path = Path()..moveTo(pts[0] * size.width, pts[1] * size.height);
      if (pts.length == 2) {
        path.lineTo(pts[0] * size.width + 0.01, pts[1] * size.height);
      }
      for (var i = 2; i + 1 < pts.length; i += 2) {
        // Quadratic smoothing between successive midpoints.
        final x = pts[i] * size.width;
        final y = pts[i + 1] * size.height;
        if (i + 3 < pts.length) {
          final nx = pts[i + 2] * size.width;
          final ny = pts[i + 3] * size.height;
          path.quadraticBezierTo(x, y, (x + nx) / 2, (y + ny) / 2);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }
}
