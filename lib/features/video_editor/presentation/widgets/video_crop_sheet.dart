import 'dart:io';

import 'package:lumora/core/utils/haptics.dart';
import 'package:lumora/core/utils/l10n_ext.dart';
import 'package:lumora/features/video_editor/domain/crop_math.dart';
import 'package:material_ui/material_ui.dart';

/// Shows [VideoCropSheet] as a bottom sheet and returns the chosen rect
/// (null = cancelled). Swipe-to-dismiss is off: its vertical-drag recogniser
/// beat the crop handles' pan gesture, so dragging a handle moved the sheet
/// instead of the box. Cancel, the scrim and back still close it.
Future<List<double>?> showVideoCropSheet(
  BuildContext context, {
  required List<double> initial,
  required double frameAspect,
  String? framePath,
}) => showModalBottomSheet<List<double>>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  enableDrag: false,
  builder: (_) => VideoCropSheet(initial: initial, frameAspect: frameAspect, framePath: framePath),
);

/// Free-form crop editor for a clip: drag the corners or the whole box,
/// optionally locked to an aspect ratio. Pops the new `[l, t, r, b]`.
class VideoCropSheet extends StatefulWidget {
  const VideoCropSheet({required this.initial, required this.frameAspect, this.framePath, super.key});

  final List<double> initial;

  /// Source frame width / height.
  final double frameAspect;

  /// A thumbnail of the clip, shown under the crop box.
  final String? framePath;

  @override
  State<VideoCropSheet> createState() => _VideoCropSheetState();
}

class _VideoCropSheetState extends State<VideoCropSheet> {
  late List<double> _rect = List.of(widget.initial);
  double? _aspect;
  int? _corner;

  static const _aspects = <(String, double?)>[
    ('Free', null),
    ('1:1', 1),
    ('4:5', 0.8),
    ('9:16', 9 / 16),
    ('16:9', 16 / 9),
  ];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: widget.frameAspect,
              child: LayoutBuilder(
                builder: (context, c) {
                  final w = c.maxWidth;
                  final h = c.maxHeight;
                  final box = Rect.fromLTRB(_rect[0] * w, _rect[1] * h, _rect[2] * w, _rect[3] * h);
                  return GestureDetector(
                    onPanStart: (d) {
                      final corners = [box.topLeft, box.topRight, box.bottomRight, box.bottomLeft];
                      _corner = null;
                      for (var i = 0; i < 4; i++) {
                        if ((corners[i] - d.localPosition).distance < 36) _corner = i;
                      }
                    },
                    onPanUpdate: (d) => setState(() {
                      final dx = d.delta.dx / w;
                      final dy = d.delta.dy / h;
                      final corner = _corner;
                      _rect = corner == null
                          ? moveCrop(_rect, dx, dy)
                          : dragCropCorner(
                              _rect,
                              corner,
                              dx,
                              dy,
                              frameAspect: widget.frameAspect,
                              targetAspect: _aspect,
                            );
                    }),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (widget.framePath != null && File(widget.framePath!).existsSync())
                          Image.file(File(widget.framePath!), fit: BoxFit.fill)
                        else
                          ColoredBox(color: scheme.surfaceContainerHighest),
                        CustomPaint(painter: _CropPainter(box, scheme.primary)),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: [
                for (final (label, a) in _aspects)
                  ChoiceChip(
                    label: Text(a == null ? l.aspectFree : label),
                    selected: _aspect == a,
                    onSelected: (_) => setState(() {
                      Haptics.selection();
                      _aspect = a;
                      if (a != null) _rect = centeredCrop(widget.frameAspect, a);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    _rect = [0, 0, 1, 1];
                    _aspect = null;
                  }),
                  child: Text(l.reset),
                ),
                const Spacer(),
                TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
                FilledButton(onPressed: () => Navigator.pop(context, _rect), child: Text(l.apply)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.box, this.color);
  final Rect box;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), Path()..addRect(box)),
      Paint()..color = const Color(0x99000000),
    );
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;
    canvas.drawRect(box, line);
    final thin = Paint()
      ..strokeWidth = 0.8
      ..color = const Color(0x88FFFFFF);
    for (var i = 1; i < 3; i++) {
      final x = box.left + box.width * i / 3;
      final y = box.top + box.height * i / 3;
      canvas
        ..drawLine(Offset(x, box.top), Offset(x, box.bottom), thin)
        ..drawLine(Offset(box.left, y), Offset(box.right, y), thin);
    }
    for (final c in [box.topLeft, box.topRight, box.bottomRight, box.bottomLeft]) {
      canvas.drawCircle(c, 8, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_CropPainter old) => old.box != box;
}
