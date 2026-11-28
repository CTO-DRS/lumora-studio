import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/photo_editor/domain/raw/lossless_jpeg.dart';
import 'package:lumora/features/photo_editor/domain/raw/tiff_parser.dart';

/// C3 fuzz gate for the RAW importers: random, truncated and bit-flipped
/// inputs must raise the parser's own bounded format exception — never a
/// crash, RangeError, or any other throw.
void main() {
  Uint8List minimalTiff() {
    // Little-endian TIFF: II, magic 42, IFD0 at offset 8, one SHORT entry
    // (tag 256 width = 1), no next IFD.
    final b = ByteData(8 + 2 + 12 + 4);
    b.setUint8(0, 0x49);
    b.setUint8(1, 0x49);
    b.setUint16(2, 42, Endian.little);
    b.setUint32(4, 8, Endian.little);
    b.setUint16(8, 1, Endian.little);
    b.setUint16(10, 256, Endian.little);
    b.setUint16(12, 3, Endian.little);
    b.setUint32(14, 1, Endian.little);
    b.setUint16(18, 1, Endian.little);
    b.setUint32(22, 0, Endian.little);
    return b.buffer.asUint8List();
  }

  Uint8List minimalLosslessJpeg() {
    // SOI + SOF3 (8-bit, 1x1, 1 component) + DHT + SOS with a tiny scan + EOI.
    // Built to decode successfully as a baseline for mutation fuzzing.
    final out = BytesBuilder();
    out.add([0xFF, 0xD8]); // SOI
    out.add([0xFF, 0xC3, 0x00, 0x0B, 0x08]); // SOF3, length 11, precision 8
    out.add([0x00, 0x01, 0x00, 0x01]); // height 1, width 1
    out.add([0x01, 0x01, 0x11, 0x10]); // 1 component, 1x1 sampling, predictor 1, Pt 0
    // DHT: DC table 0 with a single 1-bit code for symbol 0 (diff length 0).
    out.add([0xFF, 0xC4, 0x00, 0x14, 0x00]); // DHT, class DC, id 0
    out.add([0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
    out.add([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
    out.add([0x00]); // symbol 0
    // SOS: 1 component, table 0/0, Ss=1 Se=0 AhAl=0, then one zero bit.
    out.add([0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x01, 0x00, 0x00]);
    out.add([0x00]); // entropy data: one 0 bit -> code '0' -> symbol 0 -> diff 0
    out.add([0xFF, 0xD9]); // EOI
    return out.toBytes();
  }

  const corpus = 512;

  void expectBounded(void Function() body, String label) {
    try {
      body();
    } on TiffFormatException {
      // expected
    } on LosslessJpegFormatException {
      // expected
    } catch (e) {
      fail('$label threw an unbounded error: $e');
    }
  }

  group('tiff parser fuzz', () {
    test('random garbage never escapes the format exception', () {
      final rnd = Random(20261128);
      for (var i = 0; i < corpus; i++) {
        final bytes = Uint8List.fromList(List.generate(rnd.nextInt(64), (_) => rnd.nextInt(256)));
        expectBounded(() => TiffDocument.parse(bytes), 'random#$i');
      }
    });

    test('truncations and bit flips of a valid header stay bounded', () {
      final good = minimalTiff();
      expect(TiffDocument.parse(good).ifds, isNotEmpty);
      final rnd = Random(7);
      for (var cut = 0; cut < good.length; cut++) {
        expectBounded(() => TiffDocument.parse(good.sublist(0, cut)), 'cut#$cut');
      }
      for (var i = 0; i < corpus; i++) {
        final bad = Uint8List.fromList(good);
        bad[rnd.nextInt(bad.length)] ^= 1 << rnd.nextInt(8);
        expectBounded(() => TiffDocument.parse(bad), 'flip#$i');
      }
    });
  });

  group('lossless jpeg fuzz', () {
    test('random garbage never escapes the format exception', () {
      final rnd = Random(20261128);
      for (var i = 0; i < corpus; i++) {
        final bytes = Uint8List.fromList(List.generate(rnd.nextInt(64), (_) => rnd.nextInt(256)));
        expectBounded(() => decodeLosslessJpeg(bytes), 'random#$i');
      }
    });

    test('truncations and bit flips of a valid stream stay bounded', () {
      final good = minimalLosslessJpeg();
      expect(decodeLosslessJpeg(good).width, 1);
      final rnd = Random(11);
      for (var cut = 0; cut < good.length; cut++) {
        expectBounded(() => decodeLosslessJpeg(good.sublist(0, cut)), 'cut#$cut');
      }
      for (var i = 0; i < corpus; i++) {
        final bad = Uint8List.fromList(good);
        bad[rnd.nextInt(bad.length)] ^= 1 << rnd.nextInt(8);
        expectBounded(() => decodeLosslessJpeg(bad), 'flip#$i');
      }
    });
  });
}
