import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumora/features/ai/data/onnx_engine.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:lumora/features/ai/pipelines/ai_pipelines.dart';
import 'package:lumora/features/ai/pipelines/tensor_utils.dart';

/// Built-in replacement skies (v1.4 "Sky & scene"): procedural vertical
/// gradients — no external assets, no network. The gradient is anchored to
/// the detected sky span (top of the mask → horizon at its bottom edge) so
/// the replacement lands where the real sky was.
enum SkyPreset {
  sunset,
  clear,
  storm,
  golden;

  /// Gradient colours, top of the sky → horizon (RGB).
  (List<int>, List<int>) get stops => switch (this) {
    SkyPreset.sunset => ([24, 34, 74], [255, 138, 84]),
    SkyPreset.clear => ([56, 132, 224], [168, 214, 240]),
    SkyPreset.storm => ([36, 42, 58], [110, 118, 130]),
    SkyPreset.golden => ([58, 48, 84], [252, 186, 110]),
  };
}

/// The decoded sky map: a 0..1 matte over the 320×320 model input (min-max
/// normalised, U²-Net style) plus the fraction of pixels classified as sky.
class SkyResult {
  const SkyResult(this.matte, this.side, this.fraction);

  final Float32List matte;
  final int side;

  /// Fraction of the photo classified as sky (matte > 0.5).
  final double fraction;

  /// Bilinear sample of the matte at normalised coordinates (0..1).
  double sample(double u, double v) {
    final fx = (u * side - 0.5).clamp(0.0, side - 1.0);
    final fy = (v * side - 0.5).clamp(0.0, side - 1.0);
    final x0 = fx.floor();
    final y0 = fy.floor();
    final x1 = math.min(x0 + 1, side - 1);
    final y1 = math.min(y0 + 1, side - 1);
    final ax = fx - x0;
    final ay = fy - y0;
    final i00 = matte[y0 * side + x0];
    final i10 = matte[y0 * side + x1];
    final i01 = matte[y1 * side + x0];
    final i11 = matte[y1 * side + x1];
    final top = i00 * (1 - ax) + i10 * ax;
    final bot = i01 * (1 - ax) + i11 * ax;
    return (top * (1 - ay) + bot * ay).clamp(0.0, 1.0);
  }

  /// Vertical span of the sky in normalised rows `(top, bottom)`, or null
  /// when there is no meaningful sky (> 512 px above threshold required).
  (double, double)? skySpan({double threshold = 0.5}) {
    double? top;
    var bottom = 0.0;
    for (var y = 0; y < side; y++) {
      var row = 0;
      for (var x = 0; x < side; x++) {
        if (matte[y * side + x] > threshold) row++;
      }
      if (row > side / 4) {
        top ??= y / side;
        bottom = y / side;
      }
    }
    if (top == null) return null;
    return (top, math.max(bottom, top + 1 / side));
  }
}

/// Sky segmentation (v1.4 "Sky & scene"): runs the quantised U²-Net sky
/// model (44.2 MB int8, MIT — derived from the U-2-Net sky-segmentation
/// weights, see docs/SMART_EDIT.md) on the 320×320 proxy and decodes the
/// first of its seven outputs as the sky matte. The caller must only run
/// this when the model is already installed (`ModelManager.isInstalled`) —
/// sky tools never download it implicitly.
///
/// Preprocessing is the reference contract: RGB 0..1, ImageNet mean/std
/// normalisation, static 320×320 input; the final output is min-max
/// normalised per image and thresholded at 0.5 (see docs/SMART_EDIT.md).
class SkyPipeline {
  SkyPipeline(this.engine);

  final InferenceEngine engine;

  static const ModelSpec _spec = ModelRegistry.skySegQ8;
  static const int _side = 320;

  Future<SkyResult> analyze(RgbaImage src) async {
    final (tensor, shape) = await Isolate.run(() {
      final t = rgbaToNchw(
        src.resize(_side, _side),
        mean: const [0.485, 0.456, 0.406],
        std: const [0.229, 0.224, 0.225],
      );
      return (t, <int>[1, 3, _side, _side]);
    });
    final out = await engine.run(_spec, {_spec.inputNames.first: (tensor, shape)});
    if (out.length != _side * _side) {
      throw AiException(AiErrorKind.inference, model: _spec, detail: 'unexpected sky map length ${out.length}');
    }
    return await Isolate.run(() {
      final matte = normalizeMinMax(out);
      var sky = 0;
      for (final v in matte) {
        if (v > 0.5) sky++;
      }
      return SkyResult(matte, _side, sky / matte.length);
    });
  }

  /// Builds the soft sky mask at the raster's size and encodes it as PNG.
  Future<String> maskPath(RgbaImage raster) async {
    final sky = await analyze(raster);
    final mask = await Isolate.run(() => matteToMask(sky.matte, _side, _side, raster.width, raster.height));
    return savePng(mask, 'sky');
  }
}

/// Composites a procedural [preset] gradient sky over [raster] through the
/// soft [sky] matte. Pure function (isolate friendly, unit tested).
RgbaImage compositeSky(RgbaImage raster, SkyResult sky, SkyPreset preset) {
  final (topRGB, bottomRGB) = preset.stops;
  final span = sky.skySpan() ?? (0.0, 1.0);
  final (spanTop, spanBottom) = span;
  final out = Uint8List.fromList(raster.pixels);
  final w = raster.width;
  final h = raster.height;
  for (var y = 0; y < h; y++) {
    final v = y / math.max(1, h - 1);
    // Anchor the gradient to the detected sky span: t = 0 at the top of the
    // sky, t = 1 at its bottom edge (the horizon).
    final t = ((v - spanTop) / math.max(1e-6, spanBottom - spanTop)).clamp(0.0, 1.0);
    final r = topRGB[0] + (bottomRGB[0] - topRGB[0]) * t;
    final g = topRGB[1] + (bottomRGB[1] - topRGB[1]) * t;
    final b = topRGB[2] + (bottomRGB[2] - topRGB[2]) * t;
    for (var x = 0; x < w; x++) {
      final a = sky.sample(x / math.max(1, w - 1), v);
      if (a <= 0.002) continue;
      final o = (y * w + x) * 4;
      out[o] = (out[o] * (1 - a) + r * a).round();
      out[o + 1] = (out[o + 1] * (1 - a) + g * a).round();
      out[o + 2] = (out[o + 2] * (1 - a) + b * a).round();
    }
  }
  return RgbaImage(w, h, out);
}
