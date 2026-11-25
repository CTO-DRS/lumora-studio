import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumora/features/ai/data/onnx_engine.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:lumora/features/ai/pipelines/ai_pipelines.dart';
import 'package:lumora/features/ai/pipelines/tensor_utils.dart';

/// Result of sky segmentation.
class SkyResult {
  const SkyResult({required this.skyMaskPath, required this.skyFraction});

  /// Feathered white-on-black mask (white = sky) at source resolution.
  final String skyMaskPath;

  /// Fraction (0..1) of pixels classified as sky – lets the UI explain
  /// "no sky found" instead of silently doing nothing.
  final double skyFraction;
}

/// Result of a sky replacement.
class SkyReplaceResult {
  const SkyReplaceResult({required this.imagePath, required this.skyMaskPath, required this.skyFraction});

  /// Source photo with the sky region replaced.
  final String imagePath;
  final String skyMaskPath;
  final double skyFraction;
}

/// Sky segmentation with **SkySeg** (U²-Net fine-tune, int8).
///
/// Input is the static 320×320 ImageNet-normalised tensor; the first output
/// is min-max normalised into a soft matte (like every U²-Net graph) and
/// upsampled to the source resolution, so composited edits keep feathered,
/// non-destructive edges.
class SkyPipeline {
  SkyPipeline(this.engine);

  final InferenceEngine engine;

  static const _inputSize = 320;

  /// Masks with less sky than this are reported as "no sky" by the UI.
  static const minSkyFraction = 0.02;

  Future<SkyResult> run(String imagePath, {int maxSide = 4096}) async {
    final src = await loadRgba(imagePath, maxSide: maxSide);
    final (mask, fraction) = await matte(src);
    return SkyResult(skyMaskPath: await savePng(mask, 'sky_mask'), skyFraction: fraction);
  }

  /// Segments the sky and composites [replacementPath] into it. The
  /// replacement is cover-fitted (scaled + centre-cropped) to the source.
  Future<SkyReplaceResult> replace(String imagePath, String replacementPath, {int maxSide = 4096}) async {
    final src = await loadRgba(imagePath, maxSide: maxSide);
    final (mask, fraction) = await matte(src);
    final replacement = await loadRgba(replacementPath, maxSide: maxSide);
    final fitted = await Isolate.run(() => coverFit(replacement, src.width, src.height));
    final out = await Isolate.run(() => compositeSkyReplacement(src, fitted, mask));
    return SkyReplaceResult(
      imagePath: await savePng(out, 'sky_replaced'),
      skyMaskPath: await savePng(mask, 'sky_mask'),
      skyFraction: fraction,
    );
  }

  /// Runs the model on an in-memory image and returns the feathered sky
  /// matte at source resolution plus the sky fraction (0..1). Public so the
  /// editor and tests can reuse one inference for several edits.
  Future<(RgbaImage, double)> matte(RgbaImage src) async {
    const spec = ModelRegistry.skysegInt8;
    final small = src.resize(_inputSize, _inputSize);
    final input = await Isolate.run(
      () => rgbaToNchw(small, mean: const [0.485, 0.456, 0.406], std: const [0.229, 0.224, 0.225]),
    );
    final out = await engine.run(spec, {
      spec.inputNames.first: (input, [1, 3, _inputSize, _inputSize]),
    });
    return Isolate.run(() {
      final matte = normalizeMinMax(out);
      var sky = 0;
      for (final v in matte) {
        if (v > 0.5) sky++;
      }
      final mask = matteToMask(matte, _inputSize, _inputSize, src.width, src.height);
      return (mask, sky / matte.length);
    });
  }

  /// Scales [src] to completely cover [w]×[h] and centre-crops.
  static RgbaImage coverFit(RgbaImage src, int w, int h) {
    final scale = math.max(w / src.width, h / src.height);
    final sw = math.max(w, (src.width * scale).round());
    final sh = math.max(h, (src.height * scale).round());
    final scaled = src.resize(sw, sh);
    final x0 = (sw - w) ~/ 2;
    final y0 = (sh - h) ~/ 2;
    return scaled.crop(x0, y0, w, h);
  }

  /// out = src·(1−a) + replacement·a with the feathered sky matte as [a].
  static RgbaImage compositeSkyReplacement(RgbaImage src, RgbaImage replacement, RgbaImage skyMask) {
    assert(
      src.width == skyMask.width &&
          src.height == skyMask.height &&
          src.width == replacement.width &&
          src.height == replacement.height,
      'size mismatch',
    );
    final out = Uint8List.fromList(src.pixels);
    final n = src.width * src.height;
    for (var i = 0; i < n; i++) {
      final a = skyMask.pixels[i * 4] / 255;
      if (a <= 0) continue;
      final s = i * 4;
      for (var c = 0; c < 3; c++) {
        out[s + c] = (src.pixels[s + c] * (1 - a) + replacement.pixels[s + c] * a).round().clamp(0, 255);
      }
    }
    return RgbaImage(src.width, src.height, out);
  }
}
