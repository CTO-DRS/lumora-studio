import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lumora/core/utils/haptics.dart';
import 'package:lumora/core/utils/l10n_ext.dart';
import 'package:lumora/features/photo_editor/engine/photo_renderer.dart';
import 'package:lumora/features/photo_editor/engine/pixel_ops.dart';
import 'package:lumora/features/scanner/data/scanner_service.dart';
import 'package:lumora/features/scanner/domain/document_geometry.dart';
import 'package:lumora/features/scanner/domain/pdf_writer.dart';
import 'package:lumora/features/scanner/domain/scan_filters.dart';
import 'package:lumora/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

final Provider<ScannerService> scannerServiceProvider = Provider<ScannerService>((_) => ScannerService());

String scanFilterLabel(AppLocalizations l, ScanFilter f) => switch (f) {
  ScanFilter.original => l.scanOriginal,
  ScanFilter.magicColor => l.scanMagic,
  ScanFilter.noShadow => l.scanNoShadow,
  ScanFilter.grayscale => l.scanGray,
  ScanFilter.blackWhite => l.scanBw,
};

/// Document scanner: capture or pick pages, auto-detect edges, adjust the
/// corners, flatten, clean up and export a multi-page PDF.
class ScannerPage extends ConsumerStatefulWidget {
  const ScannerPage({super.key});

  @override
  ConsumerState<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends ConsumerState<ScannerPage> {
  final List<ScanPage> _pages = [];
  final Map<String, Rgba> _proxies = {};
  final Map<String, ui.Image> _proxyImages = {};
  final Map<String, ui.Image> _previews = {};
  int _current = 0;
  bool _showResult = false;
  bool _busy = false;
  double? _progress;
  Timer? _previewDebounce;
  static const _uuid = Uuid();

  ScannerService get _service => ref.read(scannerServiceProvider);

  @override
  void dispose() {
    _previewDebounce?.cancel();
    for (final i in [..._proxyImages.values, ..._previews.values]) {
      i.dispose();
    }
    super.dispose();
  }

  ScanPage? get _page => _pages.isEmpty ? null : _pages[_current.clamp(0, _pages.length - 1)];

  Future<void> _add(ImageSource source) async {
    final picker = ImagePicker();
    final files = source == ImageSource.camera
        ? [?(await picker.pickImage(source: ImageSource.camera))]
        : await picker.pickMultiImage();
    if (files.isEmpty) return;
    setState(() => _busy = true);
    try {
      for (final f in files) {
        final proxy = await _service.loadProxy(f.path);
        final detected = await _service.detect(proxy);
        final page = ScanPage(id: _uuid.v4(), sourcePath: f.path, quad: detected.quad, confidence: detected.confidence);
        _proxies[page.id] = proxy;
        _proxyImages[page.id] = await imageFromRgba(proxy.data, proxy.width, proxy.height);
        _pages.add(page);
      }
      _current = _pages.length - 1;
      Haptics.light();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    _schedulePreview();
  }

  void _update(ScanPage page) {
    final i = _pages.indexWhere((p) => p.id == page.id);
    if (i < 0) return;
    setState(() => _pages[i] = page);
    _schedulePreview();
  }

  void _schedulePreview() {
    _previewDebounce?.cancel();
    _previewDebounce = Timer(const Duration(milliseconds: 250), () async {
      final page = _page;
      if (page == null) return;
      final proxy = _proxies[page.id];
      if (proxy == null) return;
      final out = await _service.preview(proxy, page);
      final image = await imageFromRgba(out.data, out.width, out.height);
      if (!mounted) {
        image.dispose();
        return;
      }
      final old = _previews[page.id];
      setState(() => _previews[page.id] = image);
      WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
    });
  }

  Future<void> _redetect() async {
    final page = _page;
    final proxy = page == null ? null : _proxies[page.id];
    if (page == null || proxy == null) return;
    final d = await _service.detect(proxy);
    _update(page.copyWith(quad: d.quad));
  }

  Future<List<ProcessedPage>> _processAll() async {
    final out = <ProcessedPage>[];
    for (var i = 0; i < _pages.length; i++) {
      setState(() => _progress = i / _pages.length);
      out.add(await _service.process(_pages[i]));
    }
    return out;
  }

  Future<void> _export() async {
    final l = context.l10n;
    final choice = await showModalBottomSheet<(String, PdfPageSize)>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF · A4'),
              onTap: () => Navigator.pop(c, ('pdf', PdfPageSize.a4)),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF · Letter'),
              onTap: () => Navigator.pop(c, ('pdf', PdfPageSize.letter)),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text('PDF · ${l.scanFitPage}'),
              onTap: () => Navigator.pop(c, ('pdf', PdfPageSize.fit)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l.scanSaveImages),
              onTap: () => Navigator.pop(c, ('jpg', PdfPageSize.a4)),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    setState(() {
      _busy = true;
      _progress = 0;
    });
    try {
      final processed = await _processAll();
      if (choice.$1 == 'pdf') {
        final pdf = await _service.buildPdf(processed, size: choice.$2);
        Haptics.medium();
        await SharePlus.instance.share(ShareParams(files: [XFile(pdf.path, mimeType: 'application/pdf')]));
      } else {
        if (await Gal.requestPermission()) {
          for (final p in processed) {
            await Gal.putImage(p.path, album: 'Lumora');
          }
        }
        Haptics.medium();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.exported)));
      }
    } on Object catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.errorGeneric('$e'))));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final page = _page;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.scanDocument),
        actions: [
          if (_pages.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: FilledButton.icon(
                onPressed: _busy ? null : _export,
                icon: const Icon(Icons.ios_share),
                label: Text(l.export),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          if (page == null) _empty(l) else _editor(l, page),
          if (_busy)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black45,
                child: Center(child: CircularProgressIndicator(value: _progress)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _empty(AppLocalizations l) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.document_scanner_outlined, size: 72),
          const SizedBox(height: 16),
          Text(l.scanIntro, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _add(ImageSource.camera),
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(l.scanCamera),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _add(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(l.scanGallery),
          ),
        ],
      ),
    ),
  );

  Widget _editor(AppLocalizations l, ScanPage page) {
    final proxyImage = _proxyImages[page.id];
    final preview = _previews[page.id];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, icon: const Icon(Icons.crop_free), label: Text(l.scanCorners)),
              ButtonSegment(value: true, icon: const Icon(Icons.description_outlined), label: Text(l.scanResult)),
            ],
            selected: {_showResult},
            onSelectionChanged: (v) => setState(() => _showResult = v.first),
          ),
        ),
        if (!_showResult && page.confidence < 0.45)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l.scanAdjustHint, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _showResult
                ? (preview == null
                      ? const Center(child: CircularProgressIndicator())
                      : Center(
                          child: RawImage(image: preview, fit: BoxFit.contain),
                        ))
                : (proxyImage == null
                      ? const SizedBox.shrink()
                      : CornerEditor(
                          image: proxyImage,
                          quad: page.quad,
                          onChanged: (q) => _update(page.copyWith(quad: q)),
                        )),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final f in ScanFilter.values)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: ChoiceChip(
                    label: Text(scanFilterLabel(l, f)),
                    selected: page.filter == f,
                    onSelected: (_) {
                      Haptics.selection();
                      setState(() => _showResult = true);
                      _update(page.copyWith(filter: f));
                    },
                  ),
                ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(tooltip: l.scanAutoDetect, icon: const Icon(Icons.auto_fix_high), onPressed: _redetect),
            IconButton(
              tooltip: l.scanFullFrame,
              icon: const Icon(Icons.fullscreen),
              onPressed: () => _update(page.copyWith(quad: Quad.full)),
            ),
            IconButton(
              tooltip: l.rotate,
              icon: const Icon(Icons.rotate_90_degrees_cw_outlined),
              onPressed: () => _update(page.copyWith(quarterTurns: (page.quarterTurns + 1) % 4)),
            ),
            IconButton(
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => setState(() {
                _pages.removeAt(_current);
                _current = (_current - 1).clamp(0, _pages.length);
                _schedulePreview();
              }),
            ),
          ],
        ),
        SafeArea(
          top: false,
          child: SizedBox(
            height: 92,
            child: Row(
              children: [
                Expanded(
                  child: ReorderableListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    itemCount: _pages.length,
                    onReorderItem: (from, to) => setState(() {
                      final p = _pages.removeAt(from);
                      _pages.insert(to, p);
                      _current = _pages.indexOf(p);
                    }),
                    itemBuilder: (context, i) {
                      final pg = _pages[i];
                      final thumb = _previews[pg.id] ?? _proxyImages[pg.id];
                      return Padding(
                        key: ValueKey(pg.id),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _current = i);
                            _schedulePreview();
                          },
                          child: Container(
                            width: 60,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: i == _current ? Theme.of(context).colorScheme.primary : Colors.transparent,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (thumb != null) RawImage(image: thumb, fit: BoxFit.cover),
                                Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(color: Colors.white, shadows: [Shadow(blurRadius: 4)]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: l.scanAddPage,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  onPressed: () => _add(ImageSource.camera),
                ),
                IconButton(
                  tooltip: l.scanGallery,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  onPressed: () => _add(ImageSource.gallery),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Shows [image] with four draggable corner handles (normalised [quad])
/// and a magnifier while dragging.
class CornerEditor extends StatefulWidget {
  const CornerEditor({required this.image, required this.quad, required this.onChanged, super.key});

  final ui.Image image;
  final Quad quad;
  final ValueChanged<Quad> onChanged;

  @override
  State<CornerEditor> createState() => _CornerEditorState();
}

class _CornerEditorState extends State<CornerEditor> {
  int? _active;
  Offset? _finger;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return LayoutBuilder(
      builder: (context, c) {
        final img = widget.image;
        final k = (c.maxWidth / img.width) < (c.maxHeight / img.height)
            ? c.maxWidth / img.width
            : c.maxHeight / img.height;
        final size = Size(img.width * k, img.height * k);
        final origin = Offset((c.maxWidth - size.width) / 2, (c.maxHeight - size.height) / 2);
        Offset toScreen(Pt p) => origin + Offset(p.x * size.width, p.y * size.height);
        final names = [l.cornerTopLeft, l.cornerTopRight, l.cornerBottomRight, l.cornerBottomLeft];
        return GestureDetector(
          onPanStart: (d) {
            var best = -1;
            var bestD = 48.0;
            for (var i = 0; i < 4; i++) {
              final dist = (toScreen(widget.quad.points[i]) - d.localPosition).distance;
              if (dist < bestD) {
                bestD = dist;
                best = i;
              }
            }
            if (best >= 0) {
              Haptics.selection();
              setState(() {
                _active = best;
                _finger = d.localPosition;
              });
            }
          },
          onPanUpdate: (d) {
            final i = _active;
            if (i == null) return;
            final local = d.localPosition - origin;
            final p = Pt((local.dx / size.width).clamp(0.0, 1.0), (local.dy / size.height).clamp(0.0, 1.0));
            setState(() => _finger = d.localPosition);
            widget.onChanged(widget.quad.withPoint(i, p));
          },
          onPanEnd: (_) => setState(() {
            _active = null;
            _finger = null;
          }),
          child: Stack(
            children: [
              Positioned.fromRect(
                rect: origin & size,
                child: RawImage(image: img, fit: BoxFit.fill),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _QuadPainter(
                    [for (final p in widget.quad.points) toScreen(p)],
                    Theme.of(context).colorScheme.primary,
                    _active,
                  ),
                ),
              ),
              for (var i = 0; i < 4; i++)
                Positioned(
                  left: toScreen(widget.quad.points[i]).dx - 24,
                  top: toScreen(widget.quad.points[i]).dy - 24,
                  width: 48,
                  height: 48,
                  child: Semantics(label: names[i], slider: true, child: const SizedBox.expand()),
                ),
              if (_finger != null)
                Positioned(
                  left: (_finger!.dx - 60).clamp(0, c.maxWidth - 120),
                  top: (_finger!.dy - 150).clamp(0, c.maxHeight - 120),
                  child: RawMagnifier(
                    size: const Size(120, 120),
                    magnificationScale: 2,
                    focalPointOffset: Offset(
                      _finger!.dx - ((_finger!.dx - 60).clamp(0, c.maxWidth - 120) + 60),
                      _finger!.dy - ((_finger!.dy - 150).clamp(0, c.maxHeight - 120) + 60),
                    ),
                    decoration: const MagnifierDecoration(
                      shape: CircleBorder(side: BorderSide(color: Colors.white, width: 2)),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _QuadPainter extends CustomPainter {
  _QuadPainter(this.points, this.color, this.active);
  final List<Offset> points;
  final Color color;
  final int? active;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addPolygon(points, true);
    canvas
      ..drawPath(
        Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), path),
        Paint()..color = const Color(0x66000000),
      )
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color,
      );
    for (var i = 0; i < points.length; i++) {
      canvas
        ..drawCircle(points[i], i == active ? 14 : 11, Paint()..color = color.withValues(alpha: 0.35))
        ..drawCircle(
          points[i],
          i == active ? 14 : 11,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = color,
        );
    }
  }

  @override
  bool shouldRepaint(_QuadPainter old) => true;
}
