import 'dart:io';
import 'dart:isolate';

import 'package:image/image.dart' as img;
import 'package:lumora/features/ai/pipelines/ai_pipelines.dart';
import 'package:lumora/features/photo_editor/engine/pixel_ops.dart';
import 'package:lumora/features/scanner/domain/document_detector.dart';
import 'package:lumora/features/scanner/domain/document_geometry.dart';
import 'package:lumora/features/scanner/domain/pdf_writer.dart';
import 'package:lumora/features/scanner/domain/scan_filters.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// One page of a scan session.
class ScanPage {
  const ScanPage({
    required this.id,
    required this.sourcePath,
    required this.quad,
    this.confidence = 0,
    this.filter = ScanFilter.magicColor,
    this.quarterTurns = 0,
  });

  final String id;
  final String sourcePath;

  /// Document corners, normalised to the (orientation-corrected) photo.
  final Quad quad;
  final double confidence;
  final ScanFilter filter;
  final int quarterTurns;

  ScanPage copyWith({Quad? quad, ScanFilter? filter, int? quarterTurns}) => ScanPage(
    id: id,
    sourcePath: sourcePath,
    quad: quad ?? this.quad,
    confidence: confidence,
    filter: filter ?? this.filter,
    quarterTurns: quarterTurns ?? this.quarterTurns,
  );
}

/// A processed page ready for PDF/gallery export.
class ProcessedPage {
  const ProcessedPage(this.path, this.width, this.height);
  final String path;
  final int width;
  final int height;
}

/// Runs the scanner pipeline (detect → flatten → enhance → encode) on
/// background isolates. Everything stays on the device.
class ScannerService {
  /// Proxy used for detection and live previews.
  static const previewSide = 1200;

  Future<Rgba> loadProxy(String path) async {
    final r = await loadRgba(path, maxSide: previewSide);
    return Rgba(r.width, r.height, r.pixels);
  }

  Future<DetectedDocument> detect(Rgba proxy) => Isolate.run(() => detectDocument(proxy));

  /// Flattens + enhances [page] on [source] (any resolution).
  static Rgba render(Rgba source, ScanPage page, {int maxSide = 3508}) {
    final q = page.quad.scale(source.width.toDouble(), source.height.toDouble());
    final (w, h) = flattenedSize(q, maxSide: maxSide);
    final flat = warpPerspective(source, q, w, h);
    return rotateQuarter(applyScanFilter(flat, page.filter), page.quarterTurns);
  }

  /// Preview of [page] from an already loaded [proxy].
  Future<Rgba> preview(Rgba proxy, ScanPage page) => Isolate.run(() => render(proxy, page, maxSide: 1000));

  /// Full-resolution page as a JPEG in the app's scan folder.
  Future<ProcessedPage> process(ScanPage page, {int quality = 88}) async {
    final full = await loadRgba(page.sourcePath, maxSide: 4000);
    final src = Rgba(full.width, full.height, full.pixels);
    final (bytes, w, h) = await Isolate.run(() {
      final out = render(src, page);
      final image = img.Image.fromBytes(
        width: out.width,
        height: out.height,
        bytes: out.data.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );
      return (img.encodeJpg(image, quality: quality), out.width, out.height);
    });
    final dir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'scans'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    final file = File(p.join(dir.path, 'scan_${DateTime.now().microsecondsSinceEpoch}.jpg'));
    await file.writeAsBytes(bytes, flush: true);
    return ProcessedPage(file.path, w, h);
  }

  /// Builds a multi-page PDF from processed pages.
  Future<File> buildPdf(List<ProcessedPage> pages, {PdfPageSize size = PdfPageSize.a4, String? name}) async {
    final images = <PdfImagePage>[
      for (final pg in pages) PdfImagePage(jpeg: await File(pg.path).readAsBytes(), width: pg.width, height: pg.height),
    ];
    final bytes = await Isolate.run(() => buildImagePdf(images, size: size));
    final dir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'scans'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    final file = File(p.join(dir.path, '${name ?? 'Lumora_Scan_${DateTime.now().millisecondsSinceEpoch}'}.pdf'));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
