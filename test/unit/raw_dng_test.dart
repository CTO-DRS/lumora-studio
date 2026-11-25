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
import 'package:lumora/features/photo_editor/domain/raw/lossless_jpeg.dart';
import 'package:lumora/features/photo_editor/domain/raw/raw_import.dart';
import 'package:lumora/features/photo_editor/domain/raw/tiff_parser.dart';
import 'package:lumora/features/photo_editor/domain/raw/tiff_writer.dart';

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
  List<int>? stripSplits, // byte length of each strip (multi-strip raws)
  bool withPreview = false,
  List<int>? previewJpeg,
  List<int>? dngVersion,
  bool cfaPhotometric = true,
}) {
  final data = stripData ?? List.filled(rawWidth * rawHeight * (bitsPerSample == 8 ? 1 : 2), 0x40);
  final rps = rowsPerStrip ?? rawHeight;
  const little = Endian.little;

  // --- strip payloads -----------------------------------------------------
  var full = Uint8List.fromList(data);
  if (compressionId == 8) {
    full = Uint8List.fromList(ZLibEncoder().convert(data));
  }
  final List<Uint8List> stripPayloads;
  if (stripSplits != null && stripSplits.length > 1) {
    stripPayloads = [];
    var cursor = 0;
    for (final len in stripSplits) {
      stripPayloads.add(Uint8List.sublistView(full, cursor, cursor + len));
      cursor += len;
    }
  } else {
    stripPayloads = [full];
  }

  // Strip offsets (payload-relative for now — rebased to absolute after
  // the layout below; the entries hold a reference to this same list).
  final stripOffsets = <int>[];
  var stripAcc = 0;
  for (final sp in stripPayloads) {
    stripOffsets.add(stripAcc);
    stripAcc += sp.length;
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
    (273, TiffType.long.id, stripOffsets), // StripOffsets (real values)
    (277, TiffType.short.id, [1]), // SamplesPerPixel
    (278, TiffType.long.id, [rps]),
    (279, TiffType.long.id, [for (final sp in stripPayloads) sp.length]), // StripByteCounts
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
  // Rebase the payload-relative strip offsets to absolute file offsets.
  for (var i = 0; i < stripOffsets.length; i++) {
    stripOffsets[i] += payloadOff;
  }
  final jpegOff = payloadOff + full.length;

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
  for (var i = 0; i < stripPayloads.length; i++) {
    bytes.setRange(stripOffsets[i], stripOffsets[i] + stripPayloads[i].length, stripPayloads[i]);
  }
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
  if (withPreview) {
    patchEntry(previewIfdOff, 273, [jpegOff]);
    patchEntry(previewIfdOff, 279, [jpeg.length]);
  }
  return bytes;
}

Uint16List _strip16(int width, int height, int Function(int x, int y) at) {
  final out = Uint16List(width * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      out[y * width + x] = at(x, y);
    }
  }
  return out;
}

/// Byte (little-endian) view of a sample plane, for raw strip payloads.
Uint8List _bytes16(Uint16List plane) => Uint8List.view(plane.buffer);

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
      expect(doc.cfa.isDirectlyDecodable, isTrue);
      // The fixture's strip payload is not valid lossless JPEG, so the
      // decoder raises a bounded format error (wrapped as TIFF failure):
      expect(() => decodeCfa(bytes, doc), throwsA(isA<TiffFormatException>()));
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
      final bytes = buildDng(rawWidth: w, rawHeight: h, cfaPattern: [0, 1, 1, 2], stripData: _bytes16(strip));
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
        stripData: _bytes16(raw),
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
        stripData: _bytes16(strip),
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
      final bytes = buildDng(rawWidth: w, rawHeight: h, cfaPattern: [0, 1, 1, 2], stripData: _bytes16(strip));
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
      final bytes = buildDng(rawWidth: w, rawHeight: h, cfaPattern: [0, 1, 1, 2], stripData: _bytes16(strip));
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

    test('a broken lossless-JPEG DNG falls back to the embedded preview honestly', () async {
      const w = 4;
      const h = 4;
      final bytes = buildDng(
        rawWidth: w,
        rawHeight: h,
        cfaPattern: [0, 1, 1, 2],
        compressionId: 7, // lossless JPEG raw — but the strip payload is garbage
        withPreview: true,
      );
      final tmp = Directory.systemTemp.createTempSync('lumora_raw_test');
      final file = File('${tmp.path}/phone.dng')..writeAsBytesSync(bytes);
      addTearDown(() => tmp.deleteSync(recursive: true));

      final result = await importDng(file.path);
      expect(result, isA<RawImportSuccess>());
      final success = result as RawImportSuccess;
      expect(success.fromPreview, isTrue);
      expect(success.reason, contains('raw decode failed'));
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

  // ------------------------------------------- lossless JPEG (M2-2) strips
  group('lossless JPEG raw strips (M2-2)', () {
    test('predictor 1 round-trips exact sensor values', () {
      const w = 8;
      const h = 5;
      final samples = _strip16(w, h, (x, y) => (5000 + x * 311 + y * 97) & 0xFFFF);
      final jpeg = _encodeLosslessJpeg(width: w, height: h, precision: 16, samples: samples, predictor: 1);
      final bytes = buildDng(rawWidth: w, rawHeight: h, cfaPattern: [0, 1, 1, 2], compressionId: 7, stripData: jpeg);
      final doc = parseDng(bytes);
      final bayer = decodeCfa(bytes, doc);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          expect(bayer.at(x, y), (5000 + x * 311 + y * 97) & 0xFFFF, reason: 'at ($x,$y)');
        }
      }
    });

    test('predictor 5 (mixed Ra/Rb/Rc) round-trips', () {
      const w = 6;
      const h = 6;
      final samples = _strip16(w, h, (x, y) => 32768 + ((x * 137) ^ (y * 89)) % 8192 - 4096);
      final jpeg = _encodeLosslessJpeg(width: w, height: h, precision: 16, samples: samples, predictor: 5);
      final bytes = buildDng(rawWidth: w, rawHeight: h, cfaPattern: [0, 1, 1, 2], compressionId: 7, stripData: jpeg);
      final doc = parseDng(bytes);
      final bayer = decodeCfa(bytes, doc);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          expect(bayer.at(x, y), 32768 + ((x * 137) ^ (y * 89)) % 8192 - 4096, reason: 'at ($x,$y)');
        }
      }
    });

    test('8-bit precision round-trips', () {
      const w = 4;
      const h = 4;
      final samples = Uint16List.fromList([for (var y = 0; y < h; y++) for (var x = 0; x < w; x++) (x * 40 + y * 17) % 256]);
      final jpeg = _encodeLosslessJpeg(width: w, height: h, precision: 8, samples: samples, predictor: 1);
      final bytes = buildDng(
        rawWidth: w,
        rawHeight: h,
        cfaPattern: [0, 1, 1, 2],
        compressionId: 7,
        stripData: jpeg,
        bitsPerSample: 8,
      );
      final doc = parseDng(bytes);
      final bayer = decodeCfa(bytes, doc);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          expect(bayer.at(x, y), (x * 40 + y * 17) % 256, reason: 'at ($x,$y)');
        }
      }
    });

    test('restart intervals decode correctly (DRI + RSTn)', () {
      const w = 8;
      const h = 4;
      final samples = _strip16(w, h, (x, y) => (20000 + x * 512 + y * 129) & 0xFFFF);
      final jpeg = _encodeLosslessJpeg(width: w, height: h, precision: 16, samples: samples, predictor: 1, restartInterval: 5);
      final bytes = buildDng(rawWidth: w, rawHeight: h, cfaPattern: [0, 1, 1, 2], compressionId: 7, stripData: jpeg);
      final doc = parseDng(bytes);
      final bayer = decodeCfa(bytes, doc);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          expect(bayer.at(x, y), (20000 + x * 512 + y * 129) & 0xFFFF, reason: 'at ($x,$y)');
        }
      }
    });

    test('multi-strip lossless JPEG DNG (one complete JPEG per strip)', () {
      const w = 4;
      const h = 6;
      final samples = _strip16(w, h, (x, y) => (100 + y * w + x) & 0xFFFF);
      final strips = <int>[];
      final stripSplits = <int>[];
      for (var s = 0; s < 3; s++) {
        final sub = Uint16List(w * 2);
        for (var r = 0; r < 2; r++) {
          for (var x = 0; x < w; x++) {
            sub[r * w + x] = samples[(s * 2 + r) * w + x];
          }
        }
        final jpg = _encodeLosslessJpeg(width: w, height: 2, precision: 16, samples: sub, predictor: 1);
        stripSplits.add(jpg.length);
        strips.addAll(jpg);
      }
      final bytes = buildDng(
        rawWidth: w,
        rawHeight: h,
        cfaPattern: [0, 1, 1, 2],
        compressionId: 7,
        stripData: strips,
        stripSplits: stripSplits,
        rowsPerStrip: 2,
      );
      final doc = parseDng(bytes);
      final bayer = decodeCfa(bytes, doc);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          expect(bayer.at(x, y), (100 + y * w + x) & 0xFFFF, reason: 'at ($x,$y)');
        }
      }
    });

    test('truncated entropy raises a bounded format error (fuzz gate)', () {
      const w = 8;
      const h = 5;
      final samples = _strip16(w, h, (x, y) => 4000 + x * 13);
      final jpeg = _encodeLosslessJpeg(width: w, height: h, precision: 16, samples: samples, predictor: 1);
      final cut = Uint8List.sublistView(jpeg, 0, jpeg.length - 6);
      expect(() => decodeLosslessJpeg(cut), throwsA(isA<LosslessJpegFormatException>()));
    });

    test('a full lossless-JPEG DNG opens end-to-end via importDng', () async {
      const w = 4;
      const h = 4;
      final samples = _strip16(w, h, (x, y) => 30000 + x * 777);
      final jpeg = _encodeLosslessJpeg(width: w, height: h, precision: 16, samples: samples, predictor: 1);
      final bytes = buildDng(rawWidth: w, rawHeight: h, cfaPattern: [0, 1, 1, 2], compressionId: 7, stripData: jpeg);
      final tmp = Directory.systemTemp.createTempSync('lumora_raw_test');
      final file = File('${tmp.path}/shot_phone.dng')..writeAsBytesSync(bytes);
      addTearDown(() => tmp.deleteSync(recursive: true));

      final result = await importDng(file.path);
      expect(result, isA<RawImportSuccess>());
      final success = result as RawImportSuccess;
      expect(success.fromPreview, isFalse);
      expect(success.width, w);
      expect(success.height, h);
    });
  });

  // ------------------------------------------------ tiff16 export (M2-3)
  group('16-bit TIFF export (M2-3)', () {
    Uint8List rgba(int w, int h, int Function(int x, int y, int c) at) {
      final out = Uint8List(w * h * 4);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final i = (y * w + x) * 4;
          out[i] = at(x, y, 0);
          out[i + 1] = at(x, y, 1);
          out[i + 2] = at(x, y, 2);
          out[i + 3] = 255;
        }
      }
      return out;
    }

    test('round-trips exact 16-bit values through the project parser', () {
      const w = 3;
      const h = 2;
      final pixels = rgba(w, h, (x, y, c) => (x * 61 + y * 37 + c * 23) % 256);
      final file = encodeTiff16(pixels, w, h);
      final doc = TiffDocument.parse(file);
      final ifd = doc.ifds.first;
      expect(ifd.intTag(256), w); // ImageWidth
      expect(ifd.intTag(257), h); // ImageLength
      expect(ifd.intTag(259), 1); // uncompressed
      expect(ifd.intTag(262), 2); // RGB
      expect(ifd.intTag(277), 3); // SamplesPerPixel
      expect(ifd.intList(258), [16, 16, 16]); // BitsPerSample
      expect(ifd.intList(338), [1, 1, 1]); // SampleFormat uint
      expect(ifd.intTag(296), 2); // inch

      // Pixel round-trip: strip bytes are little-endian uint16 = v*257.
      final offsets = ifd.intList(273);
      final counts = ifd.intList(279);
      expect(offsets, hasLength(1));
      final strip = Uint8List.sublistView(file, offsets[0], offsets[0] + counts[0]);
      final view = ByteData.sublistView(strip);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          for (var c = 0; c < 3; c++) {
            final v = view.getUint16(((y * w + x) * 3 + c) * 2, Endian.little);
            expect(v, ((x * 61 + y * 37 + c * 23) % 256) * 257, reason: 'at ($x,$y,$c)');
          }
        }
      }
    });

    test('multi-strip layout keeps every strip readable', () {
      const w = 4;
      const h = 7;
      final pixels = rgba(w, h, (x, y, c) => (x * 3 + y * 11 + c) % 256);
      final file = encodeTiff16(pixels, w, h, stripRowsOverride: 3);
      final doc = TiffDocument.parse(file);
      final ifd = doc.ifds.first;
      final offsets = ifd.intList(273);
      final counts = ifd.intList(279);
      expect(offsets, hasLength(3)); // 7 rows / 3 = [3, 3, 1]
      expect(ifd.intTag(278), 3); // RowsPerStrip

      var row = 0;
      for (var s = 0; s < offsets.length; s++) {
        final strip = Uint8List.sublistView(file, offsets[s], offsets[s] + counts[s]);
        final rows = strip.length ~/ (w * 6);
        final view = ByteData.sublistView(strip);
        for (var r = 0; r < rows; r++, row++) {
          for (var x = 0; x < w; x++) {
            final v = view.getUint16((r * w + x) * 6, Endian.little);
            expect(v, ((x * 3 + row * 11) % 256) * 257, reason: 'at ($x,$row)');
          }
        }
      }
      expect(row, h);
    });

    test('full-range lift is exact at both ends', () {
      final pixels = Uint8List.fromList([0, 0, 0, 255, 255, 255, 255, 255]);
      final file = encodeTiff16(pixels, 2, 1);
      final doc = TiffDocument.parse(file);
      final ifd = doc.ifds.first;
      final offsets = ifd.intList(273);
      final counts = ifd.intList(279);
      final view = ByteData.sublistView(Uint8List.sublistView(file, offsets[0], offsets[0] + counts[0]));
      expect(view.getUint16(0, Endian.little), 0);
      expect(view.getUint16(2, Endian.little), 0);
      expect(view.getUint16(4, Endian.little), 0);
      expect(view.getUint16(6, Endian.little), 65535);
      expect(view.getUint16(8, Endian.little), 65535);
      expect(view.getUint16(10, Endian.little), 65535);
    });
  });
}

/// Minimal lossless (SOF3) JPEG encoder for fixtures — the exact mirror of
/// [decodeLosslessJpeg]: single component, predictor 1-7, 8/16-bit
/// precision, canonical Huffman with tree-shaped (Kraft-complete) code
/// lengths, optional restart intervals.
class _EntropyWriter {
  final List<int> out = <int>[];
  int _acc = 0;
  int _n = 0;

  void bit(int b) {
    _acc = (_acc << 1) | (b & 1);
    if (++_n == 8) {
      _push(_acc);
      _acc = 0;
      _n = 0;
    }
  }

  void bits(int v, int n) {
    for (var i = n - 1; i >= 0; i--) {
      bit((v >> i) & 1);
    }
  }

  void align() {
    while (_n != 0) {
      bit(0);
    }
  }

  void _push(int b) {
    out.add(b);
    if (b == 0xFF) out.add(0x00); // byte stuffing
  }

  void raw(int b) {
    // Marker bytes bypass the bit writer and the stuffing.
    if (_n != 0) align();
    out.add(b);
  }

  List<int> finish() {
    align();
    return out;
  }
}


Uint8List _encodeLosslessJpeg({
  required int width,
  required int height,
  required int precision,
  required Uint16List samples,
  required int predictor,
  int restartInterval = 0,
}) {
  final initValue = 1 << (precision - 1);
  final mask = (1 << precision) - 1;

  int category(int diff) => diff.abs().bitLength; // 0 → 0, 2^k ≤ |d| < 2^(k+1) → k+1

  // Pass 1: diffs + category frequencies.
  final freq = List<int>.filled(17, 0);
  final freshFlags = <bool>[];
  final diffs = <int>[];
  for (var i = 0; i < width * height; i++) {
    final x = i % width;
    final y = i ~/ width;
    final fresh = restartInterval > 0 && i % restartInterval == 0 && i > 0;
    freshFlags.add(fresh);
    int pred;
    if (fresh || (x == 0 && y == 0)) {
      pred = initValue;
    } else if (x == 0) {
      pred = samples[i - width];
    } else if (y == 0) {
      pred = samples[i - 1];
    } else {
      final (ra, rb, rc) = (samples[i - 1], samples[i - width], samples[i - width - 1]);
      pred = switch (predictor) {
        1 => ra,
        2 => rb,
        3 => rc,
        4 => ra + rb - rc,
        5 => ra + ((rb - rc) >> 1),
        6 => rb + ((ra - rc) >> 1),
        7 => (ra + rb) >> 1,
        _ => throw ArgumentError('predictor $predictor'),
      };
    }
    final diff = (samples[i] - pred) & mask;
    final signed = diff > mask ~/ 2 ? diff - (mask + 1) : diff; // interpret as signed
    diffs.add(signed);
    freq[category(signed)]++;
  }

  // Huffman: Kraft-complete length assignment — symbol at rank i gets
  // length i+1, the last two share the final length (sum = 1 exactly).
  // Frequencies only order the symbols (frequent → shorter).
  final symbols = <int>[for (var s = 0; s <= 16; s++) if (freq[s] > 0) s];
  symbols.sort((a, b) => freq[b] - freq[a]);
  final lengthOf = <int, int>{};
  if (symbols.length == 1) {
    lengthOf[symbols[0]] = 1;
  } else {
    for (var i = 0; i < symbols.length; i++) {
      lengthOf[symbols[i]] = i == symbols.length - 1 ? symbols.length - 1 : i + 1;
    }
  }
  // Canonical codes, assigned in (length, symbol) order — exactly the order
  // the DHT lists symbols in, which the decoder replays.
  final codeOf = <int, int>{};
  var code = 0;
  for (var len = 1; len <= 16; len++) {
    final group = symbols.where((s) => lengthOf[s] == len).toList()..sort();
    for (final s in group) {
      codeOf[s] = code;
      code++;
    }
    code <<= 1;
  }

  // Markers.
  final w = _EntropyWriter();
  w.raw(0xFF);
  w.raw(0xD8); // SOI
  w.raw(0xFF);
  w.raw(0xC3); // SOF3
  w.raw(0);
  w.raw(11); // LEN = 8 + 3·1
  w.raw(precision);
  w.raw(height >> 8);
  w.raw(height & 0xFF);
  w.raw(width >> 8);
  w.raw(width & 0xFF);
  w.raw(1); // Ns
  w.raw(1); // component id
  w.raw(0x11); // H=V=1
  w.raw(predictor << 4); // predictor + Pt=0

  w.raw(0xFF);
  w.raw(0xC4); // DHT
  w.raw(0);
  w.raw(3 + 16 + symbols.length); // LEN
  w.raw(0x00); // class 0, id 0
  for (var len = 1; len <= 16; len++) {
    w.raw(symbols.where((s) => lengthOf[s] == len).length);
  }
  for (var len = 1; len <= 16; len++) {
    symbols.where((s) => lengthOf[s] == len).toList()..sort()..forEach(w.raw);
  }

  if (restartInterval > 0) {
    w.raw(0xFF);
    w.raw(0xDD); // DRI
    w.raw(0);
    w.raw(4);
    w.raw(restartInterval >> 8);
    w.raw(restartInterval & 0xFF);
  }

  w.raw(0xFF);
  w.raw(0xDA); // SOS
  w.raw(0);
  w.raw(6); // LEN
  w.raw(1); // Ns
  w.raw(1); // Cs
  w.raw(0x00); // Td=0
  w.raw(1); // Ss = 1 (lossless)

  // Entropy.
  var rstIndex = 0;
  for (var i = 0; i < diffs.length; i++) {
    if (freshFlags[i]) {
      w.align();
      w.raw(0xFF);
      w.raw(0xD0 + (rstIndex++ & 7)); // RSTn
    }
    final s = category(diffs[i]);
    w.bits(codeOf[s]!, lengthOf[s]!);
    if (s == 16) {
      w.bits(diffs[i] & 0xFFFF, 16);
    } else if (s > 0) {
      final v = diffs[i] >= 0 ? diffs[i] : diffs[i] + (1 << s) - 1;
      w.bits(v, s);
    }
  }
  w.raw(0xFF);
  w.raw(0xD9); // EOI
  return Uint8List.fromList(w.finish());
}
