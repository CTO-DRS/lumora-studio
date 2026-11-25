/// 16-bit RGB TIFF writer — Wave 2 W2 M2-3 ("export beyond the 8-bit
/// ceiling"). Little-endian classic TIFF, uncompressed RGB uint16 strips.
///
/// Built for the editor's export path: RGBA8 pixels are lifted to RGB16
/// (v·257 → full 0..65535 range) and written as strips capped at ~1 MB so
/// 24 MP exports stay stream-friendly. Pure Dart, no platform calls; the
/// structure follows the TIFF inline rule (values ≤ 4 B live in the entry)
/// and is readable by this project's own `TiffDocument.parse` (the
/// round-trip is unit-tested).
library;

import 'dart:typed_data';

const _software = 'Lumora Studio 16-bit TIFF';

/// One IFD entry. [values] holds the payload (for RATIONAL entries the
/// numerator/denominator pair with [count] = 1); [offset] is set when the
/// payload does not fit in the 4-byte inline field.
class _Entry {
  _Entry(this.tag, this.type, this.values, {int? count}) : count = count ?? values.length;

  final int tag;
  final int type;
  final List<int> values;
  final int count;
  int? offset;

  bool get inline => offset == null;
}

int _typeSize(int t) => switch (t) {
      1 || 2 || 6 || 7 => 1,
      3 || 8 => 2,
      4 || 11 => 4,
      5 || 10 || 12 => 8,
      _ => throw ArgumentError('unhandled TIFF type $t'),
    };

/// Converts [rgba] (RGBA8, row-major) into a 16-bit RGB TIFF file.
/// Alpha is dropped (RGB photometric); each channel byte is expanded with
/// v·257 so 0x00→0 and 0xFF→65535 exactly. [stripRowsOverride] caps the
/// rows per strip (tests use it to force multi-strip layouts; production
/// keeps the ~1 MB heuristic).
Uint8List encodeTiff16(Uint8List rgba, int width, int height, {int? stripRowsOverride}) {
  const channels = 3;
  final bytesPerRow = width * channels * 2;
  // ~1 MB strips keep large exports stream-friendly.
  final rowsPerStrip = stripRowsOverride ?? ((0x100000 / bytesPerRow).floor().clamp(1, height));
  final stripRowCounts = <int>[
    for (var start = 0; start < height; start += rowsPerStrip) rowsPerStrip.clamp(0, height - start),
  ];

  // Pixel payload: RGBA8 → RGB16 per strip.
  final strips = <Uint8List>[];
  for (var si = 0; si < stripRowCounts.length; si++) {
    final startRow = si * rowsPerStrip;
    final rows = stripRowCounts[si];
    final out = Uint16List(rows * width * channels);
    for (var r = 0; r < rows; r++) {
      final srcRow = (startRow + r) * width * 4;
      final dstRow = r * width * channels;
      for (var x = 0; x < width; x++) {
        final s = srcRow + x * 4;
        final d = dstRow + x * channels;
        out[d] = rgba[s] * 257;
        out[d + 1] = rgba[s + 1] * 257;
        out[d + 2] = rgba[s + 2] * 257;
      }
    }
    strips.add(Uint8List.view(out.buffer));
  }

  const tagCount = 15;
  const ifdSize = 2 + 12 * tagCount + 4;

  // Layout: header → IFD → out-of-line values → strip data.
  const ifdOff = 8;
  var cursor = ifdOff + ifdSize;
  int alloc(int size) {
    final off = cursor;
    cursor += size;
    return off;
  }

  final entries = <_Entry>[
    _Entry(254, 4, [0]), // NewSubfileType: full-res primary
    _Entry(256, 3, [width]), // ImageWidth
    _Entry(257, 3, [height]), // ImageLength
    _Entry(258, 3, [16, 16, 16]), // BitsPerSample (6 B → out of line)
    _Entry(259, 3, [1]), // Compression: none
    _Entry(262, 3, [2]), // PhotometricInterpretation: RGB
    _Entry(273, 4, List.filled(strips.length, 0)), // StripOffsets (filled below)
    _Entry(277, 3, [channels]), // SamplesPerPixel
    _Entry(278, 4, [rowsPerStrip]), // RowsPerStrip
    _Entry(279, 4, [for (final s in strips) s.length]), // StripByteCounts
    _Entry(282, 5, [72, 1], count: 1), // XResolution 72/1 (8 B → out of line)
    _Entry(283, 5, [72, 1], count: 1), // YResolution
    _Entry(296, 3, [2]), // ResolutionUnit: inch
    _Entry(305, 2, [..._software.codeUnits, 0]), // Software
    _Entry(338, 3, [1, 1, 1]), // SampleFormat: uint
  ]..sort((a, b) => a.tag.compareTo(b.tag));

  // Allocate out-of-line storage per the TIFF inline rule.
  for (final e in entries) {
    final size = _typeSize(e.type) * e.count;
    if (size > 4) e.offset = alloc(size);
  }

  // Absolute strip offsets (known once the values area size is fixed).
  final stripDataOff = cursor;
  final stripOffsets = <int>[];
  var acc = 0;
  for (final s in strips) {
    stripOffsets.add(stripDataOff + acc);
    acc += s.length;
  }
  entries.firstWhere((e) => e.tag == 273).values.setAll(0, stripOffsets);

  final file = Uint8List(cursor + acc);
  final bd = ByteData.sublistView(file);
  const le = Endian.little;

  // Header: II + magic 42 + IFD offset.
  file[0] = 0x49;
  file[1] = 0x49;
  bd
    ..setUint16(2, 42, le)
    ..setUint32(4, ifdOff, le);

  // IFD.
  bd.setUint16(ifdOff, entries.length, le);
  var p = ifdOff + 2;
  for (final e in entries) {
    bd
      ..setUint16(p, e.tag, le)
      ..setUint16(p + 2, e.type, le)
      ..setUint32(p + 4, e.count, le)
      ..setUint32(p + 8, e.inline ? (e.values.first & 0xFFFFFFFF) : e.offset!, le);
    p += 12;
  }
  bd.setUint32(p, 0, le); // no next IFD

  // Out-of-line values.
  for (final e in entries) {
    if (e.inline) continue;
    final off = e.offset!;
    switch (e.type) {
      case 2: // ASCII
        for (var i = 0; i < e.values.length; i++) {
          file[off + i] = e.values[i] & 0xFF;
        }
      case 3: // SHORT
        for (var i = 0; i < e.values.length; i++) {
          bd.setUint16(off + i * 2, e.values[i], le);
        }
      case 4: // LONG
        for (var i = 0; i < e.values.length; i++) {
          bd.setUint32(off + i * 4, e.values[i], le);
        }
      case 5: // RATIONAL — numerator/denominator pair
        bd
          ..setUint32(off, e.values[0], le)
          ..setUint32(off + 4, e.values[1], le);
      default:
        throw ArgumentError('unhandled out-of-line type ${e.type}');
    }
  }

  // Pixel data.
  var dst = stripDataOff;
  for (final s in strips) {
    file.setRange(dst, dst + s.length, s);
    dst += s.length;
  }
  return file;
}
