/// Wave 2 W2 tests: TIFF parser, DNG document semantics, CFA decoder and
/// the full import path — synthetic DNGs built byte-by-byte, plus the
/// malformed-input fuzz cases from the roadmap's acceptance gate.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumora/features/photo_editor/domain/raw/dng_decoder.dart';
import 'package:lumora/features/photo_editor/domain/raw/dng_document.dart';
import 'package:lumora/features/photo_editor/domain/raw/raw_import.dart';
import 'package:lumora/features/photo_editor/domain/raw/tiff_parser.dart';

/// A simple flat builder: writes header + IFDs + data blocks in one pass,
/// patching offsets at the end.
Uint8List buildDng({
  required int rawWidth,
  required int rawHeight,
  required List<int> cfaPattern,
  List<int>? activeArea,
  double blackLevel = 0,
  int whiteLevel = 65535,
  int bitsPerSample = 16,
  int compressionId = 1, // 1 uncompressed, 8 deflate, 7 lossless JPEG
  List<int>? stripData,
  int? rowsPerStrip,
  bool withPreview = false,
  List<int>? previewJpeg,
  List<int>? dngVersion,
  bool cfaPhotometric = true,
}) {
  final data = stripData ??
      List.filled(rawWidth * rawHeight * (bitsPerSample == 8 ? 1 : 2), 0x40);
  final rps = rowsPerStrip ?? rawHeight;
  const little = Endian.little;

  // --- collect variable-size blobs first to compute offsets -------------

  // Strip payload (possibly deflate-compressed).
  var payload = Uint8List.fromList(data);
  if (compressionId == 8) {
    payload = Uint8List.fromList(ZLibEncoder().convert(data));
  }

  // JPEG preview payload.
  var jpeg = previewJpeg ?? const [];
  if (withPreview && jpeg.isEmpty) {
    final probe = img.Image(width: 4, height: 4);
    jpeg = img.encodeJpg(probe, quality: 80);
  }

  // --- IFD0 entries ------------------------------------------------------
  final ifd0Entries = <(int, int, List<int>)>[
    (50706, TiffType.byte.id, dngVersion ?? [1, 4, 0, 0]), // DNGVersion
    (254, TiffType.long.id, [0]), // NewSubfileType (full-res)
    (256, TiffType.short.id, [rawWidth]), // ImageWidth
    (257, TiffType.short.id, [rawHeight]), // ImageLength
    (258, TiffType.short.id, [bitsPerSample]), // BitsPerSample
    (259, TiffType.short.id, [7]), // Compression (JPEG preview)
    (262, TiffType.short.id, [2]), // Photometric RGB
    (273, TiffType.long.id, [0]), // StripOffsets (patched)
    (277, TiffType.short.id, [1]), // SamplesPerPixel
    (278, TiffType.long.id, [rawHeight]), // RowsPerStrip
    (279, TiffType.long.id, [jpeg.length]), // StripByteCounts (patched)
    (330, TiffType.long.id, [0]), // SubIFDs (patched)
  ];

  // --- Raw SubIFD entries ------------------------------------------------
  final rawEntries = <(int, int, List<int>)>[
    (254, TiffType.long.id, [0]),
    (256, TiffType.short.id, [rawWidth]),
    (257, TiffType.short.id, [rawHeight]),
    (258, TiffType.short.id, [bitsPerSample]),
    (259, TiffType.short.id, [compressionId]),
    (262, TiffType.short.id, [cfaPhotometric ? 32803 : 2]), // CFA
    (273, TiffType.long.id, [0]), // StripOffsets (patched)
    (277, TiffType.short.id, [1]), // SamplesPerPixel
    (278, TiffType.long.id, [rps]),
    (279, TiffType.long.id, [payload.length]), // StripByteCounts
    (50707, TiffType.short.id, [2, 2]), // CFARepeatPatternDim
    (50708, TiffType.short.id, cfaPattern), // CFAPattern
    if (activeArea != null) (50829, TiffType.long.id, activeArea), // ActiveArea
    (50714, TiffType.rational.id, [0]), // BlackLevel as rational 0/1
    (50717, TiffType.long.id, [whiteLevel]), // WhiteLevel
  ];

  // --- preview IFD (non-raw, JPEG) ---------------------------------------
  final previewEntries = <(int, int, List<int>)>[
    (254, TiffType.long.id, [1]), // ReducedResolution
    (256, TiffType.short.id, [4]),
    (257, TiffType.short.id, [4]),
    (258, TiffType.short.id, [8]),
    (259, TiffType.short.id, [7]),
    (262, TiffType.short.id, [2]),
    (273, TiffType.long.id, [0]), // patched
    (277, TiffType.short.id, [1]),
    (278, TiffType.long.id, [4]),
    (279, TiffType.long.id, [jpeg.length]), // patched
  ];

  // Compute serialized sizes to lay out the file.
  int ifdSize(List<(int, int, List<int>)> entries) => 2 + 12 * entries.length + 4;

  int entryValueSize(int typeId, List<int> values) {
    final type = TiffType.fromId(typeId)!;
    final len = type.byteSize * values.length;
    return len <= 4 ? 0 : len; // 0 = inline
  }

  final ifd0Size = ifdSize(ifd0Entries);
  final rawSize = ifdSize(rawEntries);
  final previewSize = ifdSize(previewEntries);
  final valuesSize =
      ifd0Entries.map((e) => entryValueSize(e.$2, e.$3)).fold<int>(0, (a, b) => a + b) +
          rawEntries.map((e) => entryValueSize(e.$2, e.$3)).fold<int>(0, (a, b) => a + b) +
          previewEntries.map((e) => entryValueSize(e.$2, e.$3)).fold<int>(0, (a, b) => a + b);

  const headerLen = 8;
  const ifd0Off = headerLen;
  final valuesOff = ifd0Off + ifd0Size;
  final rawIfdOff = valuesOff + valuesSize;
  final previewIfdOff = rawIfdOff + rawSize;
  final payloadOff = previewIfdOff + previewSize;
  final jpegOff = payloadOff + payload.length;

  final total = jpegOff + jpeg.length;
  final bytes = Uint8List(total);

  // Header
  bytes[0] = 0x49;
  bytes[1] = 0x49;
  ByteData.sublistView(bytes)
    ..setUint16(2, 42, little)
    ..setUint32(4, ifd0Off, little);

  var valueCursor = valuesOff;
  int writeIfd(int ifdOff, List<(int, int, List<int>)> entries, {int nextIfd = 0}) {
    final bd = ByteData.sublistView(bytes);
    bd.setUint16(ifdOff, entries.length, little);
    var p = ifdOff + 2;
    for (final (tag, typeId, values) in entries) {
      final type = TiffType.fromId(typeId)!;
      final inline = type.byteSize * values.length <= 4;
      var valueOffset = p + 8;
      if (!inline) {
        valueOffset = valueCursor;
        for (var i = 0; i < values.length; i++) {
          switch (type) {
            case TiffType.byte || TiffType.undefined || TiffType.ascii:
              bytes[valueOffset + i] = values[i] & 0xFF;
            case TiffType.short || TiffType.sshort:
              bd.setUint16(valueOffset + i * 2, values[i], little);
            case TiffType.long || TiffType.slong:
              bd.setUint32(valueOffset + i * 4, values[i], little);
            case TiffType.rational:
              bd.setUint32(valueOffset + i * 8, values[i], little);
              bd.setUint32(valueOffset + i * 8 + 4, 1, little);
            default:
              throw ArgumentError('fixture: unsupported type $type');
          }
        }
        valueCursor += type.byteSize * values.length;
      }
      bd
        ..setUint16(p, tag, little)
        ..setUint16(p + 2, typeId, little)
        ..setUint32(p + 4, values.length, little)
        ..setUint32(p + 8, valueOffset, little);
      if (inline) {
        // The header write above stores valueOffset in the value field;
        // inline entries keep the VALUE there instead — write it last.
        for (var i = 0; i < values.length; i++) {
          switch (type) {
            case TiffType.byte || TiffType.undefined || TiffType.ascii:
              bytes[valueOffset + i] = values[i] & 0xFF;
            case TiffType.short || TiffType.sshort:
              bd.setUint16(valueOffset + i * 2, values[i], little);
            case TiffType.long || TiffType.slong:
              bd.setUint32(valueOffset + i * 4, values[i], little);
            default:
              throw ArgumentError('fixture: unsupported inline type $type');
          }
        }
      }
      p += 12;
    }
    bd.setUint32(p, nextIfd, little);
    return p + 4; // offset of the "next IFD" field for later patching
  }

  writeIfd(ifd0Off, ifd0Entries);
  writeIfd(rawIfdOff, rawEntries);
  writeIfd(previewIfdOff, previewEntries);

  // Payloads
  bytes.setRange(payloadOff, payloadOff + payload.length, payload);
  if (jpeg.isNotEmpty) {
    bytes.setRange(jpegOff, jpegOff + jpeg.length, jpeg);
  }

  // Patch offsets (direct writes, all LONG inline values at known entries).
  final bd = ByteData.sublistView(bytes);
  void patchEntry(int ifdOff, int tag, List<int> values) {
    var p = ifdOff + 2;
    final n = bd.getUint16(ifdOff, little);
    for (var i = 0; i < n; i++, p += 12) {
      if (bd.getUint16(p, little) == tag) {
        final pb = ByteData.sublistView(bytes, p + 8, p + 12);
        for (var i = 0; i < values.length; i++) {
          pb.setUint32(i * 4, values[i], little);
        }
        return;
      }
    }
    fail('patch: tag $tag not found in IFD at $ifdOff');
  }

  patchEntry(ifd0Off, 330, [rawIfdOff]); // SubIFDs → raw
  patchEntry(ifd0Off, 273, [jpegOff]); // IFD0 strip = preview JPEG
  patchEntry(ifd0Off, 279, [jpeg.length]);
  patchEntry(rawIfdOff, 273, [payloadOff]);
  if (withPreview) {
    patchEntry(previewIfdOff, 273, [jpegOff]);
    patchEntry(previewIfdOff, 279, [jpeg.length]);
  }
  return bytes;
}

Uint8List _strip16(int width, int height, int Function(int x, int y) at) {
  final out = Uint16List(width * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      out[y * width + x] = at(x, y);
    }
  }
  return Uint8List.view(out.buffer);
}

void main() {
  // ---------------------------------------------------------------- parse
  group('TiffDocument.parse', () {
    test('rejects non-TIFF magic', () {
      final bad = Uint8List.fromList([0x49, 0x49, 0x2A, 0x00, 0, 0, 0, 0, 1, 2, 3]);
      bad[1] = 0x58; // break the order marker
      expect(() => TiffDocument.parse(bad), throwsA(isA<TiffFormatException>()));
    });

    test('rejects files smaller than the header', () {
      expect(() => TiffDocument.parse(Uint8List(4)), throwsA(isA<TiffFormatException>()));
    });

    test('rejects an IFD offset out of range', () {
      final bytes = Uint8List(16);
      final bd = ByteData.sublistView(bytes);
      bytes[0] = 0x49;
      bytes[1] = 0x49;
      bd
        ..setUint16(2, 42, Endian.little)
        ..setUint32(4, 9000, Endian.little);
      expect(() => TiffDocument.parse(bytes), throwsA(isA<TiffFormatException>()));
    });

    test('rejects an unknown entry type without crashing', () {
      final bytes = Uint8List(64);
      final bd = ByteData.sublistView(bytes);
      bytes[0] = 0x49;
      bytes[1] = 0x49;
      bd
        ..setUint16(2, 42, Endian.little)
        ..setUint32(4, 8, Endian.little)
        ..setUint16(8, 1, Endian.little) // 1 entry
        ..setUint16(10, 256, Endian.little) // tag
        ..setUint16(12, 99, Endian.little) // unknown type
        ..setUint32(14, 1, Endian.little)
        ..setUint32(18, 0, Endian.little);
      expect(() => TiffDocument.parse(bytes), throwsA(isA<TiffFormatException>()));
    });
  });

  // -------------------------------------------------------------- parseDng
  group('parseDng', () {
    test('classifies the CFA IFD and finds the preview', () {
      final bytes = buildDng(rawWidth: 4, rawHeight: 6, cfaPattern: [0, 1, 1, 2], withPreview: true);
      final doc = parseDng(bytes);
      expect(doc.cfa.width, 4);
      expect(doc.cfa.height, 6);
      expect(doc.cfa.bitsPerSample, 16);
      expect(doc.cfa.compression, RawCompression.uncompressed);
      expect(doc.cfa.pattern, [
        [0, 1],
        [1, 2],
      ]);
      expect(doc.cfa.whiteLevel, 65535);
      expect(doc.cfa.isDirectlyDecodable, isTrue);
      expect(doc.previews, hasLength(1));
      expect(doc.bestPreview!.width, 4);
    });

    test('active area is carried through', () {
      final bytes = buildDng(rawWidth: 8, rawHeight: 8, cfaPattern: [0, 1, 1, 2], activeArea: [1, 1, 7, 7]);
      final doc = parseDng(bytes);
      expect(doc.cfa.activeArea, [1, 1, 7, 7]);
    });

    test('lossless JPEG compression is recorded, not rejected, by the document layer', () {
      final bytes = buildDng(rawWidth: 4, rawHeight: 4, cfaPattern: [0, 1, 1, 2], compressionId: 7);
      final doc = parseDng(bytes);
      expect(doc.cfa.compression, RawCompression.losslessJpeg);
      expect(doc.cfa.isDirectlyDecodable, isFalse);
      // ...and the decoder is the one that rejects raw pixel decoding:
      expect(() => decodeCfa(bytes, doc), throwsA(isA<RawUnsupportedException>()));
    });

    test('unknown compression ids are recorded as unknown', () {
      final bytes = buildDng(rawWidth: 4, rawHeight: 4, cfaPattern: [0, 1, 1, 2], compressionId: 42);
      final doc = parseDng(bytes);
      expect(doc.cfa.compression, RawCompression.unknown);
    });
  });

  // ------------------------------------------------------------ decodeCfa
  group('decodeCfa + demosaic + toRgba', () {
    test('uncompressed strips decode to the exact Bayer values', () {
      const w = 4;
      const h = 6;
      final strip = _strip16(w, h, (x, y) => (x + y * w) % 65536);
      final bytes = buildDng(rawWidth: w, rawHeight: h, cfaPattern: [0, 1, 1, 2], stripData: strip);
      final doc = parseDng(bytes);
      final bayer = decodeCfa(bytes, doc);
      expect(bayer.width, w);
      expect(bayer.height, h);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          expect(bayer.at(x, y), (x + y * w) % 65536, reason: 'at ($x,$y)');
        }
      }
    });

    test('Adobe-deflate strips inflate back to the same values', () {
      const w = 4;
      const h = 4;
      final raw = _strip16(w, h, (x, y) => 1000 + x * 7 + y * 113);
      final bytes = buildDng(
        rawWidth: w,
        rawHeight: h,
        cfaPattern: [0, 1, 1, 2],
        compressionId: 8,
        stripData: raw,
      );
      final doc = parseDng(bytes);
      expect(doc.cfa.compression, RawCompression.deflateAdobe);
      final bayer = decodeCfa(bytes, doc);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          expect(bayer.at(x, y), 1000 + x * 7 + y * 113);
        }
      }
    });

    test('ActiveArea crops the sensor frame', () {
      const w = 8;
      const h = 8;
      final strip = _strip16(w, h, (x, y) => (x * 100 + y) & 0xFFFF);
      final bytes = buildDng(
        rawWidth: w,
        rawHeight: h,
        cfaPattern: [0, 1, 1, 2],
        activeArea: [2, 1, 6, 5], // top, left, bottom, right
        stripData: strip,
      );
      final doc = parseDng(bytes);
      final bayer = decodeCfa(bytes, doc);
      expect(bayer.width, 4);
      expect(bayer.height, 4);
      expect(bayer.at(0, 0), (1 * 100 + 2) & 0xFFFF); // (x=1, y=2)
    });

    test('demosaic of a uniform sensor yields a uniform colour', () {
      const w = 4;
      const h = 4;
      final strip = _strip16(w, h, (_, _) => 32768);
      final bytes = buildDng(rawWidth: w, rawHeight: h, cfaPattern: [0, 1, 1, 2], stripData: strip);
      final doc = parseDng(bytes);
      final bayer = decodeCfa(bytes, doc);
      final d = demosaicBilinear(bayer, doc.cfa.pattern, doc.cfa.blackLevel, doc.cfa.whiteLevel);
      // 32768 / 65535 ≈ 0.5 everywhere on every plane.
      expect(d.red, everyElement(closeTo(0.5, 0.001)));
      expect(d.green, everyElement(closeTo(0.5, 0.001)));
      expect(d.blue, everyElement(closeTo(0.5, 0.001)));
      final rgba = toRgba(d);
      expect(rgba.width, w);
      expect(rgba.height, h);
      // sRGB(0.5) ≈ 188.
      expect(rgba.pixels[0], inExclusiveRange(180, 200));
      expect(rgba.pixels[3], 255);
    });

    test('strip out of bounds raises (fuzz gate)', () {
      final bytes = buildDng(rawWidth: 4, rawHeight: 4, cfaPattern: [0, 1, 1, 2]);
      // Truncate the payload half-way.
      final cut = Uint8List.sublistView(bytes, 0, bytes.length - 20);
      final doc = parseDng(cut);
      expect(() => decodeCfa(cut, doc), throwsA(isA<TiffFormatException>()));
    });
  });

  // ------------------------------------------------------------ importDng
  group('importDng (full path)', () {
    test('a decodable DNG opens as a full decode', () async {
      const w = 4;
      const h = 4;
      final strip = _strip16(w, h, (x, y) => 20000 + x * 500);
      final bytes = buildDng(rawWidth: w, rawHeight: h, cfaPattern: [0, 1, 1, 2], stripData: strip);
      final tmp = Directory.systemTemp.createTempSync('lumora_raw_test');
      final file = File('${tmp.path}/shot.dng')..writeAsBytesSync(bytes);
      addTearDown(() => tmp.deleteSync(recursive: true));

      final result = await importDng(file.path);
      expect(result, isA<RawImportSuccess>());
      final success = result as RawImportSuccess;
      expect(success.fromPreview, isFalse);
      expect(success.width, w);
      expect(success.height, h);
      expect(File(success.path).existsSync(), isTrue);
    });

    test('lossless JPEG DNG falls back to the embedded preview honestly', () async {
      const w = 4;
      const h = 4;
      final bytes = buildDng(
        rawWidth: w,
        rawHeight: h,
        cfaPattern: [0, 1, 1, 2],
        compressionId: 7, // lossless JPEG raw
        withPreview: true,
      );
      final tmp = Directory.systemTemp.createTempSync('lumora_raw_test');
      final file = File('${tmp.path}/phone.dng')..writeAsBytesSync(bytes);
      addTearDown(() => tmp.deleteSync(recursive: true));

      final result = await importDng(file.path);
      expect(result, isA<RawImportSuccess>());
      final success = result as RawImportSuccess;
      expect(success.fromPreview, isTrue);
      expect(success.reason, contains('lossless JPEG'));
    });

    test('a garbage file fails with a plain message', () async {
      final tmp = Directory.systemTemp.createTempSync('lumora_raw_test');
      final file = File('${tmp.path}/junk.dng')..writeAsBytesSync(Uint8List.fromList(List.filled(64, 7)));
      addTearDown(() => tmp.deleteSync(recursive: true));
      final result = await importDng(file.path);
      expect(result, isA<RawImportFailure>());
    });

    test('looksLikeDng sniffs real TIFF headers only', () {
      expect(looksLikeDng(Uint8List.fromList([0x49, 0x49, 0x2A, 0x00])), isTrue);
      expect(looksLikeDng(Uint8List.fromList([0x4D, 0x4D, 0x00, 0x2A])), isTrue);
      expect(looksLikeDng(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0])), isFalse); // JPEG
      expect(looksLikeDng(Uint8List(2)), isFalse);
    });
  });
}
