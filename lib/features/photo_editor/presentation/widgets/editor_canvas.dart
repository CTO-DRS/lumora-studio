import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumora/core/utils/haptics.dart';
import 'package:lumora/core/utils/l10n_ext.dart';
import 'package:lumora/features/photo_editor/domain/layers.dart';
import 'package:lumora/features/photo_editor/engine/overlay_painter.dart';
import 'package:lumora/features/photo_editor/presentation/photo_editor_controller.dart';
import 'package:lumora/features/photo_editor/presentation/widgets/crop_overlay.dart';
import 'package:material_ui/material_ui.dart';

/// The central preview: shows the GPU render, the original while comparing,
/// and the interactive overlay of the active tool.
class EditorCanvas extends ConsumerStatefulWidget {
  const EditorCanvas({super.key});

  @override
  ConsumerState<EditorCanvas> createState() => _EditorCanvasState();
}

class _EditorCanvasState extends ConsumerState<EditorCanvas> {
  final List<double> _livePoints = [];
  double _lastScale = 1;
  double _lastRotation = 0;
  Offset? _dragStart;
  List<double>? _maskGeomAtStart;

  PhotoEditorController get _ctrl => ref.read(photoEditorControllerProvider.notifier);

  final TransformationController _zoom = TransformationController();
  bool _zoomed = false;

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _zoom.value = Matrix4.identity();
    _zoomed = false;
  }

  /// Double tap: fit ↔ 1:1 (one preview pixel per device pixel), centred
  /// on the tap.
  void _toggleZoom(Offset focal, double fitScale, double dpr) {
    if (_zoomed) {
      setState(_resetZoom);
      return;
    }
    final target = math.max<double>(2, 1 / (fitScale * dpr));
    final m = Matrix4.identity()
      ..translateByDouble(-focal.dx * (target - 1), -focal.dy * (target - 1), 0, 1)
      ..scaleByDouble(target, target, 1, 1);
    setState(() {
      _zoom.value = m;
      _zoomed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(photoEditorControllerProvider);
    final image = s.comparing ? s.preview : s.rendered;
    if (image == null) {
      return Center(child: CircularProgressIndicator(semanticsLabel: context.l10n.loading));
    }
    ref.listen(photoEditorControllerProvider.select((s) => s.interactive), (_, interactive) {
      if (interactive && _zoomed) setState(_resetZoom);
    });
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, c) {
        const pad = 16.0;
        final avail = Size(c.maxWidth - pad * 2, c.maxHeight - pad * 2);
        final k = math.min(avail.width / image.width, avail.height / image.height);
        final size = Size(image.width * k, image.height * k);
        final rect = Offset((c.maxWidth - size.width) / 2, (c.maxHeight - size.height) / 2) & size;
        final clip = s.clippingOverlay;
        final picture = Stack(
          children: [
            Positioned.fromRect(
              rect: rect,
              child: DecoratedBox(
                decoration: const BoxDecoration(boxShadow: [BoxShadow(blurRadius: 24, color: Color(0x66000000))]),
                child: Semantics(
                  image: true,
                  label: context.l10n.photoPreview,
                  child: RawImage(
                    image: image,
                    fit: BoxFit.fill,
                    filterQuality: _zoomed ? FilterQuality.none : FilterQuality.medium,
                  ),
                ),
              ),
            ),
            if (clip != null && !s.comparing && s.showClipping && clip.width == image.width)
              Positioned.fromRect(
                rect: rect,
                child: IgnorePointer(
                  child: RawImage(image: clip, fit: BoxFit.fill),
                ),
              ),
            if (!s.comparing) Positioned.fromRect(rect: rect, child: _interaction(s, rect.size)),
          ],
        );
        if (s.interactive) return picture;
        return GestureDetector(
          onDoubleTapDown: (d) => _toggleZoom(d.localPosition, k, dpr),
          onDoubleTap: () {},
          child: InteractiveViewer(
            transformationController: _zoom,
            maxScale: math.max(4, 2 / (k * dpr)),
            onInteractionEnd: (_) => _zoomed = _zoom.value.getMaxScaleOnAxis() > 1.01,
            child: SizedBox(width: c.maxWidth, height: c.maxHeight, child: picture),
          ),
        );
      },
    );
  }

  Widget _interaction(PhotoEditorState s, Size size) {
    if (s.hslPicking) return _hslPicker(size);
    if (s.tool == EditorTool.heal && s.healSettingSource) return _healSourcePicker(s, size);
    final brushTool =
        s.tool == EditorTool.draw ||
        s.eraserMode ||
        s.tool == EditorTool.heal ||
        (s.tool == EditorTool.masks && _selectedMask(s)?.kind == MaskKind.brush);
    if (brushTool) return _brushLayer(s, size);
    switch (s.tool) {
      case EditorTool.crop:
        return const CropOverlay();
      case EditorTool.text:
      case EditorTool.stickers:
        return _layerManipulator(s, size);
      case EditorTool.masks:
        return _maskManipulator(s, size);
      default:
        return const SizedBox.expand();
    }
  }

  LocalAdjustment? _selectedMask(PhotoEditorState s) {
    for (final m in s.edit.localAdjustments) {
      if (m.id == s.selectedMaskId) return m;
    }
    return null;
  }

  // ------------------------------------------------------------- brushing

  Widget _brushLayer(PhotoEditorState s, Size size) {
    final brush = ref.watch(brushControllerProvider);
    Offset norm(Offset p) => Offset(p.dx / size.width, p.dy / size.height);
    Stroke current() => Stroke(
      points: List.of(_livePoints),
      width: brush.size,
      color: s.eraserMode || s.tool == EditorTool.heal ? 0xAAFF3B5C : brush.color,
      eraser: brush.eraser && !s.eraserMode,
      softness: s.tool == EditorTool.masks ? math.max(brush.softness, 0.3) : brush.softness,
    );
    return GestureDetector(
      onPanStart: (d) => setState(() {
        _livePoints
          ..clear()
          ..addAll([norm(d.localPosition).dx, norm(d.localPosition).dy]);
      }),
      onPanUpdate: (d) => setState(() {
        final n = norm(d.localPosition);
        _livePoints.addAll([n.dx, n.dy]);
      }),
      onPanEnd: (_) {
        final stroke = current();
        setState(_livePoints.clear);
        if (s.eraserMode || s.tool == EditorTool.heal) {
          _pendingEraser.add(stroke);
          setState(() {});
        } else if (s.tool == EditorTool.draw) {
          _ctrl.addDrawingStroke(stroke);
        } else {
          final mask = _selectedMask(s);
          if (mask != null) {
            _ctrl.updateMask(mask.id, (m) => m.copyWith(strokes: [...m.strokes, stroke]));
          }
        }
      },
      child: CustomPaint(
        size: size,
        foregroundPainter: s.tool == EditorTool.heal && s.healClone ? _HealSourcePainter(s.healSource) : null,
        painter: _StrokesPainter([
          if (s.eraserMode || s.tool == EditorTool.heal) ..._pendingEraser,
          if (s.tool == EditorTool.masks) ...?_selectedMask(s)?.strokes.map((e) => e.copyWith(color: 0x88FF3B5C)),
          if (_livePoints.isNotEmpty) current(),
        ]),
      ),
    );
  }

  static final List<Stroke> _pendingEraser = [];

  // ------------------------------------------------------ colour picker

  Widget _hslPicker(Size size) {
    Offset norm(Offset p) => Offset((p.dx / size.width).clamp(0, 1), (p.dy / size.height).clamp(0, 1));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) {
        Haptics.selection();
        _ctrl.pickHslBandAt(norm(d.localPosition));
      },
      onVerticalDragStart: (d) => _ctrl.pickHslBandAt(norm(d.localPosition)),
      // Drag up to increase, down to decrease (targeted adjustment).
      onVerticalDragUpdate: (d) => _ctrl.nudgeHsl(-d.delta.dy / 250),
      onVerticalDragEnd: (_) => _ctrl.commit(),
      child: const MouseRegion(cursor: SystemMouseCursors.precise, child: SizedBox.expand()),
    );
  }

  Widget _healSourcePicker(PhotoEditorState s, Size size) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapUp: (d) {
      Haptics.light();
      _ctrl.setHealSource(Offset(d.localPosition.dx / size.width, d.localPosition.dy / size.height));
    },
    child: CustomPaint(size: size, painter: _HealSourcePainter(s.healSource)),
  );

  // -------------------------------------------------------- text/stickers

  OverlayLayer? _selectedLayer(PhotoEditorState s) {
    for (final l in s.edit.layers) {
      if (l.id == s.selectedLayerId) return l;
    }
    return null;
  }

  Widget _layerManipulator(PhotoEditorState s, Size size) {
    final selected = _selectedLayer(s);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: (d) {
        final p = Offset(d.localPosition.dx / size.width, d.localPosition.dy / size.height);
        String? hit;
        for (final l in s.edit.layers.reversed) {
          final (x, y) = switch (l) {
            TextLayer() => (l.x, l.y),
            StickerLayer() => (l.x, l.y),
            DrawingLayer() => (-10.0, -10.0),
          };
          if ((Offset(x, y) - p).distance < 0.12) {
            hit = l.id;
            break;
          }
        }
        _ctrl.selectLayer(hit);
      },
      onScaleStart: (_) {
        _lastScale = 1;
        _lastRotation = 0;
      },
      onScaleUpdate: (d) {
        if (selected == null) return;
        final dx = d.focalPointDelta.dx / size.width;
        final dy = d.focalPointDelta.dy / size.height;
        final ds = d.scale / _lastScale;
        final dr = d.rotation - _lastRotation;
        _lastScale = d.scale;
        _lastRotation = d.rotation;
        _ctrl.updateLayer(
          selected.id,
          (l) => switch (l) {
            TextLayer() => l.copyWith(
              x: (l.x + dx).clamp(0, 1),
              y: (l.y + dy).clamp(0, 1),
              scale: (l.scale * ds).clamp(0.2, 8),
              rotation: l.rotation + dr,
            ),
            StickerLayer() => l.copyWith(
              x: (l.x + dx).clamp(0, 1),
              y: (l.y + dy).clamp(0, 1),
              scale: (l.scale * ds).clamp(0.2, 8),
              rotation: l.rotation + dr,
            ),
            DrawingLayer() => l,
          },
          live: true,
        );
      },
      onScaleEnd: (_) => _ctrl.commit(),
      child: CustomPaint(size: size, painter: _SelectionPainter(selected, size)),
    );
  }

  // ---------------------------------------------------------------- masks

  Widget _maskManipulator(PhotoEditorState s, Size size) {
    final mask = _selectedMask(s);
    if (mask == null || mask.kind == MaskKind.subject) return const SizedBox.expand();
    return GestureDetector(
      onScaleStart: (d) {
        _dragStart = d.localFocalPoint;
        _maskGeomAtStart = List.of(mask.geometry);
        _lastRotation = 0;
      },
      onScaleUpdate: (d) {
        final g0 = _maskGeomAtStart;
        final start = _dragStart;
        if (g0 == null || start == null) return;
        final dx = (d.localFocalPoint.dx - start.dx) / size.width;
        final dy = (d.localFocalPoint.dy - start.dy) / size.height;
        final List<double> g;
        if (mask.kind == MaskKind.radial) {
          g = [g0[0] + dx, g0[1] + dy, (g0[2] * d.scale).clamp(0.02, 2), (g0[3] * d.scale).clamp(0.02, 2)];
        } else {
          // Linear: move both points; pinch spreads the gradient.
          final cx = (g0[0] + g0[2]) / 2 + dx;
          final cy = (g0[1] + g0[3]) / 2 + dy;
          final hx = (g0[2] - g0[0]) / 2 * d.scale;
          final hy = (g0[3] - g0[1]) / 2 * d.scale;
          final c = math.cos(d.rotation);
          final sn = math.sin(d.rotation);
          final rx = hx * c - hy * sn;
          final ry = hx * sn + hy * c;
          g = [cx - rx, cy - ry, cx + rx, cy + ry];
        }
        _ctrl.updateMask(
          mask.id,
          (m) => m.copyWith(
            geometry: g,
            rotation: mask.kind == MaskKind.radial ? mask.rotation + d.rotation - _lastRotation : m.rotation,
          ),
          live: true,
        );
        _lastRotation = d.rotation;
      },
      onScaleEnd: (_) => _ctrl.commit(),
      child: CustomPaint(size: size, painter: _MaskGuidePainter(mask)),
    );
  }
}

/// Exposes and clears the strokes painted in AI eraser mode.
List<Stroke> takePendingEraserStrokes() {
  final out = List<Stroke>.of(_EditorCanvasState._pendingEraser);
  _EditorCanvasState._pendingEraser.clear();
  return out;
}

void clearPendingEraserStrokes() => _EditorCanvasState._pendingEraser.clear();

class _HealSourcePainter extends CustomPainter {
  _HealSourcePainter(this.source);
  final Offset? source;

  @override
  void paint(Canvas canvas, Size size) {
    final s = source;
    if (s == null) return;
    final c = Offset(s.dx * size.width, s.dy * size.height);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF3FC5F0);
    canvas
      ..drawCircle(c, 14, ring)
      ..drawLine(c - const Offset(20, 0), c + const Offset(20, 0), ring)
      ..drawLine(c - const Offset(0, 20), c + const Offset(0, 20), ring);
  }

  @override
  bool shouldRepaint(_HealSourcePainter old) => old.source != source;
}

class _StrokesPainter extends CustomPainter {
  _StrokesPainter(this.strokes);
  final List<Stroke> strokes;

  @override
  void paint(Canvas canvas, Size size) => OverlayPainter.paintStrokes(canvas, size, strokes);

  @override
  bool shouldRepaint(_StrokesPainter old) => true;
}

class _SelectionPainter extends CustomPainter {
  _SelectionPainter(this.layer, this.imageSize);
  final OverlayLayer? layer;
  final Size imageSize;

  @override
  void paint(Canvas canvas, Size size) {
    final l = layer;
    if (l == null || l is DrawingLayer) return;
    final minDim = math.min(size.width, size.height);
    late final Size box;
    late final double x;
    late final double y;
    late final double rot;
    switch (l) {
      case TextLayer():
        final tp = OverlayPainter.buildTextPainter(l, minDim);
        box = tp.size;
        (x, y, rot) = (l.x, l.y, l.rotation);
      case StickerLayer():
        final side = l.size * minDim * l.scale;
        box = Size(side, side);
        (x, y, rot) = (l.x, l.y, l.rotation);
      case DrawingLayer():
        return;
    }
    canvas
      ..save()
      ..translate(x * size.width, y * size.height)
      ..rotate(rot);
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: box.width + 16, height: box.height + 16),
      const Radius.circular(8),
    );
    canvas
      ..drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFFFFB547),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_SelectionPainter old) => true;
}

class _MaskGuidePainter extends CustomPainter {
  _MaskGuidePainter(this.mask);
  final LocalAdjustment mask;

  @override
  void paint(Canvas canvas, Size size) {
    final g = mask.geometry;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFFFB547);
    final dot = Paint()..color = const Color(0xFFFFB547);
    if (mask.kind == MaskKind.radial) {
      final aspect = size.width / size.height;
      canvas
        ..save()
        ..translate(g[0] * size.width, g[1] * size.height)
        ..rotate(-mask.rotation);
      final rx = g[2] * size.width * (aspect >= 1 ? 1 : 1);
      final ry = g[3] * size.height;
      canvas
        ..drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), paint)
        ..drawOval(
          Rect.fromCenter(center: Offset.zero, width: rx * 2 * (1 - mask.feather), height: ry * 2 * (1 - mask.feather)),
          paint..color = const Color(0x88FFB547),
        )
        ..drawCircle(Offset.zero, 6, dot)
        ..restore();
    } else if (mask.kind == MaskKind.linear) {
      final a = Offset(g[0] * size.width, g[1] * size.height);
      final b = Offset(g[2] * size.width, g[3] * size.height);
      final d = b - a;
      final n = Offset(-d.dy, d.dx) / (d.distance == 0 ? 1 : d.distance) * size.longestSide;
      canvas
        ..drawLine(a - n, a + n, paint)
        ..drawLine(b - n, b + n, paint..color = const Color(0x88FFB547))
        ..drawLine(a, b, paint)
        ..drawCircle(a, 6, dot);
    }
  }

  @override
  bool shouldRepaint(_MaskGuidePainter old) => old.mask != mask;
}

/// Helper used by tests and the export sheet to snapshot a [ui.Image].
Future<ui.Image> cloneImage(ui.Image image) async => image.clone();
