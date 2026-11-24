import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show immutable;
import 'package:lumora/features/ai/data/onnx_engine.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:lumora/features/ai/pipelines/ai_pipelines.dart';
import 'package:lumora/features/ai/pipelines/tensor_utils.dart';

// ---------------------------------------------------------------------------
// Tap to select (MobileSAM)

/// A prompt point, normalised (0..1) to the *source* raster.
@immutable
class SelectPoint {
  const SelectPoint(this.x, this.y, {this.positive = true});

  final double x;
  final double y;

  /// `true` adds the region under the point, `false` subtracts it.
  final bool positive;

  @override
  bool operator ==(Object other) => other is SelectPoint && other.x == x && other.y == y && other.positive == positive;

  @override
  int get hashCode => Object.hash(x, y, positive);
}

/// A drag box prompt, normalised (0..1) to the *source* raster.
@immutable
class SelectBox {
  const SelectBox(this.left, this.top, this.right, this.bottom);

  final double left;
  final double top;
  final double right;
  final double bottom;

  @override
  bool operator ==(Object other) =>
      other is SelectBox && other.left == left && other.top == top && other.right == right && other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);
}

/// The decoder's answer for one prompt: the three SAM candidate masks with
/// their IoU prediction, best candidate first. [masks] and [scores] are
/// parallel; `best` is `masks.first`.
class SelectCandidates {
  SelectCandidates(List<RgbaImage> masks, List<double> scores)
    : assert(masks.length == scores.length, 'masks and scores must be parallel'),
      assert(masks.isNotEmpty, 'a decode always yields at least one candidate'),
      _n = masks.length {
    final order = [for (var i = 0; i < masks.length; i++) i]..sort((a, b) => scores[b].compareTo(scores[a]));
    this.masks = [for (final i in order) masks[i]];
    this.scores = [for (final i in order) scores[i]];
  }

  late final List<RgbaImage> masks;
  late final List<double> scores;
  final int _n;

  int get count => _n;
  RgbaImage get best => masks.first;

  @override
  String toString() => 'SelectCandidates($masks, $scores)';
}

/// Size the MobileSAM encoder expects: long side exactly 1024 px.
(int, int) samInputSize(int w, int h) {
  const side = 1024;
  final k = side / math.max(w, h);
  return (math.max(1, (w * k).round()), math.max(1, (h * k).round()));
}

/// RGBA → HWC float tensor with values 0..255 (the encoder graph does its
/// own mean/std normalisation and padding).
Float32List rgbaToHwcFloat(RgbaImage img) {
  final n = img.width * img.height;
  final out = Float32List(n * 3);
  final px = img.pixels;
  for (var i = 0; i < n; i++) {
    out[i * 3] = px[i * 4].toDouble();
    out[i * 3 + 1] = px[i * 4 + 1].toDouble();
    out[i * 3 + 2] = px[i * 4 + 2].toDouble();
  }
  return out;
}

/// Decoder prompt tensors in an encoder frame of [rw]x[rh]. With a [box],
/// its corners come first (SAM labels 2/3) and no padding point is used;
/// without one, the padding point SAM expects (label −1) is appended after
/// the [points] (labels 1 = add, 0 = subtract).
(Float32List, Float32List, int) samPrompt(List<SelectPoint> points, SelectBox? box, int rw, int rh) {
  final hasBox = box != null;
  final n = points.length + (hasBox ? 2 : 1);
  final coords = Float32List(n * 2);
  final labels = Float32List(n);
  for (var i = 0; i < points.length; i++) {
    coords[i * 2] = points[i].x.clamp(0.0, 1.0) * rw;
    coords[i * 2 + 1] = points[i].y.clamp(0.0, 1.0) * rh;
    labels[i] = points[i].positive ? 1 : 0;
  }
  if (hasBox) {
    coords[points.length * 2] = box.left.clamp(0.0, 1.0) * rw;
    coords[points.length * 2 + 1] = box.top.clamp(0.0, 1.0) * rh;
    coords[points.length * 2 + 2] = box.right.clamp(0.0, 1.0) * rw;
    coords[points.length * 2 + 3] = box.bottom.clamp(0.0, 1.0) * rh;
    labels[points.length] = 2;
    labels[points.length + 1] = 3;
  } else {
    labels[n - 1] = -1;
  }
  return (coords, labels, n);
}

/// Mask logits (`> 0` = selected) → white-on-black RGBA mask.
RgbaImage logitsToMask(List<num> logits, int w, int h) {
  final out = RgbaImage(w, h);
  final px = out.pixels;
  for (var i = 0; i < w * h; i++) {
    final v = logits[i] > 0 ? 255 : 0;
    px[i * 4] = v;
    px[i * 4 + 1] = v;
    px[i * 4 + 2] = v;
    px[i * 4 + 3] = 255;
  }
  return out;
}

/// Fraction of [mask] pixels that are selected (> 127).
double maskCoverage(RgbaImage mask) {
  final n = mask.width * mask.height;
  if (n == 0) return 0;
  var on = 0;
  for (var i = 0; i < n; i++) {
    if (mask.pixels[i * 4] > 127) on++;
  }
  return on / n;
}

/// Interactive object selection: the image is encoded once (≈1–3 s on a
/// phone CPU), then every tap only runs the light decoder (≈50–150 ms).
class ObjectSelectPipeline {
  ObjectSelectPipeline(this.engine);
  final InferenceEngine engine;

  String? _path;
  Float32List? _embedding;
  int _rw = 0;
  int _rh = 0;

  /// Encoder frame size of the prepared image.
  (int, int) get frameSize => (_rw, _rh);

  bool isPreparedFor(String path) => _path == path && _embedding != null;

  /// Encodes [imagePath] (cached until another image is prepared).
  Future<void> prepare(String imagePath) async {
    if (isPreparedFor(imagePath)) return;
    final src = await loadRgba(imagePath, maxSide: 2048);
    await prepareRgba(imagePath, src);
  }

  /// Encodes an already decoded image under [key].
  Future<void> prepareRgba(String key, RgbaImage src) async {
    clear();
    final (rw, rh) = samInputSize(src.width, src.height);
    final input = await Isolate.run(() => rgbaToHwcFloat(src.resize(rw, rh)));
    const spec = ModelRegistry.mobileSamEncoder;
    final out = await engine.run(spec, {
      spec.inputNames.first: (input, [rh, rw, 3]),
    });
    if (out.length != 256 * 64 * 64) {
      throw AiException(AiErrorKind.inference, model: spec, detail: 'unexpected embedding size ${out.length}');
    }
    final emb = Float32List(out.length);
    for (var i = 0; i < out.length; i++) {
      emb[i] = out[i].toDouble();
    }
    _embedding = emb;
    _path = key;
    _rw = rw;
    _rh = rh;
  }

  /// Best candidate mask for [points] (the tap-only convenience API).
  Future<RgbaImage> maskFor(List<SelectPoint> points) async => (await decode(points: points)).best;

  /// Runs the decoder for a prompt of [points] and/or a [box], optionally
  /// refined by a 256×256 low-res [maskInput] painted by the user (brush
  /// refine). Returns the three SAM candidates with their IoU prediction,
  /// best first. One decoder run per call (≈ 100 ms on the sandbox CPU).
  Future<SelectCandidates> decode({List<SelectPoint> points = const [], SelectBox? box, Float32List? maskInput}) async {
    final emb = _embedding;
    if (emb == null || (points.isEmpty && box == null)) {
      throw StateError('prepare() an image and add a point or a box first');
    }
    final (coords, labels, n) = samPrompt(points, box, _rw, _rh);
    const spec = ModelRegistry.mobileSamDecoderMulti;
    final out = await engine.runNamed(
      spec,
      {
        'image_embeddings': (emb, const [1, 256, 64, 64]),
        'point_coords': (coords, [1, n, 2]),
        'point_labels': (labels, [1, n]),
        'mask_input': (maskInput ?? Float32List(256 * 256), const [1, 1, 256, 256]),
        'has_mask_input': (Float32List.fromList([maskInput == null ? 0 : 1]), const [1]),
        'orig_im_size': (Float32List.fromList([_rh.toDouble(), _rw.toDouble()]), const [2]),
      },
      outputs: {'masks', 'iou_predictions'},
    );
    final masks = out['masks']!;
    if (masks.length < _rw * _rh) {
      throw AiException(AiErrorKind.inference, model: spec, detail: 'unexpected mask size ${masks.length}');
    }
    final iou = out['iou_predictions'] ?? const <num>[];
    final w = _rw;
    final h = _rh;
    // The multi decoder returns four channels: 0 is the single-mask branch,
    // 1..3 the candidates. A single-channel graph still works (candidates
    // = channel 0).
    final channels = masks.length ~/ (w * h);
    final first = channels > 3 ? 1 : 0;
    final last = math.min(channels, first + 3);
    final scores = List<double>.generate(last - first, (k) {
      final idx = first + k;
      return idx < iou.length ? iou[idx].toDouble() : 1 - k * 0.1;
    });
    final built = await Isolate.run(() {
      final channel = w * h;
      return [for (var k = first; k < last; k++) logitsToMask(masks.sublist(k * channel, (k + 1) * channel), w, h)];
    });
    return SelectCandidates(built, scores);
  }

  void clear() {
    _path = null;
    _embedding = null;
  }
}

/// Softens the edges of a selection mask before it is used (feathered
/// edges): a small box blur turns the hard 0/255 border into a smooth
/// falloff over [radius] pixels while the interior stays fully selected.
RgbaImage featherMask(RgbaImage mask, int radius) => boxBlurMask(mask, radius);

// ---------------------------------------------------------------------------
// Depth (Depth Anything V2 Small)

/// Relative depth normalised to 0..1 (1 = nearest) at [width]x[height].
class DepthMap {
  const DepthMap(this.values, this.width, this.height);

  final Float32List values;
  final int width;
  final int height;
}

/// Model input size: long side ≤ [maxSide], both sides multiples of 14.
(int, int) depthInputSize(int w, int h, {int maxSide = 518}) {
  final k = maxSide / math.max(w, h);
  int r(double v) => math.max(14, (v / 14).round() * 14);
  return (r(w * k), r(h * k));
}

/// Robust min-max normalisation (2nd–98th percentile) of raw inverse depth.
Float32List normalizeDepth(List<num> raw) {
  final out = Float32List(raw.length);
  if (raw.isEmpty) return out;
  final sorted = Float32List(raw.length);
  for (var i = 0; i < raw.length; i++) {
    sorted[i] = raw[i].toDouble();
  }
  sorted.sort();
  final lo = sorted[(raw.length * 0.02).floor()];
  final hi = sorted[math.min(raw.length - 1, (raw.length * 0.98).floor())];
  final range = hi - lo;
  for (var i = 0; i < raw.length; i++) {
    out[i] = range <= 1e-6 ? 0.5 : ((raw[i] - lo) / range).clamp(0.0, 1.0);
  }
  return out;
}

/// Depth of the main subject: the 90th percentile (the nearest large region).
double focusDepth(Float32List depth) {
  if (depth.isEmpty) return 1;
  final s = Float32List.fromList(depth)..sort();
  return s[math.min(s.length - 1, (s.length * 0.9).floor())];
}

double _smoothstep(double e0, double e1, double x) {
  final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// Mask for depth-graded background blur: 0 at the subject's depth, rising
/// smoothly to 1 for the farthest parts of the scene.
RgbaImage depthBlurMask(DepthMap d, {double? focus}) {
  final f = focus ?? focusDepth(d.values);
  return _maskFrom(d, (v) => _smoothstep(0.06, 0.45, f - v));
}

/// Mask for relighting: 1 on the subject and whatever is as near, falling
/// off with distance.
RgbaImage depthNearMask(DepthMap d, {double? focus}) {
  final f = focus ?? focusDepth(d.values);
  return _maskFrom(d, (v) => _smoothstep(f - 0.4, f - 0.08, v));
}

RgbaImage _maskFrom(DepthMap d, double Function(double) map) {
  final out = RgbaImage(d.width, d.height);
  for (var i = 0; i < d.values.length; i++) {
    final v = (map(d.values[i]) * 255).round().clamp(0, 255);
    out.pixels[i * 4] = v;
    out.pixels[i * 4 + 1] = v;
    out.pixels[i * 4 + 2] = v;
    out.pixels[i * 4 + 3] = 255;
  }
  return boxBlurMask(out, 2);
}

/// Separable box blur of a grayscale RGBA mask (softens depth edges).
RgbaImage boxBlurMask(RgbaImage m, int radius) {
  if (radius <= 0) return m;
  final w = m.width;
  final h = m.height;
  final a = Float32List(w * h);
  for (var i = 0; i < w * h; i++) {
    a[i] = m.pixels[i * 4].toDouble();
  }
  final b = Float32List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var s = 0.0;
      var n = 0;
      for (var k = math.max(0, x - radius); k <= math.min(w - 1, x + radius); k++) {
        s += a[y * w + k];
        n++;
      }
      b[y * w + x] = s / n;
    }
  }
  final out = RgbaImage(w, h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var s = 0.0;
      var n = 0;
      for (var k = math.max(0, y - radius); k <= math.min(h - 1, y + radius); k++) {
        s += b[k * w + x];
        n++;
      }
      final v = (s / n).round().clamp(0, 255);
      final o = (y * w + x) * 4;
      out.pixels[o] = v;
      out.pixels[o + 1] = v;
      out.pixels[o + 2] = v;
      out.pixels[o + 3] = 255;
    }
  }
  return out;
}

/// Monocular depth estimation, cached per image.
class DepthPipeline {
  DepthPipeline(this.engine);
  final InferenceEngine engine;

  String? _path;
  DepthMap? _cached;

  Future<DepthMap> estimate(String imagePath) async {
    final hit = _cached;
    if (hit != null && _path == imagePath) return hit;
    final src = await loadRgba(imagePath, maxSide: 1536);
    final (w, h) = depthInputSize(src.width, src.height);
    final input = await Isolate.run(
      () => rgbaToNchw(src.resize(w, h), mean: const [0.485, 0.456, 0.406], std: const [0.229, 0.224, 0.225]),
    );
    const spec = ModelRegistry.depthAnythingSmall;
    final out = await engine.run(spec, {
      spec.inputNames.first: (input, [1, 3, h, w]),
    });
    if (out.length != w * h) {
      throw AiException(AiErrorKind.inference, model: spec, detail: 'unexpected depth size ${out.length}');
    }
    final values = await Isolate.run(() => normalizeDepth(out));
    _path = imagePath;
    return _cached = DepthMap(values, w, h);
  }
}
