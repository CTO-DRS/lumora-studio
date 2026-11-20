import 'dart:convert';
import 'dart:typed_data';

/// Page size in PDF points (1/72 inch).
enum PdfPageSize {
  a4(595.28, 841.89),
  letter(612, 792),

  /// Each page takes the aspect ratio of its image (width 595 pt).
  fit(0, 0);

  const PdfPageSize(this.width, this.height);
  final double width;
  final double height;
}

/// One JPEG image per page.
class PdfImagePage {
  const PdfImagePage({required this.jpeg, required this.width, required this.height, this.grayscale = false});

  final Uint8List jpeg;

  /// Pixel size of [jpeg].
  final int width;
  final int height;

  /// The JPEG has a single channel.
  final bool grayscale;
}

/// Minimal, dependency-free PDF 1.4 writer: every page shows one JPEG
/// (embedded as-is with DCTDecode, so there is no re-compression).
/// Portrait/landscape follows the image; images are fitted with a margin.
Uint8List buildImagePdf(
  List<PdfImagePage> pages, {
  PdfPageSize size = PdfPageSize.a4,
  double margin = 18,
  String title = 'Lumora scan',
}) {
  if (pages.isEmpty) throw ArgumentError('no pages');
  final out = BytesBuilder(copy: false);
  final offsets = <int>[];
  void raw(String s) => out.add(latin1.encode(s));
  void obj(int n, String body, [Uint8List? stream]) {
    offsets.add(out.length);
    raw('$n 0 obj\n$body');
    if (stream != null) {
      raw('\nstream\n');
      out.add(stream);
      raw('\nendstream');
    }
    raw('\nendobj\n');
  }

  String num(double v) => v.toStringAsFixed(2);

  out.add([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34, 0x0A, 0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A]);
  // 1 catalog, 2 pages, 3 info, then per page: page, contents, image.
  final kids = [for (var i = 0; i < pages.length; i++) '${4 + i * 3} 0 R'].join(' ');
  obj(1, '<< /Type /Catalog /Pages 2 0 R >>');
  obj(2, '<< /Type /Pages /Kids [$kids] /Count ${pages.length} >>');
  final safeTitle = title
      .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
      .replaceAll(r'\', '')
      .replaceAll('(', '')
      .replaceAll(')', '');
  obj(3, '<< /Title ($safeTitle) /Producer (Lumora Studio) >>');
  for (var i = 0; i < pages.length; i++) {
    final p = pages[i];
    final pageObj = 4 + i * 3;
    final landscape = p.width > p.height;
    double pw;
    double ph;
    var pageMargin = margin;
    if (size == PdfPageSize.fit) {
      pw = 595.28;
      ph = pw * p.height / p.width;
      pageMargin = 0;
    } else {
      pw = landscape ? size.height : size.width;
      ph = landscape ? size.width : size.height;
    }
    final availW = pw - 2 * pageMargin;
    final availH = ph - 2 * pageMargin;
    final k = (availW / p.width) < (availH / p.height) ? availW / p.width : availH / p.height;
    final dw = p.width * k;
    final dh = p.height * k;
    final dx = (pw - dw) / 2;
    final dy = (ph - dh) / 2;
    final content = latin1.encode('q ${num(dw)} 0 0 ${num(dh)} ${num(dx)} ${num(dy)} cm /Im0 Do Q');
    obj(
      pageObj,
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${num(pw)} ${num(ph)}] '
      '/Resources << /XObject << /Im0 ${pageObj + 2} 0 R >> >> /Contents ${pageObj + 1} 0 R >>',
    );
    obj(pageObj + 1, '<< /Length ${content.length} >>', Uint8List.fromList(content));
    obj(
      pageObj + 2,
      '<< /Type /XObject /Subtype /Image /Width ${p.width} /Height ${p.height} '
      '/ColorSpace /${p.grayscale ? 'DeviceGray' : 'DeviceRGB'} /BitsPerComponent 8 '
      '/Filter /DCTDecode /Length ${p.jpeg.length} >>',
      p.jpeg,
    );
  }
  final xref = out.length;
  final count = offsets.length + 1;
  final sb = StringBuffer('xref\n0 $count\n0000000000 65535 f \n');
  for (final o in offsets) {
    sb.write('${o.toString().padLeft(10, '0')} 00000 n \n');
  }
  sb.write('trailer\n<< /Size $count /Root 1 0 R /Info 3 0 R >>\nstartxref\n$xref\n%%EOF\n');
  raw(sb.toString());
  return out.takeBytes();
}
