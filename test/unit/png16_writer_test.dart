import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumora/features/photo_editor/domain/raw/png16_writer.dart';

/// Parses the chunk list of a PNG buffer: (type, payload) pairs, CRCs
/// verified against the type + payload bytes.
List<(String, Uint8List)> _chunks(Uint8List png) {
  final bd = ByteData.sublistView(png);
  final out = <(String, Uint8List)>[];
  var off = 8;
  while (off < png.length) {
    final len = bd.getUint32(off);
    final type = String.fromCharCodes(png.sublist(off + 4, off + 8));
    final payload = png.sublist(off + 8, off + 8 + len);
    final crc = bd.getUint32(off + 8 + len);
    out.add((type, payload));
    expect(crc, _crc32Of(type, payload), reason: 'bad CRC on $type');
    off += 12 + len;
  }
  expect(off, png.length, reason: 'trailing bytes after IEND');
  return out;
}

int _crc32Of(String type, Uint8List payload) {
  final table = <int>[];
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    table.add(c);
  }
  var c = 0xFFFFFFFF;
  for (final b in [...type.codeUnits, ...payload]) {
    c = table[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

Uint8List _sample(int w, int h) {
  final out = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final o = (y * w + x) * 4;
      out[o] = (x * 255 / (w - 1)).round();
      out[o + 1] = (y * 255 / (h - 1)).round();
      out[o + 2] = ((x + y) * 7) & 0xFF;
      out[o + 3] = 200;
    }
  }
  return out;
}

void main() {
  test('structure: signature, chunk order and IHDR fields', () {
    final png = encodePng16(_sample(8, 5), 8, 5);
    expect(png.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    final chunks = _chunks(png);
    expect(chunks.map((c) => c.$1), ['IHDR', 'sRGB', 'IDAT', 'IEND']);
    final ihdr = ByteData.sublistView(chunks.first.$2);
    expect(ihdr.getUint32(0), 8);
    expect(ihdr.getUint32(4), 5);
    expect(ihdr.getUint8(8), 16, reason: 'bit depth');
    expect(ihdr.getUint8(9), 2, reason: 'colour type RGB');
    expect(ihdr.getUint8(12), 0, reason: 'no interlace');
    expect(chunks[1].$2, [0], reason: 'sRGB perceptual intent');
  });

  test('pixel round-trip: filter-0 rows, big-endian v·257 expansion, alpha dropped', () {
    const w = 6;
    const h = 4;
    final src = _sample(w, h);
    final png = encodePng16(src, w, h);
    final idat = _chunks(png).firstWhere((c) => c.$1 == 'IDAT').$2;
    final raw = ZLibCodec().decode(idat);
    expect(raw.length, h * (1 + w * 6));
    final bd = ByteData.sublistView(Uint8List.fromList(raw));
    for (var y = 0; y < h; y++) {
      final rowOff = y * (1 + w * 6);
      expect(raw[rowOff], 0, reason: 'filter byte');
      for (var x = 0; x < w; x++) {
        final s = (y * w + x) * 4;
        final d = rowOff + 1 + x * 6;
        expect(bd.getUint16(d), src[s] * 257);
        expect(bd.getUint16(d + 2), src[s + 1] * 257);
        expect(bd.getUint16(d + 4), src[s + 2] * 257);
      }
    }
  });

  test('0x00 and 0xFF map to exactly 0 and 65535', () {
    final src = Uint8List.fromList(const [0, 255, 0, 255]);
    final png = encodePng16(src, 1, 1);
    final idat = _chunks(png).firstWhere((c) => c.$1 == 'IDAT').$2;
    final raw = ZLibCodec().decode(idat);
    final bd = ByteData.sublistView(Uint8List.fromList(raw));
    expect(bd.getUint16(1), 0);
    expect(bd.getUint16(3), 65535);
    expect(bd.getUint16(5), 0);
  });

  test('the image package decodes the file as a 16-bit PNG', () {
    const w = 9;
    const h = 7;
    final src = _sample(w, h);
    final png = encodePng16(src, w, h);
    final decoded = img.decodePng(png);
    expect(decoded, isNotNull);
    expect(decoded!.width, w);
    expect(decoded.height, h);
    expect(decoded.numChannels, 3);
    // 16-bit decode: the package scales to its storage; compare via >> 8.
    final px = decoded.getPixel(4, 3);
    const s = (3 * w + 4) * 4;
    expect(px.r.toInt() >> (px.r.toInt() > 255 ? 8 : 0), src[s]);
  });

  test('invalid buffers raise instead of writing a corrupt file', () {
    expect(() => encodePng16(Uint8List(7), 2, 2), throwsArgumentError);
    expect(() => encodePng16(Uint8List(16), 0, 2), throwsArgumentError);
    expect(() => encodePng16(Uint8List(16), 2, -1), throwsArgumentError);
  });
}
