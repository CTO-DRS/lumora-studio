/// DNG semantics on top of the TIFF parser (Wave 2 W2 — RAW/DNG pipeline).
///
/// Classifies IFDs (main raw / preview / thumbnail), extracts the CFA
/// metadata (pattern, black/white level, active area), detects the raw
/// compression and reports the supported/unsupported matrix. Pure Dart,
/// no pixel decoding — the decoder in [dng_decoder.dart] consumes this.
library;

import 'dart:typed_data';

import 'package:lumora/features/photo_editor/domain/raw/tiff_parser.dart';

/// TIFF/DNG tag ids used by the pipeline (subset, documented in the DNG 1.7
/// specification).
class DngTags {
  static const newSubfileType = 254;
  static const imageWidth = 256;
  static const imageLength = 257;
  static const bitsPerSample = 258;
  static const compression = 259;
  static const photometricInterpretation = 262;
  static const stripOffsets = 273;
  static const samplesPerPixel = 277;
  static const rowsPerStrip = 278;
  static const stripByteCounts = 279;
  static const subIfds = 330;
  static const dngVersion = 50706;
  static const cfaRepeatPatternDim = 50707;
  static const cfaPattern = 50708;
  static const activeArea = 50829;
  static const blackLevelRepeatDim = 50713;
  static const blackLevel = 50714;
  static const whiteLevel = 50717;
  static const colorMatrix1 = 50721;
  static const colorMatrix2 = 50722;
  static const calibrationIlluminant1 = 50778;
  static const calibrationIlluminant2 = 50779;
  static const previewColorSpace = 50832;
}

/// TIFF `Compression` values that appear in DNG.
enum RawCompression {
  uncompressed(1),
  jpeg(7),
  losslessJpeg(7), // PhotometricInterpretation == CFA disambiguates vs preview JPEG
  deflateAdobe(8),
  lossyJpegDng(34892),
  unknown(-1); // id not in the DNG table — kept for the honest-failure report

  const RawCompression(this.id);

  final int id;

  static RawCompression? fromId(int id) {
    switch (id) {
      case 1:
        return RawCompression.uncompressed;
      case 8:
        return RawCompression.deflateAdobe;
      case 34892:
        return RawCompression.lossyJpegDng;
      case 7:
        return RawCompression.losslessJpeg;
      default:
        return null;
    }
  }
}

/// Why a DNG's raw data cannot be decoded yet. Plain strings ship to the
/// user through the editor's error path (roadmap: honest failures).
enum RawUnsupportedReason {
  losslessJpeg('DNG raw data uses lossless JPEG — full decode lands in the next RAW milestone'),
  lossyJpeg('DNG raw data uses lossy JPEG (linear DNG) — not supported yet'),
  unknownCompression('unknown DNG compression'),
  floatingPoint('floating-point DNG samples — not supported yet'),
  unknownBits('unsupported bit depth');

  const RawUnsupportedReason(this.message);

  final String message;
}

/// What the raw (CFA) SubIFD contains and how it is stored.
class RawCfaInfo {
  const RawCfaInfo({
    required this.width,
    required this.height,
    required this.bitsPerSample,
    required this.compression,
    required this.pattern,
    required this.blackLevel,
    required this.whiteLevel,
    required this.activeArea,
    required this.stripOffsets,
    required this.stripByteCounts,
    required this.rowsPerStrip,
  });

  final int width;
  final int height;
  final int bitsPerSample;
  final RawCompression compression;

  /// CFA colour indices per pixel position, row-major, e.g. [[0,1],[1,2]]
  /// for RGGB (0 = red, 1 = green, 2 = blue; 3+ = second green etc.).
  final List<List<int>> pattern;
  final double blackLevel;
  final double whiteLevel;

  /// Crop rect (top, left, bottom, right) as stored in the DNG; may be
  /// [0, 0, 0, 0] meaning "whole sensor".
  final List<int> activeArea;
  final List<int> stripOffsets;
  final List<int> stripByteCounts;
  final int rowsPerStrip;

  /// Whether the sample layout is directly decodable without a JPEG decoder.
  bool get isDirectlyDecodable =>
      compression == RawCompression.uncompressed || compression == RawCompression.deflateAdobe;
}

/// A parsed DNG document: raw + previews classified, metadata extracted.
class DngDocument {
  DngDocument._(this.tif, this.cfa, this.rawIfdIndex, this.previews, this.dngVersion);

  final TiffDocument tif;
  final RawCfaInfo cfa;
  final int rawIfdIndex;

  /// Embedded previews: (IFD index, JPEG byte range, width, height).
  final List<DngPreview> previews;
  final List<int> dngVersion;

  /// The largest embedded preview (the "open in < 300 ms" path).
  DngPreview? get bestPreview {
    DngPreview? best;
    for (final p in previews) {
      if (best == null || p.width * p.height > best.width * best.height) {
        best = p;
      }
    }
    return best;
  }
}

/// One embedded preview/thumbnail IFD whose payload is a JPEG.
class DngPreview {
  const DngPreview(this.ifdIndex, this.jpegRange, this.width, this.height);

  final int ifdIndex;
  final (int, int) jpegRange;
  final int width;
  final int height;
}

/// Thrown when the raw payload needs an unimplemented decoder. Carries a
/// plain-language reason for the UI.
class RawUnsupportedException implements Exception {
  const RawUnsupportedException(this.reason);

  final RawUnsupportedReason reason;

  String get message => reason.message;

  @override
  String toString() => 'RawUnsupportedException: ${reason.message}';
}

/// Parses a full DNG file into a [DngDocument].
DngDocument parseDng(Uint8List bytes) {
  final tif = TiffDocument.parse(bytes);
  if (tif.ifds.isEmpty) {
    throw const TiffFormatException('no IFDs in DNG');
  }

  // The raw IFD: PhotometricInterpretation == 32803 (CFA) in the chain or
  // any SubIFD; the DNG 1.7 layout puts the raw in a SubIFD of IFD0.
  var rawIndex = -1;
  for (var i = 0; i < tif.ifds.length; i++) {
    if (tif.ifds[i].intTag(DngTags.photometricInterpretation) == 32803) {
      rawIndex = i;
      break;
    }
  }
  // Monochrome DNGs (PhotometricInterpretation 34892 LinearRaw) are a
  // different beast; classic B/W sensors may still be CFA-less: fall back
  // to the largest IFD with strips when no CFA marker exists but DNGVersion
  // does — and let the decoder's sample checks decide.
  if (rawIndex < 0) {
    final dngVersion = tif.ifds.first.intList(DngTags.dngVersion);
    if (dngVersion.length >= 2) {
      rawIndex = _largestStrippedIfd(tif);
    }
  }
  if (rawIndex < 0) {
    throw const TiffFormatException('no CFA / raw IFD found (not a raw DNG?)');
  }

  final rawIfd = tif.ifds[rawIndex];
  final cfa = _cfaInfo(rawIfd);
  final previews = _collectPreviews(tif, skipIndex: rawIndex);

  return DngDocument._(
    tif,
    cfa,
    rawIndex,
    previews,
    tif.ifds.first.intList(DngTags.dngVersion),
  );
}

int _largestStrippedIfd(TiffDocument tif) {
  var best = -1;
  var bestPixels = -1;
  for (var i = 0; i < tif.ifds.length; i++) {
    final w = tif.ifds[i].intTag(DngTags.imageWidth) ?? 0;
    final h = tif.ifds[i].intTag(DngTags.imageLength) ?? 0;
    if (w * h > bestPixels && (tif.ifds[i].intTag(DngTags.stripOffsets) ?? 0) != 0) {
      bestPixels = w * h;
      best = i;
    }
  }
  return best;
}

RawCfaInfo _cfaInfo(TiffIfd ifd) {
  final width = ifd.intTag(DngTags.imageWidth) ?? 0;
  final height = ifd.intTag(DngTags.imageLength) ?? 0;
  if (width <= 0 || height <= 0) {
    throw const TiffFormatException('raw IFD has no valid dimensions');
  }
  final bits = ifd.intTag(DngTags.bitsPerSample) ?? 16;
  // NOTE: unsupported compressions / bit depths are NOT rejected here.
  // The document layer only records what the file is, so the importer can
  // still fall back to the embedded preview; the decoder rejects when (and
  // only when) raw pixels are actually requested.
  final compressionId = ifd.intTag(DngTags.compression) ?? 1;
  final compression = RawCompression.fromId(compressionId) ?? RawCompression.unknown;

  // CFA pattern (2×2 default when the tag pair is missing — the DNG default
  // is a 2×2 G-R / B-G? No: the default when absent is RGGB per the spec's
  // "if absent, assume [2,2] and RGGB" interpretation used by libraw too).
  final repeatDim = ifd.intList(DngTags.cfaRepeatPatternDim);
  final flatPattern = ifd.intList(DngTags.cfaPattern);
  List<List<int>> pattern;
  if (repeatDim.length == 2 && flatPattern.length == repeatDim[0] * repeatDim[1]) {
    pattern = [
      for (var r = 0; r < repeatDim[0]; r++)
        [for (var c = 0; c < repeatDim[1]; c++) flatPattern[r * repeatDim[1] + c]],
    ];
  } else {
    pattern = [
      [0, 1],
      [1, 2],
    ]; // RGGB
  }

  final blackLevels = ifd.doubleList(DngTags.blackLevel);
  final blackLevel = blackLevels.isEmpty
      ? 0.0
      : blackLevels.reduce((a, b) => a + b) / blackLevels.length;
  final whiteLevel = ifd.intTag(DngTags.whiteLevel) ?? ((1 << bits) - 1).toDouble();
  final activeArea = ifd.intList(DngTags.activeArea);

  final offsets = ifd.intList(DngTags.stripOffsets);
  final counts = ifd.intList(DngTags.stripByteCounts);
  if (offsets.isEmpty || counts.isEmpty) {
    throw const TiffFormatException('raw IFD has no strip data');
  }
  final rowsPerStrip = ifd.intTag(DngTags.rowsPerStrip) ?? height;

  return RawCfaInfo(
    width: width,
    height: height,
    bitsPerSample: bits,
    compression: compression,
    pattern: pattern,
    blackLevel: blackLevel,
    whiteLevel: whiteLevel <= 0 ? ((1 << bits) - 1).toDouble() : whiteLevel.toDouble(),
    activeArea: activeArea.length == 4 ? activeArea : const [0, 0, 0, 0],
    stripOffsets: offsets,
    stripByteCounts: counts,
    rowsPerStrip: rowsPerStrip,
  );
}

/// Previews/thumbnails: IFDs with JPEG compression (7) and non-CFA
/// photometric, carrying strip/byte ranges (the payload IS the JPEG file).
List<DngPreview> _collectPreviews(TiffDocument tif, {required int skipIndex}) {
  final out = <DngPreview>[];
  for (var i = 0; i < tif.ifds.length; i++) {
    if (i == skipIndex) continue;
    final ifd = tif.ifds[i];
    final photometric = ifd.intTag(DngTags.photometricInterpretation);
    if (photometric == 32803) continue; // raw
    final compression = ifd.intTag(DngTags.compression);
    if (compression != 7 && compression != 34892) continue;
    final offsets = ifd.intList(DngTags.stripOffsets);
    final counts = ifd.intList(DngTags.stripByteCounts);
    if (offsets.isEmpty || counts.isEmpty) continue;
    final width = ifd.intTag(DngTags.imageWidth) ?? 0;
    final height = ifd.intTag(DngTags.imageLength) ?? 0;
    if (width <= 0 || height <= 0) continue;
    // Single-strip previews only (DNG writes one JPEG strip); multi-strip
    // JPEG previews are rare — take the largest contiguous run and mark it.
    var bestStart = 0;
    var bestLen = 0;
    for (var s = 0; s < offsets.length && s < counts.length; s++) {
      if (counts[s] > bestLen) {
        bestStart = offsets[s];
        bestLen = counts[s];
      }
    }
    if (bestLen <= 0) continue;
    out.add(DngPreview(i, (bestStart, bestStart + bestLen), width, height));
  }
  return out;
}

/// Slices an embedded preview's JPEG bytes out of the file (zero-copy view).
Uint8List previewBytes(Uint8List file, DngPreview preview) {
  final (start, end) = preview.jpegRange;
  if (start < 0 || end > file.length || end <= start) {
    throw const TiffFormatException('preview range out of bounds');
  }
  return Uint8List.sublistView(file, start, end);
}
