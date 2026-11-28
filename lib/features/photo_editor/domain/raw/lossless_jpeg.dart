/// ITU-T T.81 lossless (SOF3) JPEG decoder — Wave 2 W2 M2-2.
///
/// What DNG writers actually emit for raw strips: a baseline lossless
/// predictive JPEG (SOF3) with one (CFA) or few components, 8- or 16-bit
/// sample precision, predictor 1-7 per component, and Huffman entropy
/// coding — no quantisation tables, 1×1 sampling. This decoder supports
/// exactly that subset, including restart intervals, and rejects anything
/// else honestly.
///
/// Pure Dart, no platform calls. Malformed input raises
/// [LosslessJpegFormatException] (fuzz gate — never crashes, never hangs:
/// every loop is bounded by the declared dimensions and an MCU budget).
library;

import 'dart:typed_data';

/// Raised on structurally invalid or unsupported lossless JPEG payloads.
class LosslessJpegFormatException implements Exception {
  const LosslessJpegFormatException(this.reason);

  final String reason;

  @override
  String toString() => 'LosslessJpegFormatException: $reason';
}

/// One decoded lossless JPEG: dimensions, precision and per-component
/// sample planes (predictor-removed, point-transform applied back).
class LosslessJpegImage {
  const LosslessJpegImage(this.width, this.height, this.precision, this.components);

  final int width;
  final int height;
  final int precision;

  /// One raster plane per component in scan order.
  final List<Uint16List> components;

  /// Convenience: the first component (the CFA plane for DNG strips).
  Uint16List get samples => components.first;
}

class _HuffmanTable {
  final List<Map<int, int>> decode = List.generate(17, (_) => {}); // length → {code: symbol}

  void add(int length, int code, int symbol) {
    if (length < 1 || length > 16) {
      throw LosslessJpegFormatException('Huffman code length $length out of range');
    }
    decode[length][code] = symbol;
  }

  /// Decodes one symbol; [reader] is positioned at the first code bit.
  int readSymbol(_BitReader reader) {
    var code = 0;
    for (var length = 1; length <= 16; length++) {
      code = (code << 1) | reader.readBit();
      final symbol = decode[length][code];
      if (symbol != null) return symbol;
    }
    throw const LosslessJpegFormatException('no Huffman symbol within 16 bits');
  }
}

class _BitReader {
  _BitReader(this.bytes, this.pos, this.end);

  final Uint8List bytes;
  int pos;
  final int end;
  int _bit = 8;
  int _cur = 0;

  int readBit() {
    if (_bit == 8) {
      if (pos >= end) throw const LosslessJpegFormatException('entropy data exhausted mid-MCU');
      _cur = bytes[pos++];
      if (_cur == 0xFF) {
        if (pos < end && bytes[pos] == 0x00) {
          pos++; // byte stuffing: FF 00 → literal FF
        } else {
          final marker = pos < end ? bytes[pos] : 0xD9;
          throw LosslessJpegFormatException(
            'marker 0x${(0xFF00 | marker).toRadixString(16)} inside entropy data '
            '(restart misalignment or truncated scan)',
          );
        }
      }
      _bit = 0;
    }
    final bit = (_cur >> (7 - _bit)) & 1;
    _bit++;
    return bit;
  }

  int readBits(int n) {
    var v = 0;
    for (var i = 0; i < n; i++) {
      v = (v << 1) | readBit();
    }
    return v;
  }

  /// Restart boundary: discard the padding bits of the current byte, then
  /// consume the RSTn marker (FF D0..D7) directly from the byte stream.
  void consumeRestart() {
    _bit = 8;
    if (pos + 1 < end && bytes[pos] == 0xFF && (bytes[pos + 1] & 0xF8) == 0xD0) {
      pos += 2;
      return;
    }
    final next = pos < end ? bytes[pos] : 0;
    final what = next == 0xFF
        ? '0x${((next << 8) | (pos + 1 < end ? bytes[pos + 1] : 0)).toRadixString(16)}'
        : 'end of data';
    throw LosslessJpegFormatException('expected restart marker, found $what');
  }
}

/// Category s → differential value (T.81 Table F.1): s bits received; a
/// leading 0 bit means negative. s == 16 is the escape: the 16 received
/// bits ARE the difference in two's complement (no extension).
int _extend(int v, int s) =>
    s == 16 ? (v >= 0x8000 ? v - 0x10000 : v) : (s == 0 ? 0 : (v < (1 << (s - 1)) ? v - (1 << s) + 1 : v));

class _Sof {
  _Sof(this.width, this.height, this.precision, this.components);

  final int width;
  final int height;
  final int precision;
  final List<_SofComponent> components;
}

class _SofComponent {
  const _SofComponent(this.id, this.predictor, this.pointTransform);

  final int id;
  final int predictor; // 1..7
  final int pointTransform; // Pt — encoded samples are shifted down by Pt
}

class _Sos {
  _Sos(this.componentIds, this.tables);

  final List<int> componentIds;
  final List<int> tables; // Huffman table id per scan component
}

/// Decodes a lossless (SOF3) JPEG from [bytes] — a complete compressed
/// image as stored in a DNG raw strip (SOI … EOI).
LosslessJpegImage decodeLosslessJpeg(Uint8List bytes) {
  if (bytes.length < 4) {
    throw const LosslessJpegFormatException('payload too small');
  }
  final scan = _Scan(bytes);

  // Optional SOI.
  if (scan.pos + 1 < bytes.length && bytes[scan.pos] == 0xFF && bytes[scan.pos + 1] == 0xD8) {
    scan.pos += 2;
  }

  _Sof? sof;
  final dhts = <int, _HuffmanTable>{};
  var restartInterval = 0;
  _Sos? sos;

  // Header walk: SOF3 then DHT/DRI then SOS (any order, SOS last).
  while (sof == null || sos == null) {
    final marker = scan.nextMarker();
    if (marker == null) {
      throw const LosslessJpegFormatException('incomplete lossless JPEG (no SOF3/SOS)');
    }
    switch (marker) {
      case 0xFFC3:
        sof = _parseSof3(scan);
      case 0xFFC4:
        _parseDht(scan, dhts);
      case 0xFFDD:
        scan.expectLength(4);
        restartInterval = scan.u16();
      case 0xFFDA:
        if (sof == null) {
          throw const LosslessJpegFormatException('SOS before SOF3');
        }
        sos = _parseSos(scan);
      case 0xFFD9:
        throw const LosslessJpegFormatException('EOI before any scan');
      case >= 0xFFC0 && <= 0xFFCF:
        throw LosslessJpegFormatException('unsupported SOF marker 0x${marker.toRadixString(16)} (not lossless SOF3)');
      default:
        scan.skipSegment(); // APPn / COM / DNL etc.
    }
  }

  // Entropy decode.
  final planes = _decodeEntropy(scan, sof, sos, dhts, restartInterval);
  return LosslessJpegImage(sof.width, sof.height, sof.precision, planes);
}

class _Scan {
  _Scan(this.bytes);

  final Uint8List bytes;
  int pos = 0;

  int u16() {
    if (pos + 1 >= bytes.length) {
      throw const LosslessJpegFormatException('truncated segment (u16)');
    }
    final v = (bytes[pos] << 8) | bytes[pos + 1];
    pos += 2;
    return v;
  }

  int u8() {
    if (pos >= bytes.length) {
      throw const LosslessJpegFormatException('truncated segment (u8)');
    }
    return bytes[pos++];
  }

  /// Advances to the next real marker (FF followed by non-00, non-FF),
  /// returning it, or null at end of data.
  int? nextMarker() {
    while (pos + 1 < bytes.length) {
      if (bytes[pos] == 0xFF && bytes[pos + 1] != 0x00 && bytes[pos + 1] != 0xFF) {
        final marker = (bytes[pos] << 8) | bytes[pos + 1];
        pos += 2;
        return marker;
      }
      pos++;
    }
    return null;
  }

  void expectLength(int expected) {
    final len = u16();
    if (len != expected) {
      throw LosslessJpegFormatException('segment length $len, expected $expected');
    }
  }

  void skipSegment() {
    final len = u16();
    if (len < 2 || pos + len - 2 > bytes.length) {
      throw const LosslessJpegFormatException('segment length out of range');
    }
    pos += len - 2;
  }
}

_Sof _parseSof3(_Scan scan) {
  final len = scan.u16();
  if (len < 8) throw const LosslessJpegFormatException('SOF3 too short');
  final end = scan.pos + len - 2;
  final precision = scan.u8();
  final height = scan.u16();
  final width = scan.u16();
  final count = scan.u8();
  if (precision < 1 || precision > 16) {
    throw LosslessJpegFormatException('unsupported sample precision $precision');
  }
  if (width <= 0 || height <= 0 || width > 65535 || height > 65535) {
    throw const LosslessJpegFormatException('implausible SOF3 dimensions');
  }
  if (count < 1 || count > 4) {
    throw LosslessJpegFormatException('unsupported component count $count');
  }
  final components = <_SofComponent>[];
  while (scan.pos < end) {
    final id = scan.u8();
    final packed = scan.u8(); // H<<4 | V
    final t = scan.u8(); // predictor (high nibble) + point transform Pt (low nibble)
    final predictor = t >> 4;
    final pt = t & 0x0F;
    if (predictor < 1 || predictor > 7) {
      throw LosslessJpegFormatException('unsupported predictor $predictor');
    }
    if (pt >= precision) {
      throw LosslessJpegFormatException('point transform $pt ≥ precision $precision');
    }
    if (packed != 0x11) {
      throw LosslessJpegFormatException('sampling factors ${packed >> 4}×${packed & 0xF} unsupported in lossless');
    }
    components.add(_SofComponent(id, predictor, pt));
  }
  return _Sof(width, height, precision, components);
}

void _parseDht(_Scan scan, Map<int, _HuffmanTable> dhts) {
  final len = scan.u16();
  final end = scan.pos + len - 2;
  while (scan.pos < end) {
    final packed = scan.u8();
    final tableId = packed & 0x0F;
    if (packed >> 4 != 0) {
      throw const LosslessJpegFormatException('AC Huffman table in a lossless scan');
    }
    if (tableId > 3) throw const LosslessJpegFormatException('DHT id out of range');
    final counts = List<int>.generate(16, (_) => scan.u8());
    final table = _HuffmanTable();
    var code = 0;
    var total = 0;
    for (var length = 1; length <= 16; length++) {
      for (var i = 0; i < counts[length - 1]; i++) {
        final symbol = scan.u8();
        table.add(length, code, symbol);
        code++;
        total++;
      }
      code <<= 1;
    }
    if (total == 0 || total > 256) {
      throw LosslessJpegFormatException('implausible Huffman table ($total symbols)');
    }
    dhts[tableId] = table;
  }
}

_Sos _parseSos(_Scan scan) {
  final len = scan.u16();
  final segEnd = scan.pos + len - 2;
  final count = scan.u8();
  if (count < 1 || count > 4) {
    throw LosslessJpegFormatException('unsupported scan component count $count');
  }
  final ids = <int>[];
  final tables = <int>[];
  for (var i = 0; i < count; i++) {
    ids.add(scan.u8());
    tables.add(scan.u8() & 0x0F);
  }
  // Lossless scans end with a single Ss byte (=1) that carries no
  // information for us — consume and validate it when present.
  if (scan.pos < segEnd) {
    final ss = scan.u8();
    if (ss != 1) {
      throw LosslessJpegFormatException('lossless SOS Ss = $ss (expected 1)');
    }
  }
  scan.pos = segEnd; // tolerate any padding so the entropy stream starts clean
  return _Sos(ids, tables);
}

/// The predictor lattice (T.81 §H.2.2 / §A.3.3), predictors 1-7.
int _predict(int p, int ra, int rb, int rc) => switch (p) {
  1 => ra,
  2 => rb,
  3 => rc,
  4 => ra + rb - rc,
  5 => ra + ((rb - rc) >> 1),
  6 => rb + ((ra - rc) >> 1),
  7 => (ra + rb) >> 1,
  _ => throw LosslessJpegFormatException('predictor $p'),
};

List<Uint16List> _decodeEntropy(_Scan scan, _Sof sof, _Sos sos, Map<int, _HuffmanTable> dhts, int restartInterval) {
  final width = sof.width;
  final height = sof.height;
  final planeCount = sof.components.length;
  final compIndex = <int>[];
  for (final id in sos.componentIds) {
    final idx = sof.components.indexWhere((c) => c.id == id);
    if (idx < 0) throw LosslessJpegFormatException('scan references unknown component $id');
    compIndex.add(idx);
  }
  final interleaved = sos.componentIds.length > 1;

  final planes = <Uint16List>[for (var i = 0; i < planeCount; i++) Uint16List(width * height)];
  // Raster cursor per component (index of the next sample to write).
  final cursors = List.filled(planeCount, 0);
  // True right after the scan start or a restart marker: the next sample
  // uses the initial prediction instead of the lattice.
  final fresh = List.filled(planeCount, true);
  // Per-component initial prediction and final shift (T.81: the encoded
  // sample holds value >> Pt, so the initial prediction is 2^(P-Pt-1) and
  // the reconstruction shifts back up).
  final initValue = [for (final c in sof.components) 1 << (sof.precision - 1 - c.pointTransform)];
  final mask = (1 << sof.precision) - 1;
  final totalSamples = width * height;
  final mcuBudget = totalSamples * 2; // hang-guard
  var mcus = 0;

  final reader = _BitReader(scan.bytes, scan.pos, scan.bytes.length);

  void decodeOneSample(int ci, int tableId) {
    final plane = planes[ci];
    final cursor = cursors[ci];
    final x = cursor % width;
    final y = cursor ~/ width;
    final table = dhts[tableId];
    if (table == null) throw const LosslessJpegFormatException('missing Huffman table for scan');
    final symbol = table.readSymbol(reader);
    final diff = symbol == 16 ? _extend(reader.readBits(16), 16) : _extend(reader.readBits(symbol), symbol);
    int pred;
    if (fresh[ci]) {
      pred = initValue[ci];
      fresh[ci] = false;
    } else if (x == 0 && y == 0) {
      pred = initValue[ci];
    } else if (x == 0) {
      pred = plane[cursor - width] >> sof.components[ci].pointTransform; // Rb at reduced precision
    } else if (y == 0) {
      pred = plane[cursor - 1] >> sof.components[ci].pointTransform; // Ra
    } else {
      final shift = sof.components[ci].pointTransform;
      pred = _predict(
        sof.components[ci].predictor,
        plane[cursor - 1] >> shift,
        plane[cursor - width] >> shift,
        plane[cursor - width - 1] >> shift,
      );
    }
    plane[cursor] = ((pred + diff) << sof.components[ci].pointTransform) & mask;
    cursors[ci] = cursor + 1;
  }

  var done = false;
  while (!done) {
    for (final ci in compIndex) {
      final tableId = sos.tables[compIndex.indexOf(ci)];
      if (interleaved) {
        decodeOneSample(ci, tableId);
      } else {
        // Non-interleaved: this MCU decodes samples until the component's
        // plane is full (restarts break mid-plane — handled below).
        while (cursors[ci] < totalSamples) {
          decodeOneSample(ci, tableId);
          if (restartInterval > 0 && cursors[ci] % restartInterval == 0 && cursors[ci] < totalSamples) {
            break; // restart boundary falls inside the plane
          }
        }
      }
    }
    if (++mcus > mcuBudget) {
      throw const LosslessJpegFormatException('MCU budget exceeded (corrupt entropy stream)');
    }
    done = cursors.every((c) => c >= totalSamples);
    if (done) break;

    // Restart marker between MCU blocks (T.81: predictors reset to the
    // initial value for every component in the scan).
    if (restartInterval > 0) {
      reader.consumeRestart();
      for (var i = 0; i < planeCount; i++) {
        fresh[i] = true;
      }
    }
  }

  return planes;
}
