import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lumora/core/providers.dart';
import 'package:lumora/core/utils/haptics.dart';
import 'package:lumora/core/utils/l10n_ext.dart';
import 'package:lumora/core/widgets/labeled_slider.dart';
import 'package:lumora/features/collage/domain/collage.dart';
import 'package:lumora/features/photo_editor/engine/image_exporter.dart';
import 'package:lumora/features/photo_editor/presentation/widgets/finish_panels.dart' show kSwatches;
import 'package:lumora/features/settings/data/settings_controller.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

/// Gradient backgrounds offered besides plain colours.
const kCollageGradients = <List<int>>[
  [0xFFFFB547, 0xFFFF6B6B],
  [0xFF8B7CFF, 0xFF3FC5F0],
  [0xFF43E0A0, 0xFF2E7BFF],
  [0xFF1F1F24, 0xFF4A4A57],
];

/// Draws a collage. Shared by the live preview and the full-size export.
void paintCollage(
  Canvas canvas,
  Size size, {
  required CollageLayout layout,
  required List<ui.Image?> images,
  required List<CellTransform> transforms,
  required double spacing,
  required double margin,
  required double radius,
  required int background,
  List<int>? gradient,
  int? selected,
  Color? highlight,
}) {
  final full = Offset.zero & size;
  if (gradient != null) {
    canvas.drawRect(
      full,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(size.width, size.height), [
          Color(gradient[0]),
          Color(gradient[1]),
        ]),
    );
  } else {
    canvas.drawRect(full, Paint()..color = Color(background));
  }
  final short = math.min(size.width, size.height);
  for (var i = 0; i < layout.cells.length; i++) {
    final r = cellRect(layout.cells[i], size.width, size.height, spacing: spacing * short, margin: margin * short);
    final dst = Rect.fromLTWH(r.left, r.top, r.width, r.height);
    final rr = RRect.fromRectAndRadius(dst, Radius.circular(radius * short));
    final img = i < images.length ? images[i] : null;
    canvas
      ..save()
      ..clipRRect(rr);
    if (img == null) {
      canvas.drawRect(dst, Paint()..color = const Color(0x33FFFFFF));
    } else {
      final t = i < transforms.length ? transforms[i] : const CellTransform();
      final s = coverSource(img.width.toDouble(), img.height.toDouble(), r.width, r.height, t);
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(s.left, s.top, s.width, s.height),
        dst,
        Paint()..filterQuality = FilterQuality.medium,
      );
    }
    canvas.restore();
    if (selected == i && highlight != null) {
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = highlight,
      );
    }
  }
}

class CollagePage extends ConsumerStatefulWidget {
  const CollagePage({super.key});

  @override
  ConsumerState<CollagePage> createState() => _CollagePageState();
}

class _CollagePageState extends ConsumerState<CollagePage> {
  final List<String> _paths = [];
  final List<ui.Image?> _images = [];
  List<CellTransform> _transforms = [];
  CollageLayout _layout = kCollageLayouts.first;
  double _aspect = 1;
  double _spacing = 0.015;
  double _margin = 0.02;
  double _radius = 0;
  int _background = 0xFFFFFFFF;
  List<int>? _gradient;
  int? _selected;
  int _tab = 0;
  bool _busy = false;
  CellTransform? _gestureStart;

  @override
  void dispose() {
    for (final i in _images) {
      i?.dispose();
    }
    super.dispose();
  }

  Future<ui.Image> _load(String path) async {
    final bytes = await File(path).readAsBytes();
    final desc = await ui.ImageDescriptor.encoded(await ui.ImmutableBuffer.fromUint8List(bytes));
    // Long side 2400 keeps export sharp and memory bounded.
    final k = math.min(1, 2400 / math.max(desc.width, desc.height));
    final codec = await desc.instantiateCodec(
      targetWidth: math.max(1, (desc.width * k).round()),
      targetHeight: math.max(1, (desc.height * k).round()),
    );
    final img = (await codec.getNextFrame()).image;
    desc.dispose();
    return img;
  }

  Future<void> _pick({int? replace}) async {
    final picker = ImagePicker();
    final files = replace != null
        ? [?(await picker.pickImage(source: ImageSource.gallery))]
        : await picker.pickMultiImage(limit: 9);
    if (files.isEmpty) return;
    setState(() => _busy = true);
    try {
      if (replace != null) {
        final img = await _load(files.first.path);
        _images[replace]?.dispose();
        _images[replace] = img;
        _paths[replace] = files.first.path;
        _transforms[replace] = const CellTransform();
      } else {
        for (final f in files.take(9 - _paths.length)) {
          _paths.add(f.path);
          _images.add(await _load(f.path));
        }
        _layout = layoutsFor(_paths.length).first;
        _transforms = List.filled(_layout.cells.length, const CellTransform());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setLayout(CollageLayout l) {
    Haptics.selection();
    setState(() {
      _layout = l;
      _transforms = List.generate(
        l.cells.length,
        (i) => i < _transforms.length ? _transforms[i] : const CellTransform(),
      );
      _selected = null;
    });
  }

  int? _hit(Offset p, Size size) {
    final short = math.min(size.width, size.height);
    for (var i = 0; i < _layout.cells.length; i++) {
      final r = cellRect(_layout.cells[i], size.width, size.height, spacing: _spacing * short, margin: _margin * short);
      if (Rect.fromLTWH(r.left, r.top, r.width, r.height).contains(p)) return i;
    }
    return null;
  }

  Future<void> _export({required bool share}) async {
    setState(() => _busy = true);
    try {
      final (w, h) = collageOutputSize(_aspect);
      final rec = ui.PictureRecorder();
      paintCollage(
        Canvas(rec),
        Size(w.toDouble(), h.toDouble()),
        layout: _layout,
        images: _images,
        transforms: _transforms,
        spacing: _spacing,
        margin: _margin,
        radius: _radius,
        background: _background,
        gradient: _gradient,
      );
      final pic = rec.endRecording();
      final img = await pic.toImage(w, h);
      pic.dispose();
      final data = await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      img.dispose();
      final settings = ref.read(settingsControllerProvider);
      final renderer = await createPhotoRenderer(ref.read);
      final exporter = ImageExporter(renderer);
      final file = await exporter.encodeAndSave(
        RenderedPixels(data!.buffer.asUint8List(), w, h),
        ExportOptions(
          format: settings.exportFormat == ExportFormat.png ? ExportFormat.png : ExportFormat.jpeg,
          quality: settings.exportQuality,
          keepExif: false,
        ),
      );
      renderer.dispose();
      Haptics.medium();
      if (share) {
        await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
      } else {
        if (await Gal.requestPermission()) await Gal.putImage(file.path, album: 'Lumora');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.exported)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.collage),
        actions: [
          if (_paths.isNotEmpty) ...[
            IconButton(
              tooltip: l.share,
              icon: const Icon(Icons.share_outlined),
              onPressed: _busy ? null : () => _export(share: true),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: FilledButton(onPressed: _busy ? null : () => _export(share: false), child: Text(l.export)),
            ),
          ],
        ],
      ),
      body: _paths.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.dashboard_outlined, size: 72),
                    const SizedBox(height: 16),
                    Text(l.collageIntro, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _busy ? null : _pick,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(l.collagePick),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: _aspect,
                        child: LayoutBuilder(
                          builder: (context, c) {
                            final size = Size(c.maxWidth, c.maxHeight);
                            return GestureDetector(
                              onTapUp: (d) => setState(() => _selected = _hit(d.localPosition, size)),
                              onLongPressStart: (d) {
                                final i = _hit(d.localPosition, size);
                                if (i != null && i < _paths.length) _pick(replace: i);
                              },
                              onScaleStart: (d) {
                                final i = _hit(d.localFocalPoint, size);
                                if (i != null) {
                                  _selected = i;
                                  _gestureStart = _transforms[i];
                                }
                              },
                              onScaleUpdate: (d) {
                                final i = _selected;
                                final start = _gestureStart;
                                if (i == null || start == null) return;
                                final r = cellRect(
                                  _layout.cells[i],
                                  size.width,
                                  size.height,
                                  spacing: _spacing * size.shortestSide,
                                  margin: _margin * size.shortestSide,
                                );
                                setState(() {
                                  final t = _transforms[i];
                                  _transforms[i] = t.copyWith(
                                    scale: start.scale * d.scale,
                                    panX: t.panX - d.focalPointDelta.dx / r.width * 2 / math.max(1, t.scale),
                                    panY: t.panY - d.focalPointDelta.dy / r.height * 2 / math.max(1, t.scale),
                                  );
                                });
                              },
                              child: CustomPaint(
                                size: size,
                                painter: _CollagePainter(
                                  layout: _layout,
                                  images: _images,
                                  transforms: _transforms,
                                  spacing: _spacing,
                                  margin: _margin,
                                  radius: _radius,
                                  background: _background,
                                  gradient: _gradient,
                                  selected: _selected,
                                  highlight: scheme.primary,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                if (_busy) const LinearProgressIndicator(),
                SizedBox(height: 150, child: _tabBody(l)),
                SafeArea(
                  top: false,
                  child: NavigationBar(
                    height: 64,
                    selectedIndex: _tab,
                    onDestinationSelected: (i) => setState(() => _tab = i),
                    destinations: [
                      NavigationDestination(icon: const Icon(Icons.dashboard_outlined), label: l.collageLayout),
                      NavigationDestination(icon: const Icon(Icons.aspect_ratio), label: l.aspectRatio),
                      NavigationDestination(icon: const Icon(Icons.border_outer), label: l.collageBorder),
                      NavigationDestination(icon: const Icon(Icons.format_color_fill), label: l.background),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _tabBody(Object? _) {
    final loc = context.l10n;
    switch (_tab) {
      case 0:
        final layouts = layoutsFor(_paths.length);
        return ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(12),
          children: [
            for (final layout in layouts)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 10),
                child: Semantics(
                  button: true,
                  selected: layout.id == _layout.id,
                  label: '${loc.collageLayout} ${layout.id}',
                  child: GestureDetector(
                    onTap: () => _setLayout(layout),
                    child: SizedBox(
                      width: 72,
                      child: CustomPaint(
                        painter: _LayoutIconPainter(
                          layout,
                          selected: layout.id == _layout.id,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_paths.length < 9)
              Center(
                child: IconButton.filledTonal(
                  tooltip: loc.collagePick,
                  onPressed: _pick,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                ),
              ),
          ],
        );
      case 1:
        return Center(
          child: Wrap(
            spacing: 8,
            children: [
              for (final (label, a) in kCollageAspects)
                ChoiceChip(
                  label: Text(label),
                  selected: (_aspect - a).abs() < 1e-3,
                  onSelected: (_) => setState(() => _aspect = a),
                ),
            ],
          ),
        );
      case 2:
        return ListView(
          children: [
            LabeledSlider(
              label: loc.collageSpacing,
              value: _spacing,
              min: 0,
              max: 0.06,
              displayScale: 1600,
              onChanged: (v) => setState(() => _spacing = v),
            ),
            LabeledSlider(
              label: loc.margin,
              value: _margin,
              min: 0,
              max: 0.1,
              displayScale: 1000,
              onChanged: (v) => setState(() => _margin = v),
            ),
            LabeledSlider(
              label: loc.cornerRadius,
              value: _radius,
              min: 0,
              max: 0.1,
              displayScale: 1000,
              onChanged: (v) => setState(() => _radius = v),
            ),
          ],
        );
      default:
        return ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(16),
          children: [
            for (final c in kSwatches)
              _ColorDot(
                colors: [c, c],
                selected: _gradient == null && _background == c,
                onTap: () => setState(() {
                  _background = c;
                  _gradient = null;
                }),
              ),
            for (final g in kCollageGradients)
              _ColorDot(colors: g, selected: _gradient == g, onTap: () => setState(() => _gradient = g)),
          ],
        );
    }
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.colors, required this.selected, required this.onTap});
  final List<int> colors;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 44,
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [Color(colors[0]), Color(colors[1])]),
        border: Border.all(
          color: selected ? Theme.of(context).colorScheme.primary : Colors.white24,
          width: selected ? 3 : 1,
        ),
      ),
    ),
  );
}

class _CollagePainter extends CustomPainter {
  _CollagePainter({
    required this.layout,
    required this.images,
    required this.transforms,
    required this.spacing,
    required this.margin,
    required this.radius,
    required this.background,
    required this.gradient,
    required this.selected,
    required this.highlight,
  });

  final CollageLayout layout;
  final List<ui.Image?> images;
  final List<CellTransform> transforms;
  final double spacing;
  final double margin;
  final double radius;
  final int background;
  final List<int>? gradient;
  final int? selected;
  final Color highlight;

  @override
  void paint(Canvas canvas, Size size) => paintCollage(
    canvas,
    size,
    layout: layout,
    images: images,
    transforms: transforms,
    spacing: spacing,
    margin: margin,
    radius: radius,
    background: background,
    gradient: gradient,
    selected: selected,
    highlight: highlight,
  );

  @override
  bool shouldRepaint(_CollagePainter old) => true;
}

class _LayoutIconPainter extends CustomPainter {
  _LayoutIconPainter(this.layout, {required this.selected, required this.color});
  final CollageLayout layout;
  final bool selected;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height) - 8;
    final origin = Offset((size.width - s) / 2, (size.height - s) / 2);
    for (final c in layout.cells) {
      final r = cellRect(c, s, s, spacing: 3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(origin.dx + r.left, origin.dy + r.top, r.width, r.height),
          const Radius.circular(3),
        ),
        Paint()..color = selected ? color : const Color(0x88FFFFFF),
      );
    }
  }

  @override
  bool shouldRepaint(_LayoutIconPainter old) => old.selected != selected || old.layout != layout;
}
