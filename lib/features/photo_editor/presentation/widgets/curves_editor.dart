import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/photo_editor/engine/curves/tone_curve.dart';
import 'package:material_ui/material_ui.dart';

/// Interactive tone curve: tap to add a point, drag to move it, double tap
/// a point to remove it.
class CurvesEditor extends StatefulWidget {
  const CurvesEditor({
    required this.points,
    required this.color,
    required this.onChanged,
    required this.onChangeEnd,
    super.key,
  });

  final List<CurvePoint> points;
  final Color color;
  final void Function(List<CurvePoint>) onChanged;
  final VoidCallback onChangeEnd;

  @override
  State<CurvesEditor> createState() => _CurvesEditorState();
}

class _CurvesEditorState extends State<CurvesEditor> {
  int? _drag;

  /// Local copy so a drag that starts by inserting a point keeps working
  /// before the parent rebuilds with the new list.
  late List<CurvePoint> _points = widget.points;

  @override
  void didUpdateWidget(CurvesEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_drag == null) _points = widget.points;
  }

  void _emit(List<CurvePoint> pts) {
    _points = pts;
    widget.onChanged(pts);
  }

  int? _nearest(Offset p, Size s) {
    for (var i = 0; i < _points.length; i++) {
      final c = Offset(_points[i].x * s.width, (1 - _points[i].y) * s.height);
      if ((c - p).distance < 24) return i;
    }
    return null;
  }

  CurvePoint _toPoint(Offset p, Size s) => CurvePoint((p.dx / s.width).clamp(0, 1), (1 - p.dy / s.height).clamp(0, 1));

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.6,
      child: LayoutBuilder(
        builder: (context, c) {
          final size = c.biggest;
          return GestureDetector(
            onDoubleTapDown: (d) {
              final i = _nearest(d.localPosition, size);
              if (i != null && i != 0 && i != _points.length - 1) {
                _emit([..._points]..removeAt(i));
                widget.onChangeEnd();
              }
            },
            onPanStart: (d) {
              var i = _nearest(d.localPosition, size);
              if (i == null) {
                final pts = [..._points, _toPoint(d.localPosition, size)]..sort((a, b) => a.x.compareTo(b.x));
                _emit(pts);
                i = pts.indexWhere((p) => p == _toPoint(d.localPosition, size));
              }
              _drag = i;
            },
            onPanUpdate: (d) {
              final i = _drag;
              if (i == null || i < 0) return;
              final pts = [..._points];
              var np = _toPoint(d.localPosition, size);
              // Keep end points pinned horizontally, inner points ordered.
              if (i == 0) np = CurvePoint(0, np.y);
              if (i == pts.length - 1) np = CurvePoint(1, np.y);
              if (i > 0 && i < pts.length - 1) {
                np = CurvePoint(np.x.clamp(pts[i - 1].x + 0.01, pts[i + 1].x - 0.01), np.y);
              }
              pts[i] = np;
              _emit(pts);
            },
            onPanEnd: (_) {
              _drag = null;
              widget.onChangeEnd();
            },
            child: CustomPaint(painter: _CurvePainter(_points, widget.color)),
          );
        },
      ),
    );
  }
}

class _CurvePainter extends CustomPainter {
  _CurvePainter(this.points, this.color);
  final List<CurvePoint> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0x22FFFFFF)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final x = size.width * i / 4;
      final y = size.height * i / 4;
      canvas
        ..drawLine(Offset(x, 0), Offset(x, size.height), grid)
        ..drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    canvas.drawLine(Offset(0, size.height), Offset(size.width, 0), grid);
    final curve = ToneCurve(points);
    final path = Path();
    for (var i = 0; i <= 100; i++) {
      final x = i / 100;
      final p = Offset(x * size.width, (1 - curve.evaluate(x)) * size.height);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color,
    );
    for (final p in points) {
      canvas.drawCircle(Offset(p.x * size.width, (1 - p.y) * size.height), 6, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_CurvePainter old) => old.points != points || old.color != color;
}
