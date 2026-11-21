import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumora/features/photo_editor/domain/geometry.dart';
import 'package:lumora/features/photo_editor/presentation/photo_editor_controller.dart';
import 'package:material_ui/material_ui.dart';

enum _Handle { tl, tr, bl, br, move }

/// Interactive crop rectangle drawn over the uncropped (but rotated and
/// straightened) frame. Values are normalized to that frame.
class CropOverlay extends ConsumerStatefulWidget {
  const CropOverlay({super.key});

  @override
  ConsumerState<CropOverlay> createState() => _CropOverlayState();
}

class _CropOverlayState extends ConsumerState<CropOverlay> {
  _Handle? _active;

  @override
  Widget build(BuildContext context) {
    final g = ref.watch(photoEditorControllerProvider.select((s) => s.edit.geometry));
    final ctrl = ref.read(photoEditorControllerProvider.notifier);
    return LayoutBuilder(
      builder: (context, c) {
        final size = c.biggest;
        final rect = Rect.fromLTRB(
          g.cropLeft * size.width,
          g.cropTop * size.height,
          g.cropRight * size.width,
          g.cropBottom * size.height,
        );
        return GestureDetector(
          onPanStart: (d) => _active = _hit(d.localPosition, rect),
          onPanUpdate: (d) {
            final h = _active;
            if (h == null) return;
            final dx = d.delta.dx / size.width;
            final dy = d.delta.dy / size.height;
            ctrl.update((s) => s.copyWith(geometry: _drag(s.geometry, h, dx, dy, size)), live: true);
          },
          onPanEnd: (_) {
            _active = null;
            ctrl.commit();
          },
          child: CustomPaint(size: size, painter: _CropPainter(rect)),
        );
      },
    );
  }

  _Handle? _hit(Offset p, Rect r) {
    const t = 36.0;
    if ((p - r.topLeft).distance < t) return _Handle.tl;
    if ((p - r.topRight).distance < t) return _Handle.tr;
    if ((p - r.bottomLeft).distance < t) return _Handle.bl;
    if ((p - r.bottomRight).distance < t) return _Handle.br;
    if (r.contains(p)) return _Handle.move;
    return null;
  }

  GeometryState _drag(GeometryState g, _Handle h, double dx, double dy, Size size) {
    var l = g.cropLeft;
    var t = g.cropTop;
    var r = g.cropRight;
    var b = g.cropBottom;
    const minSide = 0.05;
    switch (h) {
      case _Handle.move:
        final w = r - l;
        final hh = b - t;
        l = (l + dx).clamp(0, 1 - w);
        t = (t + dy).clamp(0, 1 - hh);
        r = l + w;
        b = t + hh;
      case _Handle.tl:
        l = (l + dx).clamp(0, r - minSide);
        t = (t + dy).clamp(0, b - minSide);
      case _Handle.tr:
        r = (r + dx).clamp(l + minSide, 1);
        t = (t + dy).clamp(0, b - minSide);
      case _Handle.bl:
        l = (l + dx).clamp(0, r - minSide);
        b = (b + dy).clamp(t + minSide, 1);
      case _Handle.br:
        r = (r + dx).clamp(l + minSide, 1);
        b = (b + dy).clamp(t + minSide, 1);
    }
    final aspect = g.aspectRatio;
    if (aspect != null && h != _Handle.move) {
      // Keep the requested aspect (in pixels) by adjusting the height.
      final wPx = (r - l) * size.width;
      final hNorm = (wPx / aspect) / size.height;
      if (h == _Handle.tl || h == _Handle.tr) {
        t = (b - hNorm).clamp(0, b - minSide);
      } else {
        b = (t + hNorm).clamp(t + minSide, 1);
      }
    }
    return g.copyWith(cropLeft: l, cropTop: t, cropRight: r, cropBottom: b);
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.rect);
  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
    final shade = Paint()..color = const Color(0x99000000);
    final outer = Path()..addRect(Offset.zero & size);
    final inner = Path()..addRect(rect);
    canvas.drawPath(Path.combine(PathOperation.difference, outer, inner), shade);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xCCFFFFFF);
    canvas.drawRect(rect, line..strokeWidth = 1.5);
    // Rule of thirds.
    for (var i = 1; i < 3; i++) {
      final x = rect.left + rect.width * i / 3;
      final y = rect.top + rect.height * i / 3;
      canvas
        ..drawLine(Offset(x, rect.top), Offset(x, rect.bottom), line..strokeWidth = 0.6)
        ..drawLine(Offset(rect.left, y), Offset(rect.right, y), line);
    }
    final handle = Paint()
      ..color = const Color(0xFFB4A9FF)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const k = 18.0;
    for (final (p, sx, sy) in [
      (rect.topLeft, 1.0, 1.0),
      (rect.topRight, -1.0, 1.0),
      (rect.bottomLeft, 1.0, -1.0),
      (rect.bottomRight, -1.0, -1.0),
    ]) {
      canvas
        ..drawLine(p, p + Offset(k * sx, 0), handle)
        ..drawLine(p, p + Offset(0, k * sy), handle);
    }
  }

  @override
  bool shouldRepaint(_CropPainter old) => old.rect != rect;
}
