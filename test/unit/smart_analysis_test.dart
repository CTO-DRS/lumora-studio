import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/ai/data/onnx_engine.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:lumora/features/ai/pipelines/smart_pipelines.dart';
import 'package:lumora/features/ai/pipelines/tensor_utils.dart';
import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/photo_editor/domain/presets.dart';
import 'package:lumora/features/smart_edit/domain/photo_analysis.dart';

/// Builds a [w]x[h] RGBA buffer from a per-pixel colour function.
Uint8List paint(int w, int h, (int, int, int) Function(int x, int y) f) {
  final out = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final (r, g, b) = f(x, y);
      final o = (y * w + x) * 4;
      out[o] = r;
      out[o + 1] = g;
      out[o + 2] = b;
      out[o + 3] = 255;
    }
  }
  return out;
}

List<SuggestionKind> kinds(Uint8List px, [int w = 160, int h = 120]) =>
    suggestFixes(PhotoAnalysis.fromRgba(px, w, h)).map((s) => s.kind).toList();

/// Mild noise so histograms are not degenerate.
int n(int x, int y) => ((x * 7 + y * 13) % 17) - 8;

void main() {
  group('PhotoAnalysis + suggestFixes', () {
    test('dark photo → brighten first', () {
      final px = paint(160, 120, (x, y) => (30 + n(x, y), 28 + n(x, y), 26 + n(x, y)));
      final a = PhotoAnalysis.fromRgba(px, 160, 120);
      expect(a.isDark, isTrue);
      expect(kinds(px).first, SuggestionKind.brighten);
    });

    test('blown-out photo → recover highlights', () {
      final px = paint(160, 120, (x, y) => x < 100 ? (252, 252, 252) : (200, 190, 185));
      expect(kinds(px), contains(SuggestionKind.recoverHighlights));
    });

    test('orange cast → fix colour (and the fix cools it down)', () {
      final px = paint(160, 120, (x, y) => (190 + n(x, y), 130 + n(x, y), 70 + n(x, y)));
      final s = suggestFixes(PhotoAnalysis.fromRgba(px, 160, 120));
      final fix = s.firstWhere((e) => e.kind == SuggestionKind.fixColor);
      expect(fix.preset.adjustments.temperature, lessThan(0));
    });

    test('document → clean paper look, no colour/haze fixes', () {
      final px = paint(160, 120, (x, y) => (y % 12 < 2 && x > 15 && x < 145) ? (30, 30, 30) : (235, 235, 230));
      final a = PhotoAnalysis.fromRgba(px, 160, 120);
      expect(a.looksLikeDocument, isTrue);
      final k = kinds(px);
      expect(k, contains(SuggestionKind.document));
      expect(k, isNot(contains(SuggestionKind.clearHaze)));
      expect(k, isNot(contains(SuggestionKind.fixColor)));
    });

    test('blue sky over green land → deeper sky + vivid nature', () {
      final px = paint(
        160,
        120,
        (x, y) =>
            y < 50 ? (90 + n(x, y), 150 + n(x, y), 225 + n(x, y) ~/ 2) : (60 + n(x, y), 130 + n(x, y), 50 + n(x, y)),
      );
      final a = PhotoAnalysis.fromRgba(px, 160, 120);
      expect(a.skyRatio, greaterThan(0.8));
      expect(a.looksLikeLandscape, isTrue);
      expect(kinds(px), containsAll([SuggestionKind.sky, SuggestionKind.landscape]));
    });

    test('skin-toned centre → portrait glow', () {
      final px = paint(160, 120, (x, y) {
        final inFace = (x - 80).abs() < 30 && (y - 55).abs() < 35;
        return inFace ? (224 + n(x, y) ~/ 2, 172 + n(x, y), 140 + n(x, y)) : (40 + n(x, y), 60 + n(x, y), 80 + n(x, y));
      });
      final a = PhotoAnalysis.fromRgba(px, 160, 120);
      expect(a.looksLikePortrait, isTrue);
      expect(kinds(px), contains(SuggestionKind.portrait));
    });

    test('always 3–5 unique suggestions with valid recipes', () {
      final images = [
        paint(160, 120, (x, y) => (128 + n(x, y), 128 + n(x, y), 128 + n(x, y))),
        paint(160, 120, (x, y) => ((x * 255) ~/ 160, (y * 255) ~/ 120, 120)),
        paint(160, 120, (x, y) => (10, 10, 10)),
        paint(160, 120, (x, y) => (255, 255, 255)),
      ];
      for (final px in images) {
        final s = suggestFixes(PhotoAnalysis.fromRgba(px, 160, 120));
        expect(s.length, inInclusiveRange(3, 5));
        expect(s.map((e) => e.kind).toSet().length, s.length);
        for (final e in s) {
          for (final p in AdjustmentParam.values) {
            expect(p.read(e.preset.adjustments), inInclusiveRange(p.min, p.max), reason: '${e.kind}.${p.name}');
          }
          if (e.libraryPresetId != null) expect(presetById(e.libraryPresetId), isNotNull);
        }
        // Sorted best first.
        for (var i = 1; i < s.length; i++) {
          expect(s[i - 1].score, greaterThanOrEqualTo(s[i].score));
        }
      }
    });

    test('transparent pixels are ignored', () {
      final px = Uint8List(64 * 64 * 4); // fully transparent
      final a = PhotoAnalysis.fromRgba(px, 64, 64);
      expect(a.skinRatio, 0);
      expect(suggestFixes(a), isNotEmpty);
    });
  });

  group('tap to select helpers', () {
    test('samInputSize makes the long side 1024', () {
      expect(samInputSize(4000, 3000), (1024, 768));
      expect(samInputSize(300, 600), (512, 1024));
    });

    test('samPrompt scales points and appends the padding point', () {
      final (coords, labels, n) = samPrompt(
        const [SelectPoint(0.5, 0.25), SelectPoint(1.2, 0, positive: false)],
        null,
        1024,
        768,
      );
      expect(n, 3);
      expect(coords.sublist(0, 4), [512, 192, 1024, 0]);
      expect(labels, [1, 0, -1]);
    });

    test('samPrompt box: corners carry labels 2/3 and no padding point', () {
      final (coords, labels, n) = samPrompt(
        const [SelectPoint(0.5, 0.5)],
        const SelectBox(0.1, 0.2, 0.9, 0.8),
        1024,
        768,
      );
      expect(n, 3);
      expect(coords.sublist(0, 2), [512, 384]);
      // Box corners: TL then BR, as 32-bit floats in the 1024x768 frame.
      const corners = {2: 102.4, 3: 153.6, 4: 921.6, 5: 614.4};
      corners.forEach((i, v) => expect(coords[i], closeTo(v, 0.01)));
      expect(labels, [1, 2, 3]);
    });

    test('logitsToMask thresholds at zero and coverage counts it', () {
      final m = logitsToMask([-1, 0.5, 2, -3], 2, 2);
      expect([for (var i = 0; i < 4; i++) m.pixels[i * 4]], [0, 255, 255, 0]);
      expect(maskCoverage(m), 0.5);
    });

    test('featherMask keeps the interior and softens the border', () {
      // Left half selected, right half empty.
      final m = logitsToMask([for (var i = 0; i < 64; i++) i % 8 < 4 ? 1.0 : -1.0], 8, 8);
      final f = featherMask(m, 1);
      expect(f.pixels[(4 * 8 + 1) * 4], 255, reason: 'interior stays selected');
      expect(f.pixels[(4 * 8 + 7) * 4], 0, reason: 'outside stays empty');
      expect(f.pixels[(4 * 8 + 4) * 4], inInclusiveRange(1, 254), reason: 'border is soft');
      expect(featherMask(m, 0), same(m), reason: 'radius 0 is a no-op');
    });

    test('rgbaToHwcFloat keeps 0..255 values in HWC order', () {
      final img = RgbaImage(1, 2, Uint8List.fromList([1, 2, 3, 255, 4, 5, 6, 255]));
      expect(rgbaToHwcFloat(img), [1, 2, 3, 4, 5, 6]);
    });

    test('pipeline: encoder once, decoder per tap, with the right tensors', () async {
      final engine = _SamFakeEngine();
      final p = ObjectSelectPipeline(engine);
      expect(() => p.decode(points: const [SelectPoint(0.5, 0.5)]), throwsStateError);
      await p.prepareRgba('img', RgbaImage(64, 48));
      expect(p.isPreparedFor('img'), isTrue);
      expect(engine.encoderShapes.single, [768, 1024, 3]);
      final mask = await p.maskFor(const [SelectPoint(0.5, 0.5)]);
      expect(mask.width, 1024);
      expect(mask.height, 768);
      final call = engine.calls.single;
      expect(call.$1, ModelRegistry.mobileSamDecoderMulti.id);
      expect(call.$2['point_coords'], [1, 2, 2]);
      expect(call.$2['point_labels'], [1, 2]);
      expect(engine.labelValues.single, [1, -1], reason: 'tap + SAM padding point');
      expect(call.$2['orig_im_size'], [2]);
      expect(call.$2['image_embeddings'], [1, 256, 64, 64]);
      expect(call.$2['has_mask_input'], [1]);
      expect(maskCoverage(mask), closeTo(0.5, 0.01));
    });

    test('decode returns three candidates ranked by IoU, best first', () async {
      final engine = _SamFakeEngine();
      final p = ObjectSelectPipeline(engine);
      await p.prepareRgba('img', RgbaImage(64, 48));
      final c = await p.decode(points: const [SelectPoint(0.5, 0.5)]);
      expect(c.count, 3);
      expect(c.scores, orderedEquals([0.95, 0.9, 0.85]), reason: 'sorted best first');
      expect(maskCoverage(c.best), closeTo(0.5, 0.01));
    });

    test('box prompt: two corner points with labels 2/3', () async {
      final engine = _SamFakeEngine();
      final p = ObjectSelectPipeline(engine);
      await p.prepareRgba('img', RgbaImage(64, 48));
      await p.decode(box: const SelectBox(0.1, 0.2, 0.9, 0.8));
      final call = engine.calls.single;
      expect(call.$2['point_coords'], [1, 2, 2]);
      expect(engine.labelValues.single, [2, 3], reason: 'SAM box corners, no padding point');
    });

    test('brush refine: 256 px mask input and has_mask_input = 1', () async {
      final engine = _SamFakeEngine();
      final p = ObjectSelectPipeline(engine);
      await p.prepareRgba('img', RgbaImage(64, 48));
      final input = Float32List(256 * 256)..fillRange(0, 256 * 256, 0.5);
      await p.decode(points: const [SelectPoint(0.5, 0.5)], maskInput: input);
      final call = engine.calls.single;
      expect(call.$2['has_mask_input'], [1]);
      expect(call.$2['mask_input'], [1, 1, 256, 256]);
    });

    test('single-channel graph still yields one candidate', () async {
      final engine = _SamFakeEngine(channels: 1);
      final p = ObjectSelectPipeline(engine);
      await p.prepareRgba('img', RgbaImage(64, 48));
      final c = await p.decode(box: const SelectBox(0, 0, 1, 1));
      expect(c.count, 1);
      expect(c.scores, [1]);
    });
  });

  group('depth helpers', () {
    test('depthInputSize keeps multiples of 14 under the cap', () {
      final (w, h) = depthInputSize(4032, 3024);
      expect(w % 14, 0);
      expect(h % 14, 0);
      expect(w, lessThanOrEqualTo(518 + 7));
      expect(w / h, closeTo(4 / 3, 0.05));
    });

    test('normalizeDepth is robust to outliers', () {
      final raw = [for (var i = 0; i < 100; i++) i.toDouble()]..[0] = -1000;
      final d = normalizeDepth(raw);
      expect(d.reduce((a, b) => a < b ? a : b), 0);
      expect(d.reduce((a, b) => a > b ? a : b), 1);
      expect(d[50], closeTo(0.5, 0.05));
    });

    test('blur mask: subject sharp, far background blurred; near mask is the opposite', () {
      // Left half near (1.0), right half far (0.1).
      const w = 40;
      const h = 20;
      final values = Float32List(w * h);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          values[y * w + x] = x < w / 2 ? 1 : 0.1;
        }
      }
      final d = DepthMap(values, w, h);
      final blur = depthBlurMask(d);
      final near = depthNearMask(d);
      int at(RgbaImage m, int x) => m.pixels[(10 * w + x) * 4];
      expect(at(blur, 2), lessThan(10));
      expect(at(blur, w - 3), greaterThan(245));
      expect(at(near, 2), greaterThan(245));
      expect(at(near, w - 3), lessThan(10));
    });

    test('model specs for the new tools are pinned and verified', () {
      for (final m in [
        ModelRegistry.mobileSamEncoder,
        ModelRegistry.mobileSamDecoderMulti,
        ModelRegistry.depthAnythingSmall,
      ]) {
        expect(m.sha256, hasLength(64));
        expect(m.url, startsWith('https://huggingface.co/'));
        expect(m.url, isNot(contains('/resolve/main/')), reason: 'revision-pinned');
        expect(ModelRegistry.all, contains(m));
      }
      expect(aiToolModels(AiTool.selectObject), hasLength(2));
      expect(aiToolModels(AiTool.depthBlur), [ModelRegistry.depthAnythingSmall]);
      expect(aiToolModels(AiTool.erasePerson), [ModelRegistry.modnet, ModelRegistry.migan]);
    });
  });
}

/// Fake SAM engine: the encoder returns zeros; the multi-mask decoder
/// returns left-half-selected masks for channels 0..2 and a full mask for
/// channel 3, with descending IoU predictions (configurable channel count).
class _SamFakeEngine implements InferenceEngine {
  _SamFakeEngine({this.channels = 4});

  final int channels;
  final calls = <(String, Map<String, List<int>>)>[];
  final encoderShapes = <List<int>>[];
  final labelValues = <List<double>>[];

  @override
  Future<List<num>> run(ModelSpec model, Map<String, (TypedData, List<int>)> inputs) async {
    final out = await runNamed(model, inputs);
    return out[model.outputName] ?? out.values.first;
  }

  @override
  Future<Map<String, List<num>>> runNamed(
    ModelSpec model,
    Map<String, (TypedData, List<int>)> inputs, {
    Set<String> outputs = const {},
  }) async {
    if (model.id == ModelRegistry.mobileSamEncoder.id) {
      encoderShapes.add(inputs.values.single.$2);
      return {'image_embeddings': Float32List(256 * 64 * 64)};
    }
    calls.add((model.id, {for (final e in inputs.entries) e.key: e.value.$2}));
    final size = inputs['orig_im_size']!.$1 as Float32List;
    final labels = inputs['point_labels']!.$1 as Float32List;
    labelValues.add(labels.toList());
    final h = size[0].toInt();
    final w = size[1].toInt();
    final per = w * h;
    final masks = <num>[
      for (var c = 0; c < channels; c++)
        for (var i = 0; i < per; i++) c == 3 ? 1.0 : (i % w < w / 2 ? 1.0 : -1.0),
    ];
    final iou = [for (var c = 0; c < channels; c++) (1.0 - c * 0.05)];
    return {'masks': masks, if (outputs.contains('iou_predictions')) 'iou_predictions': iou};
  }

  @override
  Future<void> release() async {}
}
