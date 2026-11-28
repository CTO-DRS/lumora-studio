/// 16-bit RGB PNG writer — the second half of the W2 "export beyond the
/// 8-bit ceiling" path (next to `tiff_writer.dart`).
///
/// RGBA8 pixels are lifted to RGB16 (v·257 → full 0..65535 range, alpha
/// dropped) and written as a baseline PNG: 8-byte signature, IHDR (bit
/// depth 16, colour type 2, no interlace), an sRGB chunk so viewers treat
/// the data as sRGB, one IDAT (zlib stream of filter-0 scanlines,
/// big-endian samples per RFC 2083) and IEND. Pure Dart; the zlib stream
/// uses `dart:io`'s codec, which runs fine inside `Isolate.run`.
library;

import 'dart:io';
import 'dart:typed_data';

const _signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

/// CRC-32 (ISO 3309, the PNG chunk CRC) over [data] (optionally seeded).
int _crc32(List<int> data, [int crc = 0]) {
  final table = _crcTable();
  var c = crc ^ 0xFFFFFFFF;
  for (final b in data) {
    c = table[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

List<int>? _table;

List<int> _crcTable() {
  final cached = _table;
  if (cached != null) return cached;
  final t = List<int>.filled(256, 0);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    t[n] = c;
  }
  return _table = t;
}

void _chunk(BytesBuilder out, String type, List<int> payload) {
  final length = ByteData(4)..setUint32(0, payload.length);
  final typeBytes = type.codeUnits;
  final crc = ByteData(4)..setUint32(0, _crc32([...typeBytes, ...payload]));
  out
    ..add(length.buffer.asUint8List())
    ..add(typeBytes)
    ..add(payload)
    ..add(crc.buffer.asUint8List());
}

/// Converts [rgba] (RGBA8, row-major) into a 16-bit RGB PNG file.
Uint8List encodePng16(Uint8List rgba, int width, int height) {
  if (width <= 0 || height <= 0 || rgba.length != width * height * 4) {
    throw ArgumentError('RGBA buffer does not match ${width}x$height');
  }

  // Scanlines: filter byte 0 + RGB16 big-endian per pixel.
  final rowBytes = width * 6;
  final raw = Uint8List((rowBytes + 1) * height);
  final rawBd = ByteData.sublistView(raw);
  for (var y = 0; y < height; y++) {
    final rowOff = y * (rowBytes + 1);
    raw[rowOff] = 0; // filter: none
    for (var x = 0; x < width; x++) {
      final s = (y * width + x) * 4;
      final d = rowOff + 1 + x * 6;
      rawBd
        ..setUint16(d, rgba[s] * 257)
        ..setUint16(d + 2, rgba[s + 1] * 257)
        ..setUint16(d + 4, rgba[s + 2] * 257);
    }
  }
  final compressed = ZLibCodec().encode(raw);

  final ihdr = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 16) // bit depth
    ..setUint8(9, 2) // colour type: truecolour RGB
    ..setUint8(10, 0) // compression: deflate
    ..setUint8(11, 0) // filter: adaptive (we emit filter-0 rows)
    ..setUint8(12, 0); // interlace: none

  final out = BytesBuilder()..add(_signature);
  _chunk(out, 'IHDR', ihdr.buffer.asUint8List());
  _chunk(out, 'sRGB', [0]); // rendering intent: perceptual
  _chunk(out, 'IDAT', compressed);
  _chunk(out, 'IEND', const []);
  return out.takeBytes();
}
