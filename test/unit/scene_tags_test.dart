import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/ai/data/onnx_engine.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:lumora/features/ai/domain/scene_tags.dart';
import 'package:lumora/features/ai/pipelines/scene_pipeline.dart';
import 'package:lumora/features/ai/pipelines/tensor_utils.dart';
import 'package:lumora/features/smart_edit/domain/photo_analysis.dart';

/// Mild noise so histograms are not degenerate.
int n(int x, int y) => ((x * 7 + y * 13) % 17) - 8;

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

/// An engine that answers every run with [logits] and records the shapes it
/// received, proving the pipeline's tensor contract without native code.
class RecordingEngine implements InferenceEngine {
  RecordingEngine(this.logits);

  final List<double> logits;
  final shapes = <List<int>>[];

  @override
  Future<List<num>> run(ModelSpec model, Map<String, (TypedData, List<int>)> inputs) async {
    shapes.add(inputs.values.first.$2);
    return Float32List.fromList(logits);
  }

  @override
  Future<Map<String, List<num>>> runAll(ModelSpec model, Map<String, (TypedData, List<int>)> inputs) =>
      throw UnimplementedError();

  @override
  Future<void> release() async {}
}

/// Logits with one class boosted above the rest.
List<double> spike(int classIndex, {double base = 0, double boost = 10}) {
  final out = List<double>.filled(1000, base);
  out[classIndex] = base + boost;
  return out;
}

/// Fakes a model run that puts exactly [mass] of softmax probability on the
/// classes of each tag: probabilities sum to 1 (the remainder is spread
/// evenly over every other class) and logits are ln(p) — softmax inverts
/// them back to the same distribution.
List<double> logitsFor(Map<SceneTag, double> masses) {
  final p = List<double>.filled(1000, 0);
  var claimed = 0.0;
  var claimedIndices = 0;
  for (final tag in SceneTag.values) {
    final mass = masses[tag] ?? 0;
    if (mass <= 0) continue;
    final idx = kSceneTagIndices[tag]!;
    for (final i in idx) {
      p[i] = mass / idx.length;
    }
    claimed += mass;
    claimedIndices += idx.length;
  }
  final rest = (1.0 - claimed).clamp(0.0, 1.0) / (1000 - claimedIndices);
  for (var i = 0; i < 1000; i++) {
    if (p[i] == 0) p[i] = rest;
  }
  // Softmax is invariant to a constant shift, so logits = ln(p) reproduce
  // exactly this probability distribution after softmax.
  return [for (final v in p) math.log(v)];
}

SceneResult tags(Map<SceneTag, double> masses) => SceneResult.fromLogits(logitsFor(masses));

void main() {
  group('SceneResult.fromLogits', () {
    test('uniform logits → all probabilities below the active bar', () {
      final r = SceneResult.fromLogits(List<double>.filled(1000, 0));
      final total = r.scores.values.fold<double>(0, (a, b) => a + b);
      expect(total, greaterThan(0));
      expect(total, lessThan(1.0001));
      for (final v in r.scores.values) {
        expect(v, inInclusiveRange(0, 1));
      }
      // Even pets (93 of 1000 classes) is ~0.093 — below kSceneTagMinScore.
      expect(r.activeTags, isEmpty);
      expect(r.score(SceneTag.pets), closeTo(0.093, 0.001));
    });

    test('a dominant cat class lights up the pets tag', () {
      // 285 = Egyptian cat (n02124075), the last class of the cat block.
      final r = SceneResult.fromLogits(spike(285));
      expect(r.topClassIndex, 285);
      expect(r.score(SceneTag.pets), greaterThan(0.5));
      expect(r.activeTags.first, SceneTag.pets);
      expect(r.score(SceneTag.food), lessThan(0.01));
    });

    test('a dominant pizza class lights up the food tag', () {
      // 963 = pizza (n07873807).
      final r = SceneResult.fromLogits(spike(963));
      expect(r.topClassIndex, 963);
      expect(r.activeTags.first, SceneTag.food);
    });

    test('every curated tag index stays within 0..999 and every tag is non-empty', () {
      for (final tag in SceneTag.values) {
        expect(kSceneTagIndices[tag], isNotEmpty, reason: tag.name);
        for (final i in kSceneTagIndices[tag]!) {
          expect(i, inInclusiveRange(0, 999), reason: '${tag.name} index $i');
        }
      }
    });

    test('logitsFor distributes the requested mass exactly', () {
      final r = SceneResult.fromLogits(logitsFor({SceneTag.pets: 0.6, SceneTag.food: 0.3}));
      expect(r.score(SceneTag.pets), closeTo(0.6, 0.005));
      expect(r.score(SceneTag.food), closeTo(0.3, 0.005));
      expect(r.activeTags, [SceneTag.pets, SceneTag.food]);
    });

    test('numerically stable for huge logits (no NaN / inf)', () {
      final r = SceneResult.fromLogits([for (var i = 0; i < 1000; i++) 1000.0 + i / 1000]);
      for (final v in r.scores.values) {
        expect(v.isNaN, isFalse);
        expect(v.isInfinite, isFalse);
      }
      expect(r.topClassIndex, 999);
    });
  });

  group('SceneClassifierPipeline tensor contract', () {
    test('feeds a [1,3,224,224] NCHW tensor with ImageNet normalisation', () async {
      final engine = RecordingEngine(spike(285));
      // A 2×2 proxy that resizes to 224×224 of solid red (255, 0, 0).
      final proxy = RgbaImage(2, 2, paint(2, 2, (x, y) => (255, 0, 0)));
      final result = await SceneClassifierPipeline(engine).run(proxy);

      expect(engine.shapes.single, [1, 3, 224, 224]);

      // The exact value the model receives for pure red: (1 − 0.485)/0.229
      // on the R plane, (0 − 0.456)/0.224 on G, (0 − 0.406)/0.225 on B.
      final t = rgbaToNchw(proxy.resize(224, 224), mean: const [0.485, 0.456, 0.406], std: const [0.229, 0.224, 0.225]);
      const plane = 224 * 224;
      expect(t[0], closeTo((1 - 0.485) / 0.229, 1e-6));
      expect(t[plane], closeTo((0 - 0.456) / 0.224, 1e-6));
      expect(t[2 * plane], closeTo((0 - 0.406) / 0.225, 1e-6));

      // And the logits flow back into tags.
      expect(result.activeTags.first, SceneTag.pets);
    });

    test('wrong output length is an inference error', () async {
      final engine = RecordingEngine(List<double>.filled(100, 0));
      final proxy = RgbaImage(2, 2, paint(2, 2, (x, y) => (10, 10, 10)));
      expect(() => SceneClassifierPipeline(engine).run(proxy), throwsA(isA<AiException>()));
    });
  });

  group('scene-aware suggestFixes', () {
    test('pets photo without skin statistics gains the soft portrait suggestion', () {
      // Neutral bluish-gray noise: no skin, no sky, no foliage, dull.
      final px = paint(160, 120, (x, y) => (100 + n(x, y), 105 + n(x, y), 110 + n(x, y)));
      final a = PhotoAnalysis.fromRgba(px, 160, 120);
      expect(a.looksLikePortrait, isFalse);
      expect(a.isDark, isFalse);

      final baseline = suggestFixes(a);
      expect(baseline.where((s) => s.kind == SuggestionKind.portrait), isEmpty);

      final withScene = suggestFixes(a, scene: tags({SceneTag.pets: 0.6}));
      expect(withScene.map((s) => s.kind), contains(SuggestionKind.portrait));
      // And the pets look stays gentle: less clarity than the fix applies.
      final portrait = withScene.firstWhere((s) => s.kind == SuggestionKind.portrait);
      expect(portrait.preset.adjustments.clarity, lessThan(0));
    });

    test('food photo that is not dull gains the vivid suggestion', () {
      // Saturated red/blue checker: not dull, not landscape, not skin.
      final px = paint(160, 120, (x, y) => (x + y).isEven ? (200, 40, 45) : (45, 60, 200));
      final a = PhotoAnalysis.fromRgba(px, 160, 120);
      expect(a.isDull, isFalse);
      expect(suggestFixes(a).map((s) => s.kind), isNot(contains(SuggestionKind.vivid)));

      final withScene = suggestFixes(a, scene: tags({SceneTag.food: 0.5}));
      expect(withScene.map((s) => s.kind), contains(SuggestionKind.vivid));
    });

    test('nature scene surfaces the landscape look for non-landscape photos', () {
      // Warm brown tones: no sky, little foliage → statistics see no
      // landscape, but the classifier does.
      final px = paint(160, 120, (x, y) => (140 + n(x, y), 110 + n(x, y), 80 + n(x, y)));
      final a = PhotoAnalysis.fromRgba(px, 160, 120);
      expect(a.looksLikeLandscape, isFalse);
      final baseline = suggestFixes(a);
      expect(baseline.map((s) => s.kind), isNot(contains(SuggestionKind.landscape)));

      final withScene = suggestFixes(a, scene: tags({SceneTag.nature: 0.7}));
      expect(withScene.map((s) => s.kind), contains(SuggestionKind.landscape));
      final land = withScene.firstWhere((s) => s.kind == SuggestionKind.landscape);
      expect(land.libraryPresetId, 'vivid_landscape');
    });

    test('city scene lifts the cinematic suggestion above its fallback floor', () {
      final px = paint(160, 120, (x, y) => (100 + n(x, y), 105 + n(x, y), 110 + n(x, y)));
      final baseline = suggestFixes(PhotoAnalysis.fromRgba(px, 160, 120));
      final baseCine = baseline.firstWhere((s) => s.kind == SuggestionKind.cinematic);
      expect(baseCine.score, closeTo(0.3, 1e-9));

      final withScene = suggestFixes(PhotoAnalysis.fromRgba(px, 160, 120), scene: tags({SceneTag.city: 0.5}));
      final cine = withScene.firstWhere((s) => s.kind == SuggestionKind.cinematic);
      expect(cine.score, greaterThan(baseCine.score));
      expect(cine.libraryPresetId, 'blockbuster');
    });

    test('statistics still fire with the scene present (sky boost only)', () {
      final px = paint(
        160,
        120,
        (x, y) =>
            y < 50 ? (90 + n(x, y), 150 + n(x, y), 225 + n(x, y) ~/ 2) : (60 + n(x, y), 130 + n(x, y), 50 + n(x, y)),
      );
      final a = PhotoAnalysis.fromRgba(px, 160, 120);
      final base = suggestFixes(a);
      final withScene = suggestFixes(a, scene: tags({SceneTag.nature: 0.6}));
      final baseSky = base.firstWhere((s) => s.kind == SuggestionKind.sky);
      final sceneSky = withScene.firstWhere((s) => s.kind == SuggestionKind.sky);
      expect(sceneSky.score, greaterThan(baseSky.score));
    });

    test('flat scene probabilities add nothing (statistics path unchanged)', () {
      final px = paint(160, 120, (x, y) => (100 + n(x, y), 105 + n(x, y), 110 + n(x, y)));
      final a = PhotoAnalysis.fromRgba(px, 160, 120);
      final baseline = suggestFixes(a).map((s) => s.kind).toList();
      final withScene = suggestFixes(a, scene: tags(const {})).map((s) => s.kind).toList();
      expect(withScene, baseline);
    });
  });
}
