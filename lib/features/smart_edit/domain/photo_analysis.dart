import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/photo_editor/domain/auto_enhance.dart';
import 'package:lumora/features/photo_editor/domain/presets.dart';

/// What a quick, model-free look at a photo tells us. Every value is a
/// fraction (0..1) or a signed cast, computed in one pass over a small
/// proxy (≤ 65k samples) – it runs in a few milliseconds on any phone.
class PhotoAnalysis {
  const PhotoAnalysis({
    required this.stats,
    required this.skinRatio,
    required this.centerSkinRatio,
    required this.skyRatio,
    required this.foliageRatio,
    required this.paperRatio,
    required this.inkRatio,
    required this.warmCast,
    required this.greenCast,
  });

  factory PhotoAnalysis.fromRgba(Uint8List rgba, int width, int height) {
    final stats = ImageStats.fromRgba(rgba, width, height);
    final total = width * height;
    final step = math.max(1, (total / 65536).floor());
    var n = 0;
    var skin = 0;
    var centerN = 0;
    var centerSkin = 0;
    var topN = 0;
    var sky = 0;
    var foliage = 0;
    var paper = 0;
    var ink = 0;
    for (var i = 0; i < total; i += step) {
      final o = i * 4;
      if (rgba[o + 3] < 16) continue;
      final r = rgba[o].toDouble();
      final g = rgba[o + 1].toDouble();
      final b = rgba[o + 2].toDouble();
      final x = i % width;
      final y = i ~/ width;
      n++;
      final mx = math.max(r, math.max(g, b));
      final mn = math.min(r, math.min(g, b));
      final sat = mx == 0 ? 0.0 : (mx - mn) / mx;
      final luma = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255;
      final hue = _hue(r, g, b, mx, mn);

      // Skin: the classic YCbCr box, plus a minimum brightness and a hue
      // limited to reds/oranges (excludes most wood and sand).
      final cb = 128 - 0.168736 * r - 0.331264 * g + 0.5 * b;
      final cr = 128 + 0.5 * r - 0.418688 * g - 0.081312 * b;
      final isSkin =
          cb >= 77 && cb <= 127 && cr >= 137 && cr <= 173 && luma > 0.2 && (hue < 50 || hue > 340) && sat > 0.12;
      if (isSkin) skin++;
      final cx = (x / width - 0.5).abs();
      final cy = (y / height - 0.45).abs();
      if (cx < 0.25 && cy < 0.3) {
        centerN++;
        if (isSkin) centerSkin++;
      }
      // Sky: blue (or bright overcast) pixels in the top third.
      if (y < height / 3) {
        topN++;
        final blueSky = hue >= 185 && hue <= 250 && sat > 0.12 && luma > 0.3;
        final overcast = sat < 0.1 && luma > 0.75;
        if (blueSky || overcast) sky++;
      }
      if (hue >= 65 && hue <= 165 && sat > 0.2 && luma > 0.12 && luma < 0.85) foliage++;
      if (sat < 0.14 && luma > 0.62) paper++;
      if (luma < 0.32 && sat < 0.35) ink++;
    }
    double f(int a, int d) => d == 0 ? 0 : a / d;
    final avg = (stats.meanR + stats.meanG + stats.meanB) / 3;
    return PhotoAnalysis(
      stats: stats,
      skinRatio: f(skin, n),
      centerSkinRatio: f(centerSkin, centerN),
      skyRatio: f(sky, topN),
      foliageRatio: f(foliage, n),
      paperRatio: f(paper, n),
      inkRatio: f(ink, n),
      warmCast: avg <= 0 ? 0 : (stats.meanR - stats.meanB) / avg,
      greenCast: avg <= 0 ? 0 : (stats.meanG - (stats.meanR + stats.meanB) / 2) / avg,
    );
  }

  final ImageStats stats;

  /// Skin-toned pixels overall and in the central region where faces
  /// usually are (a heuristic for "there is a person", not face detection).
  final double skinRatio;
  final double centerSkinRatio;

  /// Sky-like pixels in the top third.
  final double skyRatio;
  final double foliageRatio;

  /// Bright, colourless pixels (paper) and dark, colourless ones (ink).
  final double paperRatio;
  final double inkRatio;

  /// (R − B) / mean: positive = warm/orange cast, negative = blue cast.
  final double warmCast;

  /// G − (R + B)/2 over mean: positive = green cast, negative = magenta.
  final double greenCast;

  bool get looksLikePortrait => centerSkinRatio > 0.12 || skinRatio > 0.1;
  bool get looksLikeDocument => paperRatio > 0.45 && inkRatio > 0.01 && inkRatio < 0.35 && stats.meanSaturation < 0.16;
  bool get looksLikeLandscape => !looksLikeDocument && (skyRatio > 0.3 || foliageRatio > 0.25);
  bool get isDark => stats.meanLuma < 0.3;
  bool get isBright => stats.meanLuma > 0.68 || stats.highlightClip > 0.03;
  bool get isFlat => stats.highPercentile - stats.lowPercentile < 0.6;
  bool get isDull => stats.meanSaturation < 0.18;
  bool get hasColorCast => warmCast.abs() > 0.12 || greenCast.abs() > 0.06;

  static double _hue(double r, double g, double b, double mx, double mn) {
    final d = mx - mn;
    if (d <= 0) return 0;
    double h;
    if (mx == r) {
      h = ((g - b) / d) % 6;
    } else if (mx == g) {
      h = (b - r) / d + 2;
    } else {
      h = (r - g) / d + 4;
    }
    h *= 60;
    return h < 0 ? h + 360 : h;
  }
}

/// Why a suggestion is offered (also its label in the UI).
enum SuggestionKind {
  autoFix,
  brighten,
  recoverHighlights,
  fixColor,
  portrait,
  sky,
  landscape,
  document,
  clearHaze,
  vivid,
  cinematic,
  mono,
}

/// A one-tap fix. [preset] carries the change as preset deltas so the
/// editor can render a live thumbnail with the real pipeline and apply it
/// on top of the user's edit in one undo step. Library looks keep their
/// library id in [libraryPresetId].
class Suggestion {
  const Suggestion({required this.kind, required this.preset, required this.score, this.libraryPresetId});

  final SuggestionKind kind;
  final Preset preset;
  final double score;
  final String? libraryPresetId;

  @override
  String toString() => 'Suggestion(${kind.name}, ${score.toStringAsFixed(2)})';
}

Preset _delta(SuggestionKind kind, Adjustments a) => Preset(
  id: 'suggest:${kind.name}',
  nameEn: kind.name,
  nameAr: kind.name,
  category: PresetCategory.essentials,
  adjustments: a,
);

Suggestion? _library(SuggestionKind kind, String id, double score) {
  final p = presetById(id);
  return p == null ? null : Suggestion(kind: kind, preset: p, score: score, libraryPresetId: id);
}

/// Ranks 3–5 suggestions for [a] (best first). Deterministic; every
/// suggestion is a plain adjustment recipe, so nothing leaves the device.
List<Suggestion> suggestFixes(PhotoAnalysis a, {int max = 5}) {
  final s = a.stats;
  final out = <Suggestion>[];

  // Auto fix: always available, ranked by how much it would change, but
  // below a fix aimed at a specific problem.
  final auto = autoEnhance(s);
  final autoAmount =
      auto.exposure.abs() / 1.5 + auto.temperature.abs() + auto.tint.abs() + auto.contrast + auto.vibrance.abs();
  out.add(
    Suggestion(
      kind: SuggestionKind.autoFix,
      preset: _delta(SuggestionKind.autoFix, auto),
      score: 0.55 + math.min(autoAmount, 0.6) * 0.5,
    ),
  );

  if (a.looksLikeDocument) {
    final doc = _library(SuggestionKind.document, 'clean_paper', 1.4);
    if (doc != null) out.add(doc);
  }
  if (a.isDark) {
    final ev = ((0.42 - s.meanLuma) * 3).clamp(0.3, 1.4);
    out.add(
      Suggestion(
        kind: SuggestionKind.brighten,
        preset: _delta(
          SuggestionKind.brighten,
          Adjustments(exposure: ev, shadows: 0.35, highlights: -0.25, blacks: 0.05, vibrance: 0.1),
        ),
        score: 0.9 + (0.3 - s.meanLuma) * 2,
      ),
    );
  }
  if (a.isBright) {
    out.add(
      Suggestion(
        kind: SuggestionKind.recoverHighlights,
        preset: _delta(
          SuggestionKind.recoverHighlights,
          Adjustments(
            exposure: -((s.meanLuma - 0.5) * 1.5).clamp(0.1, 0.8),
            highlights: -0.55,
            whites: -0.2,
            contrast: 0.08,
          ),
        ),
        score: 0.85 + s.highlightClip * 5,
      ),
    );
  }
  if (a.hasColorCast && !a.looksLikeDocument) {
    out.add(
      Suggestion(
        kind: SuggestionKind.fixColor,
        preset: _delta(
          SuggestionKind.fixColor,
          Adjustments(
            temperature: (-a.warmCast * 0.9).clamp(-0.45, 0.45),
            tint: (-a.greenCast * 1.2).clamp(-0.35, 0.35),
          ),
        ),
        score: 0.8 + a.warmCast.abs() + a.greenCast.abs() * 2,
      ),
    );
  }
  if (a.looksLikePortrait) {
    out.add(
      Suggestion(
        kind: SuggestionKind.portrait,
        preset: _delta(
          SuggestionKind.portrait,
          const Adjustments(
            exposure: 0.12,
            clarity: -0.18,
            highlights: -0.12,
            shadows: 0.12,
            temperature: 0.05,
            vibrance: 0.08,
            hsl: HslAdjustments(saturation: [-0.05, -0.08, 0, 0, 0, 0, 0, 0], luminance: [0.04, 0.1, 0, 0, 0, 0, 0, 0]),
          ),
        ),
        score: 0.8 + a.centerSkinRatio,
      ),
    );
  }
  if (a.skyRatio > 0.3) {
    out.add(
      Suggestion(
        kind: SuggestionKind.sky,
        preset: _delta(
          SuggestionKind.sky,
          const Adjustments(
            dehaze: 0.15,
            highlights: -0.2,
            vibrance: 0.12,
            hsl: HslAdjustments(saturation: [0, 0, 0, 0, 0.15, 0.25, 0, 0], luminance: [0, 0, 0, 0, -0.1, -0.2, 0, 0]),
          ),
        ),
        score: 0.7 + a.skyRatio * 0.5,
      ),
    );
  }
  if (a.looksLikeLandscape) {
    final land = _library(SuggestionKind.landscape, 'vivid_landscape', 0.65 + a.foliageRatio * 0.5);
    if (land != null) out.add(land);
  }
  if (a.isFlat && !a.looksLikeDocument) {
    out.add(
      Suggestion(
        kind: SuggestionKind.clearHaze,
        preset: _delta(
          SuggestionKind.clearHaze,
          const Adjustments(dehaze: 0.25, contrast: 0.15, clarity: 0.12, blacks: -0.05),
        ),
        score: 0.7 + (0.6 - (s.highPercentile - s.lowPercentile)),
      ),
    );
  }
  if (a.isDull && !a.looksLikeDocument) {
    out.add(
      Suggestion(
        kind: SuggestionKind.vivid,
        preset: _delta(SuggestionKind.vivid, const Adjustments(vibrance: 0.35, saturation: 0.05, contrast: 0.08)),
        score: 0.6 + (0.18 - s.meanSaturation) * 2,
      ),
    );
  }
  // Creative fallbacks keep the row full (lower scores, always last).
  final cine = _library(SuggestionKind.cinematic, a.looksLikePortrait ? 'golden_hour' : 'blockbuster', 0.3);
  if (cine != null) out.add(cine);
  final mono = _library(SuggestionKind.mono, 'mono', 0.25);
  if (mono != null) out.add(mono);

  out.sort((x, y) => y.score.compareTo(x.score));
  final seen = <SuggestionKind>{};
  return [
    for (final sgg in out)
      if (seen.add(sgg.kind)) sgg,
  ].take(max).toList();
}
