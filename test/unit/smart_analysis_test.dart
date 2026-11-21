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
        1024,
        768,
      );
      expect(n, 3);
      expect(coords.sublist(0, 4), [512, 192, 1024, 0]);
      expect(labels, [1, 0, -1]);
    });

    test('logitsToMask thresholds at zero and coverage counts it', () {
      final m = logitsToMask([-1, 0.5, 2, -3], 2, 2);
      expect([for (var i = 0; i < 4; i++) m.pixels[i * 4]], [0, 255, 255, 0]);
      expect(maskCoverage(m), 0.5);
    });

    test('rgbaToHwcFloat keeps 0..255 values in HWC order', () {
      final img = RgbaImage(1, 2, Uint8List.fromList([1, 2, 3, 255, 4, 5, 6, 255]));
      expect(rgbaToHwcFloat(img), [1, 2, 3, 4, 5, 6]);
    });

    test('pipeline: encoder once, decoder per tap, with the right tensors', () async {
      final engine = _SamFakeEngine();
      final p = ObjectSelectPipeline(engine);
      expect(() => p.maskFor(const [SelectPoint(0.5, 0.5)]), throwsStateError);
      await p.prepareRgba('img', RgbaImage(64, 48));
      expect(p.isPreparedFor('img'), isTrue);
      expect(engine.encoderShapes.single, [768, 1024, 3]);
      final mask = await p.maskFor(const [SelectPoint(0.5, 0.5)]);
      expect(mask.width, 1024);
      expect(mask.height, 768);
      final call = engine.calls.single;
      expect(call.$1, ModelRegistry.mobileSamDecoder.id);
      expect(call.$2['point_coords'], [1, 2, 2]);
      expect(call.$2['point_labels'], [1, 2]);
      expect(call.$2['orig_im_size'], [2]);
      expect(call.$2['image_embeddings'], [1, 256, 64, 64]);
      expect(maskCoverage(mask), closeTo(0.5, 0.01));
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
        ModelRegistry.mobileSamDecoder,
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

/// Returns a left-half-selected mask for the decoder.
class _SamFakeEngine implements InferenceEngine {
  final calls = <(String, Map<String, List<int>>)>[];
  final encoderShapes = <List<int>>[];

  @override
  Future<List<num>> run(ModelSpec model, Map<String, (TypedData, List<int>)> inputs) async {
    if (model.id == ModelRegistry.mobileSamEncoder.id) {
      encoderShapes.add(inputs.values.single.$2);
      return Float32List(256 * 64 * 64);
    }
    calls.add((model.id, {for (final e in inputs.entries) e.key: e.value.$2}));
    final size = inputs['orig_im_size']!.$1 as Float32List;
    final h = size[0].toInt();
    final w = size[1].toInt();
    return [
      for (var y = 0; y < h; y++)
        for (var x = 0; x < w; x++) x < w / 2 ? 1.0 : -1.0,
    ];
  }

  @override
  Future<void> release() async {}
}
