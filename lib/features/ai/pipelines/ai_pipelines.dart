import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:lumora/features/ai/data/onnx_engine.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:lumora/features/ai/pipelines/tensor_utils.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Decodes any supported file into an [RgbaImage] (EXIF orientation baked),
/// optionally capping the long side.
Future<RgbaImage> loadRgba(String path, {int? maxSide}) async {
  final Uint8List bytes;
  try {
    bytes = await File(path).readAsBytes();
  } on FileSystemException catch (e) {
    throw AiException(AiErrorKind.input, detail: '$e');
  }
  return Isolate.run(() {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw const AiException(AiErrorKind.input, detail: 'unsupported or corrupt image');
    var image = img.bakeOrientation(decoded);
    if (maxSide != null && math.max(image.width, image.height) > maxSide) {
      image = image.width >= image.height
          ? img.copyResize(image, width: maxSide, interpolation: img.Interpolation.cubic)
          : img.copyResize(image, height: maxSide, interpolation: img.Interpolation.cubic);
    }
    final rgba = image.convert(numChannels: 4, format: img.Format.uint8);
    return RgbaImage(rgba.width, rgba.height, Uint8List.fromList(rgba.getBytes(order: img.ChannelOrder.rgba)));
  });
}

/// Encodes [image] as PNG into the app's AI cache and returns the path.
Future<String> savePng(RgbaImage image, String prefix) async {
  final dir = Directory(p.join((await getApplicationSupportDirectory()).path, 'ai_cache'));
  if (!dir.existsSync()) await dir.create(recursive: true);
  final path = p.join(dir.path, '${prefix}_${DateTime.now().microsecondsSinceEpoch}.png');
  final bytes = await Isolate.run(
    () => img.encodePng(
      img.Image.fromBytes(
        width: image.width,
        height: image.height,
        bytes: image.pixels.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      ),
      level: 4,
    ),
  );
  await File(path).writeAsBytes(bytes, flush: true);
  return path;
}

// ---------------------------------------------------------------------------
// Segmentation / background removal

class SegmentationResult {
  const SegmentationResult({required this.maskPath, required this.cutoutPath});

  /// Grayscale mask (white = subject) in source resolution.
  final String maskPath;

  /// Source with the background made transparent.
  final String cutoutPath;
}

/// Subject segmentation with U²-Net-p (general objects) or MODNet
/// (portraits).
class SegmentationPipeline {
  SegmentationPipeline(this.engine);
  final InferenceEngine engine;

  Future<SegmentationResult> run(String imagePath, {bool portrait = false}) async {
    final source = await loadRgba(imagePath, maxSide: 4096);
    final model = portrait ? ModelRegistry.modnet : ModelRegistry.u2netp;

    late int mw;
    late int mh;
    late Float32List input;
    if (portrait) {
      (mw, mh) = fitForModel(source.width, source.height, maxSide: 512);
      input = await Isolate.run(
        () => rgbaToNchw(source.resize(mw, mh), mean: const [0.5, 0.5, 0.5], std: const [0.5, 0.5, 0.5]),
      );
    } else {
      mw = mh = model.fixedInputSize!;
      input = await Isolate.run(
        () => rgbaToNchw(source.resize(mw, mh), mean: const [0.485, 0.456, 0.406], std: const [0.229, 0.224, 0.225]),
      );
    }

    final out = await engine.run(model, {
      model.inputNames.first: (input, [1, 3, mh, mw]),
    });

    final w = source.width;
    final h = source.height;
    final (mask, cutout) = await Isolate.run(() {
      final matte = portrait ? Float32List.fromList(out.map((e) => e.toDouble()).toList()) : normalizeMinMax(out);
      final mask = matteToMask(matte, mw, mh, w, h);
      return (mask, applyMaskAsAlpha(source, mask));
    });
    return SegmentationResult(maskPath: await savePng(mask, 'mask'), cutoutPath: await savePng(cutout, 'cutout'));
  }
}

// ---------------------------------------------------------------------------
// Super resolution

/// 4× super resolution with Real-ESRGAN (static 128 px tiles, overlapping and
/// feather-blended). [maxInputSide] keeps memory bounded on phones.
class UpscalePipeline {
  UpscalePipeline(this.engine);
  final InferenceEngine engine;

  static const scale = 4;

  /// Largest input area (≈0.79 MP → ≈12.6 MP output). The accumulation
  /// buffers need 16 bytes per *output* pixel, so this bounds peak memory
  /// to roughly 200 MB plus the result.
  static const int maxInputPixels = 1024 * 768;

  Future<String> run(String imagePath, {int maxInputSide = 1024, void Function(double)? onProgress}) async {
    const model = ModelRegistry.realEsrgan;
    final tile = model.fixedInputSize!;
    var src = await loadRgba(imagePath, maxSide: maxInputSide);
    if (src.width * src.height > maxInputPixels) {
      final k = math.sqrt(maxInputPixels / (src.width * src.height));
      src = src.resize(math.max(1, (src.width * k).floor()), math.max(1, (src.height * k).floor()));
    }
    // Pad tiny images up to a full tile.
    final pw = math.max(src.width, tile);
    final ph = math.max(src.height, tile);
    final origW = src.width;
    final origH = src.height;
    if (pw != src.width || ph != src.height) src = _padEdge(src, pw, ph);

    final tiles = planSrTiles(pw, ph, tile: tile);
    final outW = pw * scale;
    final outH = ph * scale;
    final acc = Float32List(outW * outH * 3);
    final wsum = Float32List(outW * outH);
    final ot = tile * scale;
    final weights = _featherWeights(ot, 8 * scale);

    for (var i = 0; i < tiles.length; i++) {
      final t = tiles[i];
      final input = rgbaToNchw(src.crop(t.x, t.y, tile, tile));
      final out = await engine.run(model, {
        model.inputNames.first: (input, [1, 3, tile, tile]),
      });
      final plane = ot * ot;
      for (var y = 0; y < ot; y++) {
        final oy = t.y * scale + y;
        for (var x = 0; x < ot; x++) {
          final ox = t.x * scale + x;
          final wgt = weights[y * ot + x];
          final o = oy * outW + ox;
          final s = y * ot + x;
          acc[o * 3] += out[s].toDouble() * wgt;
          acc[o * 3 + 1] += out[plane + s].toDouble() * wgt;
          acc[o * 3 + 2] += out[2 * plane + s].toDouble() * wgt;
          wsum[o] += wgt;
        }
      }
      onProgress?.call((i + 1) / tiles.length);
    }

    final cropW = origW * scale;
    final cropH = origH * scale;
    // Normalised in place on this isolate (Isolate.run would copy the
    // ~200 MB accumulation buffers), yielding to the UI every few rows.
    final result = RgbaImage(cropW, cropH);
    for (var y = 0; y < cropH; y++) {
      for (var x = 0; x < cropW; x++) {
        final o = y * outW + x;
        final w = wsum[o] == 0 ? 1 : wsum[o];
        final d = (y * cropW + x) * 4;
        result.pixels[d] = (acc[o * 3] / w * 255).round().clamp(0, 255);
        result.pixels[d + 1] = (acc[o * 3 + 1] / w * 255).round().clamp(0, 255);
        result.pixels[d + 2] = (acc[o * 3 + 2] / w * 255).round().clamp(0, 255);
        result.pixels[d + 3] = 255;
      }
      if (y % 64 == 63) await Future<void>.delayed(Duration.zero);
    }
    return savePng(result, 'upscaled');
  }

  static Float32List _featherWeights(int size, int ramp) {
    final w = Float32List(size * size);
    double f(int i) {
      final d = math.min(i, size - 1 - i);
      return d >= ramp ? 1 : (d + 1) / (ramp + 1);
    }

    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        w[y * size + x] = f(x) * f(y);
      }
    }
    return w;
  }

  static RgbaImage _padEdge(RgbaImage s, int w, int h) {
    final out = RgbaImage(w, h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final sx = math.min(x, s.width - 1);
        final sy = math.min(y, s.height - 1);
        final si = (sy * s.width + sx) * 4;
        final di = (y * w + x) * 4;
        out.pixels.setRange(di, di + 4, s.pixels, si);
      }
    }
    return out;
  }
}

// ---------------------------------------------------------------------------
// Inpainting / object eraser

enum InpaintModel { migan, lama }

/// Object eraser. Only a context window around the painted mask is sent to
/// the model, and the result is feather-composited back into the full
/// resolution image, so quality does not depend on photo size.
class InpaintPipeline {
  InpaintPipeline(this.engine);
  final InferenceEngine engine;

  /// [maskRgba] is a white-on-black mask the size of the image at
  /// [imagePath] (white = remove).
  /// Long-side cap for the photo the eraser works on. Full-resolution
  /// 48–200 MP photos need several copies of their RGBA buffer and can get
  /// the app killed for memory.
  static const maxSide = 4096;

  Future<String> run(String imagePath, RgbaImage maskRgba, {InpaintModel model = InpaintModel.migan}) async {
    final source = await loadRgba(imagePath, maxSide: maxSide);
    final mask = maskRgba.width == source.width && maskRgba.height == source.height
        ? maskRgba
        : maskRgba.resize(source.width, source.height);
    final dilated = await Isolate.run(() => dilateMask(mask, math.max(3, source.width ~/ 300)));
    final bounds = maskBounds(dilated);
    if (bounds == null) return imagePath;

    // Context window: mask bbox grown by 1x its size (min 256 px), square.
    final (bx, by, bw, bh) = bounds;
    final side = math.min(math.max(math.max(bw, bh) * 2, 256), math.min(source.width, source.height));
    final cx = bx + bw ~/ 2;
    final cy = by + bh ~/ 2;
    final x0 = (cx - side ~/ 2).clamp(0, source.width - side);
    final y0 = (cy - side ~/ 2).clamp(0, source.height - side);
    final crop = source.crop(x0, y0, side, side);
    final cropMask = dilated.crop(x0, y0, side, side);

    final RgbaImage filled;
    switch (model) {
      case InpaintModel.migan:
        const spec = ModelRegistry.migan;
        final n = math.min(512, roundUpTo(side, 8));
        final img = crop.resize(n, n);
        final m = cropMask.resize(n, n);
        final maskT = Uint8List(n * n);
        for (var i = 0; i < n * n; i++) {
          maskT[i] = m.pixels[i * 4] > 127 ? 0 : 255; // 0 = erase
        }
        final out = await engine.run(spec, {
          'image': (rgbaToNchwUint8(img), [1, 3, n, n]),
          'mask': (maskT, [1, 1, n, n]),
        });
        filled = nchwToRgba(out, n, n, scale: 1).resize(side, side);
      case InpaintModel.lama:
        const spec = ModelRegistry.lama;
        const n = 512;
        final img = crop.resize(n, n);
        final m = cropMask.resize(n, n);
        final maskT = Float32List(n * n);
        for (var i = 0; i < n * n; i++) {
          maskT[i] = m.pixels[i * 4] > 127 ? 1 : 0; // 1 = erase
        }
        final out = await engine.run(spec, {
          'image': (rgbaToNchw(img), [1, 3, n, n]),
          'mask': (maskT, [1, 1, n, n]),
        });
        var maxV = 0.0;
        for (final v in out) {
          if (v > maxV) maxV = v.toDouble();
        }
        filled = nchwToRgba(out, n, n, scale: maxV <= 1.5 ? 255 : 1).resize(side, side);
    }

    // Feathered composite of the generated pixels inside the mask only.
    final result = await Isolate.run(() {
      final out = RgbaImage(source.width, source.height, Uint8List.fromList(source.pixels));
      final soft = cropMask; // already dilated
      for (var y = 0; y < side; y++) {
        for (var x = 0; x < side; x++) {
          final a = soft.pixels[(y * side + x) * 4] / 255;
          if (a <= 0) continue;
          final s = (y * side + x) * 4;
          final d = ((y0 + y) * source.width + (x0 + x)) * 4;
          for (var c = 0; c < 3; c++) {
            out.pixels[d + c] = (out.pixels[d + c] * (1 - a) + filled.pixels[s + c] * a).round();
          }
        }
      }
      return out;
    });
    return savePng(result, 'erased');
  }
}

// ---------------------------------------------------------------------------
// Portrait retouch hooks

/// Portrait retouch built on the matting model: returns a subject mask that
/// the editor turns into a masked local adjustment (skin smoothing via
/// negative clarity/structure, subtle exposure lift and warmth).
///
/// Hook: a face-landmark model (e.g. MediaPipe FaceMesh exported to ONNX)
/// can refine the mask to skin-only regions and enable eye/teeth tools –
/// see ROADMAP.md.
class PortraitRetouchPipeline {
  PortraitRetouchPipeline(this.segmentation);
  final SegmentationPipeline segmentation;

  Future<String> subjectMask(String imagePath) async => (await segmentation.run(imagePath, portrait: true)).maskPath;
}
