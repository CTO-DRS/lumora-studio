/// Minimal TIFF/IFD reader for DNG (Wave 2 W2 — RAW/DNG 16-bit pipeline).
///
/// DNG is TIFF-based; this parses the header, walks the IFD chain (plus
/// `SubIFDs`), decodes the common value types and returns typed entries.
/// **No image decoding here** — pure structure, so it is fuzz-testable and
/// unit-testable without any pixel work. Malformed input raises
/// [TiffFormatException] (never crashes) per the roadmap's fuzzing gate.
library;

import 'dart:typed_data';

/// Thrown on structurally invalid TIFF/DNG input (bad magic, truncated IFD,
/// out-of-range offsets). The caller turns it into a plain "unsupported
/// RAW" message.
class TiffFormatException implements Exception {
  const TiffFormatException(this.reason);

  final String reason;

  @override
  String toString() => 'TiffFormatException: $reason';
}

/// TIFF field types (classic TIFF + the BigTIFF additions DNG may carry).
enum TiffType {
  byte(1, 1),
  ascii(2, 1),
  short(3, 2),
  long(4, 4),
  rational(5, 8),
  sbyte(6, 1),
  undefined(7, 1),
  sshort(8, 2),
  slong(9, 4),
  srational(10, 8),
  float(11, 4),
  double(12, 8),
  long8(16, 8);

  const TiffType(this.id, this.byteSize);

  final int id;
  final int byteSize;

  static TiffType? fromId(int id) {
    for (final t in TiffType.values) {
      if (t.id == id) return t;
    }
    return null;
  }
}

/// One decoded TIFF entry: tag id + decoded values.
class TiffEntry {
  const TiffEntry(this.tag, this.values, this.rawOffset, this.rawLength);

  final int tag;

  /// Decoded element values. Ints for BYTE/SHORT/LONG/LONG8 (and the
  /// signed variants), doubles for RATIONAL/FLOAT/DOUBLE, strings for ASCII.
  final List<num> values;
  final int rawOffset;
  final int rawLength;

  int get firstInt => values.isEmpty ? 0 : values.first.toInt();

  double get firstDouble => values.isEmpty ? 0 : values.first.toDouble();

  /// ASCII payload as a string (used for the Software tag in tests).
  String get asString => String.fromCharCodes([
    for (final v in values) v.toInt() & 0xFF,
  ]).trim();
}

/// One Image File Directory.
class TiffIfd {
  const TiffIfd(this.entries);

  final List<TiffIfdEntry> entries;

  TiffIfdEntry? operator [](int tag) {
    for (final e in entries) {
      if (e.tag == tag) return e;
    }
    return null;
  }

  int? intTag(int tag) => this[tag]?.firstInt;

  List<int> intList(int tag) => (this[tag]?.values ?? const []).map((v) => v.toInt()).toList();

  List<double> doubleList(int tag) => (this[tag]?.values ?? const []).map((v) => v.toDouble()).toList();
}

/// Alias keeping the public name short inside [TiffIfd].
typedef TiffIfdEntry = TiffEntry;

/// Parsed TIFF structure: root IFD plus everything reachable through the
/// next-IFD chain and `SubIFDs` (bounded — malicious loops cannot hang us).
class TiffDocument {

  const TiffDocument(this.ifds, this.littleEndian);
  /// Parses the whole structure (chain + SubIFDs), depth- and loop-bounded.
  factory TiffDocument.parse(Uint8List bytes) {
    if (bytes.length < 8) {
      throw const TiffFormatException('file too small for a TIFF header');
    }
    final head = ByteData.sublistView(bytes);
    final order = String.fromCharCodes([bytes[0], bytes[1]]);
    final littleEndian = switch (order) {
      'II' => true,
      'MM' => false,
      _ => throw TiffFormatException('bad byte order "$order" (not TIFF)'),
    };
    final magic = littleEndian ? head.getUint16(2, Endian.little) : head.getUint16(2);
    if (magic != 42) {
      throw TiffFormatException('bad TIFF magic $magic (expected 42)');
    }
    final firstOffset = littleEndian ? head.getUint32(4, Endian.little) : head.getUint32(4);
    if (firstOffset < 8 || firstOffset >= bytes.length) {
      throw TiffFormatException('IFD0 offset $firstOffset out of range');
    }

    final ifds = <TiffIfd>[];
    final seen = <int>{};
    var offset = firstOffset;
    while (offset != 0 && !seen.contains(offset) && ifds.length < _kMaxIfds) {
      seen.add(offset);
      final ifd = _readIfd(bytes, offset, littleEndian);
      ifds.add(ifd.$1);
      offset = ifd.$2;
    }
    if (offset != 0 && ifds.length >= _kMaxIfds) {
      throw const TiffFormatException('IFD chain longer than 32 (malicious or corrupt)');
    }

    // SubIFDs of every directory (raw + previews usually live there).
    final subSeen = <int>{};
    final subs = <TiffIfd>[];
    for (final ifd in List<TiffIfd>.from(ifds)) {
      final subEntry = ifd[330]; // SubIFDs
      if (subEntry == null) continue;
      for (final off in subEntry.values) {
        final o = off.toInt();
        if (o < 8 || o >= bytes.length || subSeen.contains(o) || subs.length >= _kMaxSubIfds) continue;
        subSeen.add(o);
        try {
          final sub = _readIfd(bytes, o, littleEndian);
          subs.add(sub.$1);
        } on TiffFormatException {
          // A broken SubIFD must not sink the whole document.
        }
      }
    }
    return TiffDocument([...ifds, ...subs], littleEndian);
  }

  final List<TiffIfd> ifds;
  final bool littleEndian;

  static const _kMaxIfds = 32;
  static const _kMaxSubIfds = 64;

  static (TiffIfd, int) _readIfd(Uint8List bytes, int offset, bool littleEndian) {
    final head = ByteData.sublistView(bytes);
    if (offset + 2 > bytes.length) {
      throw const TiffFormatException('IFD header truncated');
    }
    final count = littleEndian ? head.getUint16(offset, Endian.little) : head.getUint16(offset);
    // 2 (count) + 12·count + 4 (next offset) must fit.
    if (offset + 2 + 12 * count + 4 > bytes.length) {
      throw TiffFormatException('IFD truncated at $offset ($count entries)');
    }
    var p = offset + 2;
    final entries = <TiffEntry>[];
    for (var i = 0; i < count; i++) {
      entries.add(_readEntry(bytes, p, littleEndian));
      p += 12;
    }
    final next = littleEndian ? head.getUint32(p, Endian.little) : head.getUint32(p);
    return (TiffIfd(entries), next);
  }

  static TiffEntry _readEntry(Uint8List bytes, int p, bool littleEndian) {
    final head = ByteData.sublistView(bytes);

    int u16(int o) => littleEndian ? head.getUint16(o, Endian.little) : head.getUint16(o);
    int u32(int o) => littleEndian ? head.getUint32(o, Endian.little) : head.getUint32(o);

    final tag = u16(p);
    final typeId = u16(p + 2);
    final type = TiffType.fromId(typeId);
    if (type == null) {
      throw TiffFormatException('unknown TIFF type $typeId (tag $tag)');
    }
    final count = u32(p + 4);
    if (count < 0 || count > (1 << 24)) {
      throw TiffFormatException('implausible entry count $count (tag $tag)');
    }
    final byteLength = type.byteSize * count;
    final fitsInline = byteLength <= 4;
    final valueOffset = fitsInline ? p + 8 : u32(p + 8);
    if (!fitsInline && (valueOffset < 0 || valueOffset + byteLength > bytes.length)) {
      throw TiffFormatException('value offset $valueOffset out of range (tag $tag)');
    }

    final values = <num>[];
    switch (type) {
      case TiffType.byte || TiffType.undefined || TiffType.sbyte || TiffType.ascii:
        for (var i = 0; i < count; i++) {
          values.add(bytes[valueOffset + i]);
        }
      case TiffType.short || TiffType.sshort:
        for (var i = 0; i < count; i++) {
          final v = u16(valueOffset + i * 2);
          values.add(type == TiffType.short ? v : _sign16(v));
        }
      case TiffType.long || TiffType.slong || TiffType.long8:
        final wide = type == TiffType.long8;
        for (var i = 0; i < count; i++) {
          final v = wide
              ? (littleEndian
                    ? head.getUint64(valueOffset + i * 8, Endian.little)
                    : head.getUint64(valueOffset + i * 8))
              : u32(valueOffset + i * 4);
          values.add(type == TiffType.slong ? _sign32(v) : v);
        }
      case TiffType.rational || TiffType.srational:
        for (var i = 0; i < count; i++) {
          final numerator = u32(valueOffset + i * 8);
          final denominator = u32(valueOffset + i * 8 + 4);
          values.add(denominator == 0 ? 0.0 : numerator / denominator);
        }
      case TiffType.float || TiffType.double:
        for (var i = 0; i < count; i++) {
          final size = type.byteSize;
          final v = size == 4
              ? head.getFloat32(valueOffset + i * 4, littleEndian ? Endian.little : Endian.big)
              : head.getFloat64(valueOffset + i * 8, littleEndian ? Endian.little : Endian.big);
          values.add(v);
        }
    }
    return TiffEntry(tag, values, valueOffset, byteLength);
  }

  static int _sign16(int v) => v >= 0x8000 ? v - 0x10000 : v;
  static int _sign32(int v) => v >= 0x80000000 ? v - 0x100000000 : v;
}
