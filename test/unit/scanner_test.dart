import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumora/features/photo_editor/engine/pixel_ops.dart';
import 'package:lumora/features/scanner/data/scanner_service.dart';
import 'package:lumora/features/scanner/domain/document_detector.dart';
import 'package:lumora/features/scanner/domain/document_geometry.dart';
import 'package:lumora/features/scanner/domain/pdf_writer.dart';
import 'package:lumora/features/scanner/domain/scan_filters.dart';

/// Dark table with a bright, perspective-distorted sheet of paper.
Rgba photoOfPaper(int w, int h, Quad corners) {
  final out = Rgba(w, h)..fill(0xFF3A3530);
  final q = corners.scale(w.toDouble(), h.toDouble());
  bool inside(double x, double y) {
    final p = q.points;
    for (var i = 0; i < 4; i++) {
      final a = p[i];
      final b = p[(i + 1) % 4];
      if ((b.x - a.x) * (y - a.y) - (b.y - a.y) * (x - a.x) < 0) return false;
    }
    return true;
  }

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (inside(x + 0.5, y + 0.5)) {
        // Paper with a soft shadow gradient and a few ink lines.
        final shade = 235 - (x * 40 ~/ w);
        final ink = (y % 23 < 2) && x % 5 != 0;
        final v = ink ? 60 : shade;
        out.data.setAll(out.offset(x, y), [v, v, ink ? 140 : v - 5, 255]);
      }
    }
  }
  return out;
}

double maxCornerError(Quad a, Quad b) {
  var m = 0.0;
  for (var i = 0; i < 4; i++) {
    final d = a.points[i].distanceTo(b.points[i]);
    if (d > m) m = d;
  }
  return m;
}

void main() {
  group('document detection', () {
    test('finds a tilted sheet on a dark table', () {
      const truth = Quad(Pt(0.18, 0.12), Pt(0.84, 0.08), Pt(0.9, 0.9), Pt(0.12, 0.86));
      final d = detectDocument(photoOfPaper(400, 300, truth));
      expect(d.found, isTrue);
      expect(d.confidence, greaterThan(0.5));
      expect(maxCornerError(d.quad, truth), lessThan(0.03), reason: '${d.quad.points}');
    });

    test('also works for dark paper on a light background', () {
      const truth = Quad(Pt(0.2, 0.2), Pt(0.8, 0.2), Pt(0.8, 0.8), Pt(0.2, 0.8));
      final light = Rgba(200, 200)..fill(0xFFF0F0F0);
      final q = truth.scale(200, 200);
      for (var y = q.topLeft.y.toInt(); y < q.bottomLeft.y; y++) {
        for (var x = q.topLeft.x.toInt(); x < q.topRight.x; x++) {
          light.data.setAll(light.offset(x, y), [40, 40, 50, 255]);
        }
      }
      final d = detectDocument(light);
      expect(maxCornerError(d.quad, truth), lessThan(0.03));
    });

    test('a featureless photo falls back to an inset frame with no confidence', () {
      final d = detectDocument(Rgba(100, 80)..fill(0xFF808080));
      expect(d.found, isFalse);
      expect(d.quad, Quad.inset);
    });

    test('otsu splits a bimodal histogram between the modes', () {
      final v = Uint8List.fromList([...List.filled(100, 40), ...List.filled(100, 200)]);
      expect(otsuThreshold(v), inInclusiveRange(40, 199));
    });

    test('convex hull and largest quad of a noisy rectangle', () {
      final pts = <Pt>[
        for (var i = 0; i <= 10; i++) ...[Pt(i * 10.0, 0), Pt(i * 10.0, 50), Pt(0, i * 5.0), Pt(100, i * 5.0)],
        const Pt(50, 25),
        const Pt(30, 10),
      ];
      final hull = convexHull(pts);
      expect(hull.contains(const Pt(50, 25)), isFalse);
      final q = largestQuad(hull);
      expect(q.area, closeTo(5000, 1));
      expect(q.topLeft, const Pt(0, 0));
      expect(q.bottomRight, const Pt(100, 50));
    });
  });

  group('geometry', () {
    test('homography maps the four corners exactly', () {
      const from = [Pt(0, 0), Pt(100, 0), Pt(100, 50), Pt(0, 50)];
      const to = [Pt(10, 5), Pt(90, 12), Pt(95, 70), Pt(3, 60)];
      final h = Homography.solve(from, to);
      for (var i = 0; i < 4; i++) {
        final (x, y) = h.apply(from[i].x, from[i].y);
        expect(x, closeTo(to[i].x, 1e-6));
        expect(y, closeTo(to[i].y, 1e-6));
      }
    });

    test('Quad ordering, convexity and json', () {
      final q = Quad.fromUnordered(const [Pt(1, 1), Pt(0, 0), Pt(0, 1), Pt(1, 0)]);
      expect(q, Quad.full);
      expect(q.isConvex, isTrue);
      expect(const Quad(Pt(0, 0), Pt(1, 1), Pt(1, 0), Pt(0, 1)).isConvex, isFalse);
      expect(Quad.fromJson(jsonDecode(jsonEncode(q.toJson())) as List), q);
      expect(q.withPoint(2, const Pt(0.5, 0.5)).bottomRight, const Pt(0.5, 0.5));
    });

    test('flattening a distorted sheet yields an upright page', () {
      const truth = Quad(Pt(0.18, 0.12), Pt(0.84, 0.08), Pt(0.9, 0.9), Pt(0.12, 0.86));
      final photo = photoOfPaper(400, 300, truth);
      final q = truth.scale(400, 300);
      final (w, h) = flattenedSize(q);
      expect(w, greaterThan(h));
      final flat = warpPerspective(photo, q, w, h);
      // Every pixel of the flattened page comes from the paper (bright or ink),
      // never from the dark table.
      var table = 0;
      for (var y = 3; y < h - 3; y++) {
        for (var x = 3; x < w - 3; x++) {
          final o = flat.offset(x, y);
          if (flat.data[o] > 50 && flat.data[o] < 70 && flat.data[o + 2] < 60) table++;
        }
      }
      expect(table, 0);
    });

    test('rotateQuarter turns images', () {
      final src = Rgba(3, 2);
      src.data.setAll(src.offset(0, 0), [9, 9, 9, 255]);
      final r = rotateQuarter(src, 1);
      expect((r.width, r.height), (2, 3));
      expect(r.data[r.offset(1, 0)], 9);
      final r2 = rotateQuarter(src, 2);
      expect(r2.data[r2.offset(2, 1)], 9);
      final r3 = rotateQuarter(src, 3);
      expect(r3.data[r3.offset(0, 2)], 9);
      expect(identical(rotateQuarter(src, 4), src), isTrue);
    });
  });

  group('scan filters', () {
    // Paper with a strong shadow on the right and ink text.
    Rgba shadowedPage() {
      final img = Rgba(120, 80);
      for (var y = 0; y < 80; y++) {
        for (var x = 0; x < 120; x++) {
          final paper = 230 - x; // 230 → 111 (deep shadow)
          final ink = y % 10 < 2 && x % 7 < 5;
          final v = ink ? paper ~/ 3 : paper;
          img.data.setAll(img.offset(x, y), [v, v, v, 255]);
        }
      }
      return img;
    }

    test('shadow removal makes the paper evenly white', () {
      final out = applyScanFilter(shadowedPage(), ScanFilter.noShadow);
      final left = out.data[out.offset(10, 5)];
      final right = out.data[out.offset(110, 5)];
      expect(left, greaterThan(225));
      expect(right, greaterThan(225), reason: 'shadowed paper is lifted to white');
    });

    test('black & white keeps ink black and paper white', () {
      final out = applyScanFilter(shadowedPage(), ScanFilter.blackWhite);
      expect(out.data[out.offset(105, 5)], 255);
      expect(out.data[out.offset(105, 0)], 0, reason: 'ink in the shadow stays readable');
      expect(out.data[out.offset(10, 0)], 0);
    });

    test('grayscale and magic colour produce valid images; original is untouched', () {
      final page = shadowedPage();
      expect(identical(applyScanFilter(page, ScanFilter.original), page), isTrue);
      for (final f in [ScanFilter.grayscale, ScanFilter.magicColor]) {
        final out = applyScanFilter(page, f);
        expect((out.width, out.height), (120, 80));
        expect(out.data[out.offset(110, 5)], greaterThan(200), reason: '$f');
      }
    });

    test('ScannerService.render flattens, filters and rotates', () {
      final photo = photoOfPaper(200, 150, Quad.inset);
      const page = ScanPage(id: 'a', sourcePath: '', quad: Quad.inset, filter: ScanFilter.blackWhite, quarterTurns: 1);
      final out = ScannerService.render(photo, page);
      expect(out.width, lessThan(out.height));
    });
  });

  group('PDF writer', () {
    Uint8List jpeg(int w, int h) => img.encodeJpg(img.Image(width: w, height: h), quality: 80);

    test('writes a valid multi-page PDF with a correct xref table', () {
      final pages = [
        PdfImagePage(jpeg: jpeg(40, 60), width: 40, height: 60),
        PdfImagePage(jpeg: jpeg(80, 30), width: 80, height: 30),
      ];
      final pdf = buildImagePdf(pages, title: 'Scan ✓ (test)');
      final text = latin1.decode(pdf);
      expect(text.startsWith('%PDF-1.4'), isTrue);
      expect(text.trimRight().endsWith('%%EOF'), isTrue);
      expect(text, contains('/Count 2'));
      expect(text, contains('/Filter /DCTDecode'));
      expect(RegExp('/Type /Page ').allMatches(text).length, 2);
      // Landscape image → landscape A4 page.
      expect(text, contains('/MediaBox [0 0 841.89 595.28]'));
      final startxref = int.parse(RegExp(r'startxref\n(\d+)').firstMatch(text)!.group(1)!);
      expect(text.substring(startxref, startxref + 4), 'xref');
      final entries = RegExp(r'(\d{10}) 00000 n').allMatches(text).map((m) => int.parse(m.group(1)!)).toList();
      expect(entries, hasLength(1 + 2 + 2 * 3));
      for (var i = 0; i < entries.length; i++) {
        expect(text.substring(entries[i]).startsWith('${i + 1} 0 obj'), isTrue, reason: 'object ${i + 1}');
      }
    });

    test('fit page size follows the image aspect ratio', () {
      final pdf = buildImagePdf([PdfImagePage(jpeg: jpeg(100, 200), width: 100, height: 200)], size: PdfPageSize.fit);
      expect(latin1.decode(pdf), contains('/MediaBox [0 0 595.28 1190.56]'));
      expect(() => buildImagePdf([]), throwsArgumentError);
    });
  });
}
