/// DNG CFA decoder — Wave 2 W2 (M2-1): uncompressed and Adobe-deflate raw
/// strips → 16-bit Bayer planes → black/white-level normalisation →
/// bilinear demosaic → sRGB-gamma 8-bit [RgbaImage] the editor already
/// knows how to edit.
///
/// Lossless-JPEG (the phone-default) is detected in the document layer and
/// surfaces as [RawUnsupportedException] with a plain message until the
/// dedicated decoder lands (ROADMAP W2). Fuzz gate: every strip access is
/// bounds-checked; corrupt input raises, never crashes.
library;

import 'dart:io' show ZLibDecoder;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumora/features/ai/pipelines/tensor_utils.dart' show RgbaImage;
import 'package:lumora/features/photo_editor/domain/raw/dng_document.dart';
import 'package:lumora/features/photo_editor/domain/raw/tiff_parser.dart';

/// 16-bit single-channel Bayer buffer.
class BayerImage {
  BayerImage(this.width, this.height) : data = Uint16List(width * height);

  final int width;
  final int height;
  final Uint16List data;

  int at(int x, int y) => data[y * width + x];

  void set(int x, int y, int v) => data[y * width + x] = v;
}

/// Decodes the raw CFA strips of [file] (already parsed as [doc]) into a
/// [BayerImage] cropped to the DNG ActiveArea.
BayerImage decodeCfa(Uint8List file, DngDocument doc) {
  final cfa = doc.cfa;
  // Bit-depth guards first (the document layer records, the decoder rejects).
  if (cfa.bitsPerSample == 32) {
    throw const RawUnsupportedException(RawUnsupportedReason.floatingPoint);
  }
  if (cfa.bitsPerSample != 8 && cfa.bitsPerSample != 12 && cfa.bitsPerSample != 14 && cfa.bitsPerSample != 16) {
    throw const RawUnsupportedException(RawUnsupportedReason.unknownBits);
  }
  if (!cfa.isDirectlyDecodable) {
    throw RawUnsupportedException(
      cfa.compression == RawCompression.losslessJpeg
          ? RawUnsupportedReason.losslessJpeg
          : cfa.compression == RawCompression.lossyJpegDng
              ? RawUnsupportedReason.lossyJpeg
              : RawUnsupportedReason.unknownCompression,
    );
  }

  final bytesPerSample = cfa.bitsPerSample == 8 ? 1 : 2;
  final littleEndian = doc.tif.littleEndian;

  // 1. Concatenate strips → full raw block (sensor-sized).
  final fullW = cfa.width;
  final fullH = cfa.height;
  final raw = Uint16List(fullW * fullH);
  var rowCursor = 0;
  for (var s = 0; s < cfa.stripOffsets.length; s++) {
    final start = cfa.stripOffsets[s];
    final count = s < cfa.stripByteCounts.length ? cfa.stripByteCounts[s] : 0;
    if (start < 0 || start + count > file.length) {
      throw TiffFormatException('strip $s out of bounds (offset $start, $count B)');
    }
    var payload = Uint8List.sublistView(file, start, start + count);
    if (cfa.compression == RawCompression.deflateAdobe) {
      try {
        payload = Uint8List.fromList(ZLibDecoder().convert(payload));
      } on FormatException catch (e) {
        throw TiffFormatException('deflate strip $s: ${e.message}');
      }
    }
    final rowsLeft = fullH - s * cfa.rowsPerStrip;
    final expectedRows = rowsLeft <= 0 ? 0 : math.min(cfa.rowsPerStrip, rowsLeft);
    if (payload.length < expectedRows * fullW * bytesPerSample) {
      throw TiffFormatException('strip $s too small for $expectedRows rows');
    }
    final view = bytesPerSample == 2 ? ByteData.sublistView(payload) : null;
    for (var r = 0; r < expectedRows; r++) {
      final dstRow = rowCursor + r;
      for (var x = 0; x < fullW; x++) {
        if (bytesPerSample == 2) {
          raw[dstRow * fullW + x] = littleEndian
              ? view!.getUint16((r * fullW + x) * 2, Endian.little)
              : view!.getUint16((r * fullW + x) * 2);
        } else {
          raw[dstRow * fullW + x] = payload[r * fullW + x];
        }
      }
    }
    rowCursor += expectedRows;
  }
  if (rowCursor != fullH) {
    throw TiffFormatException('strips cover $rowCursor of $fullH rows');
  }

  // 2. ActiveArea crop (top, left, bottom, right) — sensor → image frame.
  //    An absent/zero ActiveArea ([0,0,0,0] sentinel from the document
  //    layer) means "whole sensor" per the DNG spec default.
  final aa = cfa.activeArea;
  final whole = aa.length != 4 || (aa[0] == 0 && aa[1] == 0 && aa[2] == 0 && aa[3] == 0);
  final top = whole ? 0 : aa[0];
  final left = whole ? 0 : aa[1];
  final bottom = whole ? fullH : aa[2];
  final right = whole ? fullW : aa[3];
  final outW = right - left;
  final outH = bottom - top;
  if (outW <= 0 || outH <= 0 || outW > fullW || outH > fullH) {
    throw TiffFormatException('ActiveArea $aa does not fit the sensor $fullW×$fullH');
  }
  final bayer = BayerImage(outW, outH);
  for (var y = 0; y < outH; y++) {
    for (var x = 0; x < outW; x++) {
      bayer.set(x, y, raw[(y + top) * fullW + (x + left)]);
    }
  }
  return bayer;
}

/// Bilinear demosaic of a Bayer image into RGB planes (0..1 linear floats),
/// respecting the CFA pattern repeat (RGGB-family, 2×2 and beyond; channel
/// ids ≥ 3 fold into green).
DemosaicResult demosaicBilinear(BayerImage bayer, List<List<int>> pattern, double black, double white) {
  final w = bayer.width;
  final h = bayer.height;
  final span = (white - black) <= 0 ? 1.0 : (white - black);

  int channelAt(int x, int y) {
    final c = pattern[y % pattern.length][x % pattern[0].length];
    return c >= 3 ? 1 : c;
  }

  final r = Float32List(w * h);
  final g = Float32List(w * h);
  final b = Float32List(w * h);
  final planes = [r, g, b];

  double sample(int plane, int x, int y) {
    final cx = x.clamp(0, w - 1);
    final cy = y.clamp(0, h - 1);
    final v = bayer.at(cx, cy);
    return ((v - black) / span).clamp(0.0, 1.0);
  }

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final own = channelAt(x, y);
      planes[own][y * w + x] = sample(own, x, y);
      for (var c = 0; c < 3; c++) {
        if (c == own) continue;
        // Red↔blue pairs sit on the diagonal (RGGB geometry): average the
        // 4 diagonal neighbours. Anything involving green is orthogonal.
        final diagonal = own != 1 && c != 1 && own != c;
        final v = diagonal
            ? (sample(c, x - 1, y - 1) + sample(c, x + 1, y - 1) + sample(c, x - 1, y + 1) + sample(c, x + 1, y + 1)) / 4
            : (sample(c, x - 1, y) + sample(c, x + 1, y) + sample(c, x, y - 1) + sample(c, x, y + 1)) / 4;
        planes[c][y * w + x] = v;
      }
    }
  }
  return DemosaicResult(r, g, b, w, h);
}

/// Bilinear demosaic result: linear RGB planes in 0..1.
class DemosaicResult {
  const DemosaicResult(this.red, this.green, this.blue, this.width, this.height);

  final Float32List red;
  final Float32List green;
  final Float32List blue;
  final int width;
  final int height;
}

/// Demosaic → sRGB gamma → 8-bit RGBA, ready for the editor's normal
/// 8-bit pipeline (deeper 16-bit paths land in M2-2).
RgbaImage toRgba(DemosaicResult d) {
  final out = Uint8List(d.width * d.height * 4);
  for (var i = 0; i < d.width * d.height; i++) {
    out[i * 4] = _srgb(d.red[i]);
    out[i * 4 + 1] = _srgb(d.green[i]);
    out[i * 4 + 2] = _srgb(d.blue[i]);
    out[i * 4 + 3] = 255;
  }
  return RgbaImage(d.width, d.height, out);
}

double _srgbEncode(double v) {
  if (v <= 0.0031308) return 12.92 * v;
  return 1.055 * math.pow(v, 1 / 2.4).toDouble() - 0.055;
}

int _srgb(double v) => (255 * _srgbEncode(v)).round().clamp(0, 255);
