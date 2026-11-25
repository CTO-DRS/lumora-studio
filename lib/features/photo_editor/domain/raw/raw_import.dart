/// RAW import (Wave 2 W2 M2-1): turns a picked DNG file into an image the
/// editor's normal pipeline can open, fully on-device.
///
/// Two paths, both off the UI thread (`Isolate.run`):
/// 1. **Full decode** — parse the TIFF structure, classify the CFA raw IFD,
///    decode the strips (uncompressed / Adobe-deflate), normalise by
///    black/white level, bilinear-demosaic → 8-bit sRGB PNG.
/// 2. **Preview fallback** — when the raw payload needs an unimplemented
///    decoder (lossless JPEG, the phone-default compression) the largest
///    embedded preview JPEG is decoded instead, and the honest reason is
///    carried back to the UI ("preview shown, full decode lands next").
///
/// Corrupt or malicious files raise [TiffFormatException] / return a
/// [RawImportFailure] — they never crash the app (roadmap fuzz gate).
library;

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:lumora/features/ai/pipelines/tensor_utils.dart';
import 'package:lumora/features/photo_editor/domain/raw/colour_render.dart';
import 'package:lumora/features/photo_editor/domain/raw/dng_decoder.dart';
import 'package:lumora/features/photo_editor/domain/raw/dng_document.dart';
import 'package:lumora/features/photo_editor/domain/raw/tiff_parser.dart';
import 'package:path/path.dart' as p;

/// Outcome of [importDng].
sealed class RawImportResult {
  const RawImportResult();
}

/// Success: an editable PNG lives at [path] inside the app's cache.
class RawImportSuccess extends RawImportResult {
  const RawImportSuccess({required this.path, required this.width, required this.height, required this.fromPreview, this.reason});

  final String path;
  final int width;
  final int height;

  /// True when only the embedded preview could be decoded (raw payload not
  /// decodable yet) — the UI tells the user honestly.
  final bool fromPreview;

  /// Plain-language reason when [fromPreview] (null on a full decode).
  final String? reason;
}

/// Failure: the file is not a decodable RAW at all (or too corrupt).
class RawImportFailure extends RawImportResult {
  const RawImportFailure(this.message);

  /// Plain-language, user-safe message (no stack traces, no paths).
  final String message;
}

/// Cheap header sniff used before committing to the picker extension filter:
/// TIFF magic `II*\0` / `MM\0*` — enough for the UI to route a `.dng` (or a
/// renamed TIFF) into the RAW path.
bool looksLikeDng(Uint8List bytes) {
  if (bytes.length < 4) return false;
  final b0 = bytes[0];
  final b1 = bytes[1];
  final b2 = bytes[2];
  final b3 = bytes[3];
  final littleEndian = b0 == 0x49 && b1 == 0x49;
  final bigEndian = b0 == 0x4D && b1 == 0x4D;
  if (!littleEndian && !bigEndian) return false;
  final magic = littleEndian ? (b2 | (b3 << 8)) : ((b2 << 8) | b3);
  return magic == 42;
}

/// Extension set that routes a picked file into the RAW pipeline.
const rawImportExtensions = ['dng', 'tif', 'tiff'];

/// Imports [sourcePath] (a DNG/TIFF picked by the user) into an editable
/// PNG under the app's AI cache. Never throws — every failure becomes a
/// [RawImportFailure] with a plain message.
Future<RawImportResult> importDng(String sourcePath) async {
  try {
    final bytes = await File(sourcePath).readAsBytes();
    if (!looksLikeDng(bytes)) {
      return const RawImportFailure('not a TIFF/DNG file');
    }
    return await Isolate.run(() => _decodeDng(bytes));
  } on TiffFormatException catch (e) {
    return RawImportFailure('corrupt or unsupported TIFF/DNG (${e.reason})');
  } on RawUnsupportedException {
    // Handled inside _decodeDng via the preview fallback; reaching here
    // means even the fallback classification failed.
    return const RawImportFailure('unsupported DNG raw data');
  } on FileSystemException {
    return const RawImportFailure('file could not be read');
  }
}

/// The isolate body: parse → classify → decode (raw first, preview as the
/// honest fallback) → encode PNG → return the result with the saved path.
RawImportResult _decodeDng(Uint8List bytes) {
  final doc = parseDng(bytes);

  // 1. Direct CFA decode attempt (any decode failure falls through to the
  //    embedded preview — the user still gets their photo, with a reason).
  var failure = 'raw data uses an unsupported compression';
  if (doc.cfa.isDirectlyDecodable) {
    try {
      final bayer = decodeCfa(bytes, doc);
      final demosaiced = demosaicBilinear(bayer, doc.cfa.pattern, doc.cfa.blackLevel, doc.cfa.whiteLevel);
      // M2-4: camera-neutral colour — white balance + ColorMatrix1 +
      // highlight recovery. Files without colour metadata keep the legacy
      // identity path inside renderRawSrgb (wb/matrix skipped, shoulder on).
      final rgba = renderRawSrgb(
        demosaiced,
        asShotNeutral: doc.cfa.asShotNeutral.isEmpty ? null : doc.cfa.asShotNeutral,
        colorMatrix1: doc.cfa.colorMatrix1.isEmpty ? null : doc.cfa.colorMatrix1,
      );
      final path = _savePng(rgba, 'raw_open');
      return RawImportSuccess(path: path, width: rgba.width, height: rgba.height, fromPreview: false);
    } on TiffFormatException catch (e) {
      failure = 'raw decode failed: ${e.reason}';
    } on RawUnsupportedException catch (e) {
      failure = e.message;
    }
  }

  // 2. Preview fallback: embedded JPEG + the honest reason carried up.
  final preview = doc.bestPreview;
  if (preview != null) {
    final jpeg = previewBytes(bytes, preview);
    final decoded = img.decodeJpg(jpeg);
    if (decoded != null) {
      final rgba = decoded.convert(numChannels: 4, format: img.Format.uint8);
      final image = RgbaImage(rgba.width, rgba.height, Uint8List.fromList(rgba.getBytes(order: img.ChannelOrder.rgba)));
      final path = _savePng(image, 'raw_preview');
      return RawImportSuccess(
        path: path,
        width: image.width,
        height: image.height,
        fromPreview: true,
        reason: failure,
      );
    }
  }
  return RawImportFailure(failure);
}

/// Encodes [image] as PNG into the app's AI cache (same folder as the
/// editor's model outputs) and returns the path.
String _savePng(RgbaImage image, String prefix) {
  final dir = Directory(p.join(_cacheDirSync(), 'ai_cache'));
  if (!dir.existsSync()) dir.createSync(recursive: true);
  final path = p.join(dir.path, '${prefix}_${DateTime.now().microsecondsSinceEpoch}.png');
  final bytes = img.encodePng(
    img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: image.pixels.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    ),
  );
  File(path).writeAsBytesSync(bytes);
  return path;
}

/// Synchronous cache root (this runs inside a worker isolate, where
/// `getApplicationSupportDirectory`'s plugin hop is unavailable).
String _cacheDirSync() {
  if (Platform.environment.containsKey('HOME') && !Platform.isAndroid && !Platform.isIOS) {
    // Desktop/test hosts: keep it under the home dir like path_provider does.
    return p.join(Platform.environment['HOME']!, '.lumora');
  }
  // Android: the app-support dir is not reachable synchronously; use the
  // cache dir from TMPDIR (Flutter sets it to the app cache path).
  return Platform.environment['TMPDIR'] ?? Directory.systemTemp.path;
}
