/// Wave 2 W2 M2-4 tests: camera-neutral colour rendering — white balance,
/// ColorMatrix1 → linear sRGB, Bradford adaptation, highlight recovery,
/// the SRATIONAL sign fix they depend on, and end-to-end colour DNGs built
/// byte-by-byte with real (signed) colour tags.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumora/features/photo_editor/domain/raw/colour_render.dart';
import 'package:lumora/features/photo_editor/domain/raw/dng_decoder.dart';
import 'package:lumora/features/photo_editor/domain/raw/dng_document.dart';
import 'package:lumora/features/photo_editor/domain/raw/raw_import.dart';
import 'package:lumora/features/photo_editor/domain/raw/tiff_parser.dart';

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

/// Uniform 4×4 linear planes.
DemosaicResult uniformPlanes(double r, double g, double b, [int size = 4]) {
  final n = size * size;
  return DemosaicResult(
    Float32List(n)..fillRange(0, n, r),
    Float32List(n)..fillRange(0, n, g),
    Float32List(n)..fillRange(0, n, b),
    size,
    size,
  );
}

/// A synthetic camera: arbitrary invertible XYZ→camera matrix (row-major).
const List<double> kSyntheticCamera = [
  0.60, 0.30, 0.10, //
  -0.10, 0.90, 0.20, //
  0.15, -0.05, 0.90,
];

List<double> mulVec(List<double> m, List<double> v) => [
      m[0] * v[0] + m[1] * v[1] + m[2] * v[2],
      m[3] * v[0] + m[4] * v[1] + m[5] * v[2],
      m[6] * v[0] + m[7] * v[1] + m[8] * v[2],
    ];

/// The camera-native RGB of the D65 white through the synthetic camera
/// (max-channel-normalised, i.e. ready to be an `AsShotNeutral`).
List<double> get kCamWhiteD65 {
  final v = mulVec(kSyntheticCamera, const [0.95047, 1.0, 1.08883]);
  final m = v.reduce((a, b) => a > b ? a : b);
  return [v[0] / m, v[1] / m, v[2] / m];
}

/// A minimal DNG builder for the colour path: one raw SubIFD (uncompressed
/// 16-bit CFA) + optional colour tags. RATIONAL/SRATIONAL `values` carry
/// packed (numerator, denominator) word pairs — the SRATIONAL sign lives
/// in the numerator word.
Uint8List buildColourDng({
  required int width,
  required int height,
  required List<int> cfaPattern,
  required Uint16List samples, // width×height CFA counts
  List<double>? colorMatrix1,
  List<double>? asShotNeutral,
  int whiteLevel = 65535,
}) {
  const little = Endian.little;
  final strip = Uint8List.view(samples.buffer); // 16-bit LE

  final ifd0Entries = <(int, TiffType, List<int>)>[
    (50706, TiffType.byte, [1, 4, 0, 0]), // DNGVersion 1.4
    (330, TiffType.long, [0]), // SubIFDs → patched
  ];
  final rawEntries = <(int, TiffType, List<int>)>[
    (254, TiffType.long, [0]),
    (256, TiffType.short, [width]),
    (257, TiffType.short, [height]),
    (258, TiffType.short, [16]),
    (259, TiffType.short, [1]), // uncompressed
    (262, TiffType.short, [32803]), // CFA
    (273, TiffType.long, [0]), // patched
    (277, TiffType.short, [1]),
    (278, TiffType.long, [height]),
    (279, TiffType.long, [strip.length]),
    (50707, TiffType.short, [2, 2]),
    (50708, TiffType.short, cfaPattern),
    (50714, TiffType.rational, [0, 1]), // BlackLevel 0/1
    (50717, TiffType.long, [whiteLevel]),
  ];
  if (colorMatrix1 != null) {
    rawEntries.add((
      50721,
      TiffType.srational,
      [for (final v in colorMatrix1) ...[(v * 1e6).round(), 1000000]],
    ));
  }
  if (asShotNeutral != null) {
    rawEntries.add((
      50728,
      TiffType.srational,
      [for (final v in asShotNeutral) ...[(v * 1e6).round(), 1000000]],
    ));
  }

  const headerLen = 8;
  const ifd0Off = headerLen;
  final ifd0Size = 2 + 12 * ifd0Entries.length + 4;
  final rawIfdOff = ifd0Off + ifd0Size;
  final rawIfdSize = 2 + 12 * rawEntries.length + 4;
  final valuesOff = rawIfdOff + rawIfdSize;

  int valueBytes((int, TiffType, List<int>) e) {
    final (_, type, values) = e;
    final len = type.byteSize * values.length;
    return len <= 4 ? 0 : len;
  }

  final valuesSize = [...ifd0Entries, ...rawEntries].map(valueBytes).fold(0, (a, b) => a + b);
  final payloadOff = valuesOff + valuesSize;
  final total = payloadOff + strip.length;
  final bytes = Uint8List(total);
  final bd = ByteData.sublistView(bytes);

  bytes[0] = 0x49;
  bytes[1] = 0x49;
  bd
    ..setUint16(2, 42, little)
    ..setUint32(4, ifd0Off, little);

  var valueCursor = valuesOff;
  void writeIfd(int off, List<(int, TiffType, List<int>)> entries, {int nextIfd = 0}) {
    bd.setUint16(off, entries.length, little);
    var p = off + 2;
    for (final (tag, type, values) in entries) {
      final isRatio = type == TiffType.rational || type == TiffType.srational;
      final count = isRatio ? values.length ~/ 2 : values.length;
      final inline = type.byteSize * count <= 4;
      var valueOffset = p + 8;
      if (!inline) {
        valueOffset = valueCursor;
        for (var i = 0; i < count; i++) {
          switch (type) {
            case TiffType.byte:
              bytes[valueOffset + i] = values[i] & 0xFF;
            case TiffType.short:
              bd.setUint16(valueOffset + i * 2, values[i], little);
            case TiffType.long:
              bd.setUint32(valueOffset + i * 4, values[i], little);
            case TiffType.rational:
              bd
                ..setUint32(valueOffset + i * 8, values[i * 2], little)
                ..setUint32(valueOffset + i * 8 + 4, values[i * 2 + 1], little);
            case TiffType.srational:
              bd
                ..setUint32(valueOffset + i * 8, values[i * 2] & 0xFFFFFFFF, little)
                ..setUint32(valueOffset + i * 8 + 4, values[i * 2 + 1], little);
            default:
              throw ArgumentError('builder: unsupported type $type');
          }
        }
        valueCursor += type.byteSize * count;
      }
      bd
        ..setUint16(p, tag, little)
        ..setUint16(p + 2, type.id, little)
        ..setUint32(p + 4, count, little)
        ..setUint32(p + 8, valueOffset, little);
      if (inline) {
        for (var i = 0; i < count; i++) {
          switch (type) {
            case TiffType.byte:
              bytes[valueOffset + i] = values[i] & 0xFF;
            case TiffType.short:
              bd.setUint16(valueOffset + i * 2, values[i], little);
            case TiffType.long:
              bd.setUint32(valueOffset + i * 4, values[i], little);
            default:
              throw ArgumentError('builder: unsupported inline type $type');
          }
        }
      }
      p += 12;
    }
    bd.setUint32(p, nextIfd, little);
  }

  void patchIfd(int ifdOff, int tag, List<int> values) {
    final n = bd.getUint16(ifdOff, little);
    var p = ifdOff + 2;
    for (var i = 0; i < n; i++, p += 12) {
      if (bd.getUint16(p, little) == tag) {
        for (var j = 0; j < values.length; j++) {
          bd.setUint32(p + 8 + j * 4, values[j], little);
        }
        return;
      }
    }
    fail('patch: tag $tag not found');
  }

  writeIfd(ifd0Off, ifd0Entries);
  writeIfd(rawIfdOff, rawEntries);
  patchIfd(ifd0Off, 330, [rawIfdOff]);
  patchIfd(rawIfdOff, 273, [payloadOff]);
  bytes.setRange(payloadOff, payloadOff + strip.length, strip);
  return bytes;
}

String _tmpFile(Uint8List bytes) {
  final dir = Directory('${Directory.systemTemp.path}/lumora_colour_test');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  final f = File('${dir.path}/colour_${DateTime.now().microsecondsSinceEpoch}.dng');
  f.writeAsBytesSync(bytes);
  return f.path;
}

(int, int, int) _readPngCentre(String path) {
  final decoded = img.decodePng(File(path).readAsBytesSync())!;
  final p = decoded.getPixel(decoded.width ~/ 2, decoded.height ~/ 2);
  return (p.r.toInt(), p.g.toInt(), p.b.toInt());
}

/// Per-channel CFA fill: R/G/B positions carry their own count so the
/// demosaiced camera RGB is exactly [vR, vG, vB]/65535 (RGGB layout).
Uint16List fillPerChannel(int w, int h, int vR, int vG, int vB) {
  final out = Uint16List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final c = y.isEven ? (x.isEven ? vR : vG) : (x.isEven ? vG : vB);
      out[y * w + x] = c;
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// tests
// ---------------------------------------------------------------------------

void main() {
  group('invert3x3 + cameraToSrgbLinear', () {
    test('round trip: M · inv(M) = I', () {
      final inv = invert3x3(kSyntheticCamera)!;
      final product = mul3x3(kSyntheticCamera, inv);
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 3; c++) {
          expect(product[r * 3 + c], closeTo(r == c ? 1.0 : 0.0, 1e-9));
        }
      }
    });

    test('singular matrix returns null (no poison)', () {
      expect(invert3x3([0, 0, 0, 0, 0, 0, 0, 0, 0]), isNull);
      expect(invert3x3([1, 2, 3, 2, 4, 6, 0, 0, 1]), isNull); // rank 2
    });

    test('M · [1,1,1] = [1,1,1] — achromatic maps to achromatic', () {
      final m = cameraToSrgbLinear(kSyntheticCamera)!;
      final white = mul3x3Vec(m, [1, 1, 1]);
      // ~1e-4 tolerance: the published Bradford matrix's rows do not sum to
      // exactly 1, so the composed chain carries a sub-1e-3 residual (ΔE ≈ 0,
      // visually exact).
      expect(white[0], closeTo(1, 1e-3));
      expect(white[1], closeTo(1, 1e-3));
      expect(white[2], closeTo(1, 1e-3));
    });

    test('camera response to D65 white lands on sRGB white', () {
      final m = cameraToSrgbLinear(kSyntheticCamera)!;
      final srgb = mul3x3Vec(m, [1.0, 1.0, 1.0]);
      expect(srgb[0], closeTo(1, 1e-3));
      expect(srgb[1], closeTo(1, 1e-3));
      expect(srgb[2], closeTo(1, 1e-3));
    });
  });

  group('renderRawSrgb', () {
    test('no metadata + no recovery == legacy toRgba (bit-for-bit)', () {
      final d = uniformPlanes(0.3, 0.55, 0.8);
      final legacy = toRgba(d);
      final rendered = renderRawSrgb(d, recovery: null);
      expect(rendered.pixels, equals(legacy.pixels));
    });

    test('AsShotNeutral makes the neutral patch exactly grey', () {
      final d = uniformPlanes(0.9, 0.495, 0.648); // 0.9 × [1, 0.55, 0.72]
      final out = renderRawSrgb(
        d,
        asShotNeutral: const [1.0, 0.55, 0.72],
        colorMatrix1: kSyntheticCamera,
        recovery: null,
      );
      final centre = (out.width * (out.height ~/ 2) + out.width ~/ 2) * 4;
      final r = out.pixels[centre];
      final g = out.pixels[centre + 1];
      final b = out.pixels[centre + 2];
      expect(r, inInclusiveRange(235, 250));
      expect(g, r);
      expect(b, r);
    });

    test('singular ColorMatrix degrades to the WB-only path (no throw)', () {
      final d = uniformPlanes(0.5, 0.5, 0.5);
      final out = renderRawSrgb(
        d,
        asShotNeutral: const [1.0, 1.0, 1.0],
        colorMatrix1: const [0, 0, 0, 0, 0, 0, 0, 0, 0],
        recovery: null,
      );
      expect(out.pixels.every((p) => p > 0), isTrue);
    });

    test('D65-white camera patch renders pure white end-to-end', () {
      final neutral = kCamWhiteD65;
      final d = uniformPlanes(neutral[0], neutral[1], neutral[2]);
      final out = renderRawSrgb(
        d,
        asShotNeutral: neutral,
        colorMatrix1: kSyntheticCamera,
        recovery: null,
      );
      final centre = (out.width * (out.height ~/ 2) + out.width ~/ 2) * 4;
      expect(out.pixels[centre], 255);
      expect(out.pixels[centre + 1], 255);
      expect(out.pixels[centre + 2], 255);
    });
  });

  group('highlight recovery', () {
    test('white stays white', () {
      final d = uniformPlanes(1, 1, 1);
      const HighlightRecovery().apply(d);
      expect(d.red[0], closeTo(1.0, 1e-6));
      expect(d.green[0], closeTo(1.0, 1e-6));
      expect(d.blue[0], closeTo(1.0, 1e-6));
    });

    test('sub-threshold pixels untouched', () {
      final d = uniformPlanes(0.4, 0.5, 0.6);
      final r0 = d.red[0];
      final g0 = d.green[0];
      final b0 = d.blue[0];
      final frac = const HighlightRecovery().apply(d);
      expect(frac, 0.0);
      expect(d.red[0], r0);
      expect(d.green[0], g0);
      expect(d.blue[0], b0);
    });

    test('clipped red loses its fringe without going grey', () {
      final d = uniformPlanes(1, 0.4, 0.4);
      final gapBefore = d.red[0] - d.green[0];
      final frac = const HighlightRecovery().apply(d);
      expect(frac, 1.0);
      final gapAfter = d.red[0] - d.green[0];
      expect(gapAfter, lessThan(gapBefore));
      expect(d.red[0], greaterThan(d.green[0]));
      expect(d.red[0], inInclusiveRange(0.0, 1.0));
      expect(d.green[0], inInclusiveRange(0.0, 1.0));
    });

    test('monotone: deeper clip ⇒ luminance brighter or equal', () {
      // The shoulder raises exposure as clipping deepens, while the blend
      // pulls the peak channel toward luminance — so per-channel maxima are
      // not monotone, but scene luminance is.
      double lum(DemosaicResult d) => 0.2126 * d.red[0] + 0.7152 * d.green[0] + 0.0722 * d.blue[0];
      final a = uniformPlanes(0.96, 0.3, 0.3);
      final b = uniformPlanes(1, 0.3, 0.3);
      const HighlightRecovery().apply(a);
      const HighlightRecovery().apply(b);
      expect(lum(b), greaterThanOrEqualTo(lum(a) - 1e-6));
    });

    test('zero strength keeps the pure-clip behaviour (bounded, hue kept)', () {
      final d = uniformPlanes(1, 0.3, 0.2);
      const pure = HighlightRecovery(strength: 0);
      pure.apply(d);
      expect(d.red[0], closeTo(1.0, 1e-6));
      expect(d.red[0], greaterThan(d.green[0]));
    });
  });

  group('SRATIONAL sign fix (tiff parser)', () {
    test('negative ColorMatrix coefficients survive the parser', () {
      final bytes = buildColourDng(
        width: 4,
        height: 4,
        cfaPattern: const [0, 1, 1, 2],
        samples: Uint16List(16),
        colorMatrix1: const [-0.7, 0.2, 0.5, 0.1, -0.9, 0.8, 0.3, 0.15, -0.45],
        asShotNeutral: const [1.0, 0.55, 0.72],
      );
      final doc = parseDng(bytes);
      expect(doc.cfa.hasColourMetadata, isTrue);
      expect(doc.cfa.colorMatrix1[0], closeTo(-0.7, 1e-9));
      expect(doc.cfa.colorMatrix1[4], closeTo(-0.9, 1e-9));
      expect(doc.cfa.colorMatrix1[8], closeTo(-0.45, 1e-9));
      expect(doc.cfa.asShotNeutral[1], closeTo(0.55, 1e-9));
    });
  });

  group('end-to-end colour DNG (M2-4)', () {
    test('the shot white renders as equal channels (camera-neutral)', () async {
      const neutral = [1.0, 0.55, 0.72];
      const k = 0.9;
      final samples = fillPerChannel(
        8,
        8,
        (k * neutral[0] * 65535).round(),
        (k * neutral[1] * 65535).round(),
        (k * neutral[2] * 65535).round(),
      );
      final bytes = buildColourDng(
        width: 8,
        height: 8,
        cfaPattern: const [0, 1, 1, 2],
        samples: samples,
        colorMatrix1: kSyntheticCamera,
        asShotNeutral: neutral,
      );
      final result = await importDng(_tmpFile(bytes));
      expect(result, isA<RawImportSuccess>());
      final success = result as RawImportSuccess;
      expect(success.fromPreview, isFalse);
      final (r, g, b) = _readPngCentre(success.path);
      expect((r - g).abs(), lessThanOrEqualTo(1));
      expect((g - b).abs(), lessThanOrEqualTo(1));
      expect(r, inInclusiveRange(235, 250));
    });

    test('colour matrix visibly shifts a camera patch (not identity)', () async {
      const neutral = [1.0, 0.55, 0.72];
      final samples = fillPerChannel(
        8,
        8,
        (0.9 * 65535).round(),
        (0.2 * 65535).round(),
        (0.15 * 65535).round(),
      );
      final withMatrix = buildColourDng(
        width: 8,
        height: 8,
        cfaPattern: const [0, 1, 1, 2],
        samples: samples,
        colorMatrix1: kSyntheticCamera,
        asShotNeutral: neutral,
      );
      final withoutMatrix = buildColourDng(
        width: 8,
        height: 8,
        cfaPattern: const [0, 1, 1, 2],
        samples: samples,
        asShotNeutral: neutral,
      );
      final a = await importDng(_tmpFile(withMatrix));
      final b = await importDng(_tmpFile(withoutMatrix));
      final (ra, _, _) = _readPngCentre((a as RawImportSuccess).path);
      final (rb, _, _) = _readPngCentre((b as RawImportSuccess).path);
      expect(ra != rb, isTrue, reason: 'colour matrix must change the render');
    });

    test('absent colour tags keep the legacy identity render', () async {
      final samples = fillPerChannel(8, 8, 40000, 20000, 10000);
      final bytes = buildColourDng(
        width: 8,
        height: 8,
        cfaPattern: const [0, 1, 1, 2],
        samples: samples,
      );
      final doc = parseDng(bytes);
      expect(doc.cfa.hasColourMetadata, isFalse);
      final result = await importDng(_tmpFile(bytes));
      expect(result, isA<RawImportSuccess>());
    });
  });
}
