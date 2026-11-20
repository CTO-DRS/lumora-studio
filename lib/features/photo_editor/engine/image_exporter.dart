import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:lumora/features/photo_editor/domain/edit_state.dart';
import 'package:lumora/features/photo_editor/domain/geometry.dart';
import 'package:lumora/features/photo_editor/engine/finishing_renderer.dart';
import 'package:lumora/features/photo_editor/engine/photo_renderer.dart';
import 'package:lumora/features/photo_editor/engine/pixel_ops.dart';
import 'package:lumora/features/photo_editor/engine/tiling.dart';
import 'package:native_exif/native_exif.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum ExportFormat {
  jpeg('jpg'),
  png('png'),
  webp('webp'),
  heic('heic');

  const ExportFormat(this.extension);
  final String extension;
}

class ExportOptions {
  const ExportOptions({
    this.format = ExportFormat.jpeg,
    this.quality = 95,
    this.keepExif = true,
    this.maxDimension,
    this.social = SocialSize.original,
    this.socialFit = SocialFit.pad,
    this.padColor = 0xFFFFFFFF,
    this.padBlur = true,
    this.saveToGallery = true,
  });

  final ExportFormat format;
  final int quality;
  final bool keepExif;

  /// Optional downscale (long edge) – null exports at full resolution.
  final int? maxDimension;

  /// Social network size preset (crop or pad to its aspect, then resize).
  final SocialSize social;
  final SocialFit socialFit;
  final int padColor;
  final bool padBlur;

  /// Also copy the file into the gallery (album "Lumora").
  final bool saveToGallery;
}

class RenderedPixels {
  const RenderedPixels(this.rgba, this.width, this.height);
  final Uint8List rgba;
  final int width;
  final int height;
}

/// Full resolution export. Images up to [gpuLimit] px are rendered in one
/// GPU pass; larger images are decoded on a background isolate and rendered
/// tile by tile (geometry on the CPU, colour pipeline on the GPU) so memory
/// and texture size stay bounded.
class ImageExporter {
  ImageExporter(this.renderer, {this.gpuLimit = 8192, this.tileSize = 2048});

  final PhotoRenderer renderer;
  final int gpuLimit;
  final int tileSize;

  Future<RenderedPixels> renderFullResolution(
    String sourcePath,
    EditState state, {
    void Function(double progress)? onProgress,
  }) async {
    final path = state.rasterPath ?? sourcePath;
    final bytes = await File(path).readAsBytes();
    await renderer.prepare(state);

    final descriptor = await ui.ImageDescriptor.encoded(await ui.ImmutableBuffer.fromUint8List(bytes));
    final big = math.max(descriptor.width, descriptor.height) > gpuLimit;
    descriptor.dispose();

    if (!big) {
      final codec = await ui.instantiateImageCodec(bytes);
      final src = (await codec.getNextFrame()).image;
      final out = renderer.render(src, state);
      final data = await out.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      final result = RenderedPixels(data!.buffer.asUint8List(), out.width, out.height);
      src.dispose();
      out.dispose();
      onProgress?.call(1);
      return result;
    }
    return _renderTiled(bytes, state, onProgress);
  }

  Future<RenderedPixels> _renderTiled(
    Uint8List bytes,
    EditState state,
    void Function(double progress)? onProgress,
  ) async {
    final decoded = await Isolate.run(() {
      final image = img.bakeOrientation(img.decodeImage(bytes)!);
      final rgba = image.convert(numChannels: 4, format: img.Format.uint8);
      return (rgba.getBytes(order: img.ChannelOrder.rgba), rgba.width, rgba.height);
    });
    final (srcRgba, sw, sh) = decoded;
    final geo = state.geometry;
    final (ow, oh) = geo.outputSize(sw, sh);
    final inverse = buildInverseWarp(geo, sw, sh, ow, oh).m;
    final out = Uint8List(ow * oh * 4);
    final tiles = planTiles(ow, oh, tileSize: tileSize);

    for (var i = 0; i < tiles.length; i++) {
      final t = tiles[i];
      final req = WarpTileRequest(
        src: srcRgba,
        srcWidth: sw,
        srcHeight: sh,
        inverse: inverse,
        tileX: t.paddedX,
        tileY: t.paddedY,
        tileWidth: t.paddedWidth,
        tileHeight: t.paddedHeight,
      );
      final warped = await compute(warpTileCpu, req);
      final tileImg = await imageFromRgba(warped, t.paddedWidth, t.paddedHeight);
      final rendered = renderer.render(
        tileImg,
        state,
        target: RenderTarget.tile(
          tileOffset: ui.Offset(t.paddedX.toDouble(), t.paddedY.toDouble()),
          fullSize: ui.Size(ow.toDouble(), oh.toDouble()),
        ),
      );
      final data = await rendered.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      blitTile(out, ow, data!.buffer.asUint8List(), t);
      tileImg.dispose();
      rendered.dispose();
      onProgress?.call((i + 1) / tiles.length);
    }
    return RenderedPixels(out, ow, oh);
  }

  /// Applies frame, watermark and the social size preset of [options].
  Future<RenderedPixels> finish(
    RenderedPixels pixels,
    EditState state,
    ExportOptions options,
    FinishingRenderer finishing,
  ) async {
    var out = await finishing.finish(Rgba(pixels.width, pixels.height, pixels.rgba), state);
    final social = options.social;
    if (social != SocialSize.original) {
      final src = out;
      final fit = options.socialFit;
      final pad = options.padColor;
      final blur = options.padBlur;
      out = await Isolate.run(() => fitSocial(src, social, fit: fit, padColor: pad, blur: blur));
    }
    return RenderedPixels(out.data, out.width, out.height);
  }

  /// Encodes [pixels] and writes them to the app's export directory.
  Future<File> encodeAndSave(RenderedPixels pixels, ExportOptions options, {String? exifSourcePath}) async {
    final dir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'exports'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    final file = File(p.join(dir.path, 'Lumora_${DateTime.now().millisecondsSinceEpoch}.${options.format.extension}'));

    final rgba = pixels.rgba;
    final w = pixels.width;
    final h = pixels.height;
    final maxDim = options.maxDimension;
    final quality = options.quality;

    Future<Uint8List> encodeWith(ExportFormat f) => Isolate.run(() {
      var image = img.Image.fromBytes(
        width: w,
        height: h,
        bytes: rgba.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );
      if (maxDim != null && math.max(w, h) > maxDim) {
        image = w >= h
            ? img.copyResize(image, width: maxDim, interpolation: img.Interpolation.cubic)
            : img.copyResize(image, height: maxDim, interpolation: img.Interpolation.cubic);
      }
      return switch (f) {
        ExportFormat.png => img.encodePng(image),
        _ => img.encodeJpg(image, quality: quality),
      };
    });

    final Uint8List encoded;
    switch (options.format) {
      case ExportFormat.jpeg:
      case ExportFormat.png:
        encoded = await encodeWith(options.format);
      case ExportFormat.webp:
      case ExportFormat.heic:
        // Platform encoders (Android Bitmap / iOS ImageIO) via
        // flutter_image_compress. A lossless PNG is used as intermediate.
        final png = await encodeWith(ExportFormat.png);
        encoded = await FlutterImageCompress.compressWithList(
          png,
          minWidth: w,
          minHeight: h,
          quality: quality,
          format: options.format == ExportFormat.webp ? CompressFormat.webp : CompressFormat.heic,
        );
    }
    await file.writeAsBytes(encoded, flush: true);

    if (options.keepExif && exifSourcePath != null && options.format == ExportFormat.jpeg) {
      await copyExif(exifSourcePath, file.path);
    }
    return file;
  }

  /// Copies descriptive EXIF tags (camera, lens, exposure, date, GPS) from
  /// the original. Orientation is reset because it is baked into pixels.
  static Future<void> copyExif(String from, String to) async {
    Exif? src;
    Exif? dst;
    try {
      src = await Exif.fromPath(from);
      final attrs = await src.getAttributes();
      if (attrs == null || attrs.isEmpty) return;
      const keep = {
        'Make',
        'Model',
        'LensModel',
        'LensMake',
        'DateTimeOriginal',
        'DateTimeDigitized',
        'DateTime',
        'ExposureTime',
        'FNumber',
        'ISOSpeedRatings',
        'PhotographicSensitivity',
        'FocalLength',
        'FocalLengthIn35mmFilm',
        'GPSLatitude',
        'GPSLatitudeRef',
        'GPSLongitude',
        'GPSLongitudeRef',
        'GPSAltitude',
        'GPSAltitudeRef',
        'Artist',
        'Copyright',
        'WhiteBalance',
        'Flash',
        'ExposureBiasValue',
      };
      final filtered = <String, Object>{
        for (final e in attrs.entries)
          if (keep.contains(e.key)) e.key: e.value,
        'Software': 'Lumora Studio',
        'Orientation': '1',
      };
      dst = await Exif.fromPath(to);
      await dst.writeAttributes(filtered);
    } on Object catch (e) {
      debugPrint('EXIF copy skipped: $e');
    } finally {
      await src?.close();
      await dst?.close();
    }
  }
}
