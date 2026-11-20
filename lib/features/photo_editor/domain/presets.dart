import 'package:lumora/features/photo_editor/domain/adjustments.dart';

enum PresetCategory { essentials, film, cinematic, portrait, bw, creative }

/// A named look. Presets are plain [Adjustments] recipes (optionally
/// pointing at a bundled 3D LUT) and are blended with the user's own edits
/// through [Preset.apply] at a chosen intensity.
class Preset {
  const Preset({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.category,
    required this.adjustments,
  });

  final String id;
  final String nameEn;
  final String nameAr;
  final PresetCategory category;
  final Adjustments adjustments;

  String name(String languageCode) => languageCode == 'ar' ? nameAr : nameEn;

  /// Returns [base] with this preset applied at [intensity] (0..1).
  /// Scalar sliders are interpolated from the neutral value towards the
  /// preset's value and *added* to the user's own adjustments, so a preset
  /// can be layered on top of manual edits.
  Adjustments apply(Adjustments base, {double intensity = 1}) {
    var out = base;
    for (final p in AdjustmentParam.values) {
      if (p == AdjustmentParam.lutIntensity) continue;
      final target = p.read(adjustments);
      final neutral = p.neutral;
      if (target == neutral) continue;
      final delta = (target - neutral) * intensity;
      out = p.write(out, p.read(base) + delta);
    }
    final st = adjustments.splitTone;
    if (st.shadowSaturation > 0 || st.highlightSaturation > 0) {
      out = out.copyWith(
        splitTone: st.copyWith(
          shadowSaturation: st.shadowSaturation * intensity,
          highlightSaturation: st.highlightSaturation * intensity,
        ),
      );
    }
    if (adjustments.duotone.strength > 0) {
      out = out.copyWith(duotone: adjustments.duotone.copyWith(strength: adjustments.duotone.strength * intensity));
    }
    if (!adjustments.curves.isIdentity) {
      out = out.copyWith(curves: _blendCurves(adjustments.curves, intensity));
    }
    if (!adjustments.hsl.isNeutral) {
      out = out.copyWith(
        hsl: HslAdjustments(
          hue: _addBands(base.hsl.hue, adjustments.hsl.hue, intensity),
          saturation: _addBands(base.hsl.saturation, adjustments.hsl.saturation, intensity),
          luminance: _addBands(base.hsl.luminance, adjustments.hsl.luminance, intensity),
        ),
      );
    }
    if (adjustments.lutId != null) {
      out = out.copyWith(lutId: adjustments.lutId, lutIntensity: adjustments.lutIntensity * intensity);
    }
    return out;
  }

  static List<double> _addBands(List<double> a, List<double> b, double k) => [
    for (var i = 0; i < 8; i++) (a[i] + b[i] * k).clamp(-1.0, 1.0),
  ];

  static CurveSet _blendCurves(CurveSet c, double k) {
    List<CurvePoint> blend(List<CurvePoint> pts) => [for (final p in pts) CurvePoint(p.x, p.x + (p.y - p.x) * k)];
    return CurveSet(master: blend(c.master), red: blend(c.red), green: blend(c.green), blue: blend(c.blue));
  }
}

const _fadeCurve = [CurvePoint(0, 0.08), CurvePoint(0.25, 0.27), CurvePoint(0.75, 0.78), CurvePoint(1, 0.95)];
const _sCurve = [CurvePoint(0, 0), CurvePoint(0.25, 0.2), CurvePoint(0.75, 0.82), CurvePoint(1, 1)];
const _strongS = [CurvePoint(0, 0), CurvePoint(0.25, 0.16), CurvePoint(0.75, 0.86), CurvePoint(1, 1)];

/// 30 built-in looks.
const List<Preset> kBuiltInPresets = [
  // ---- Essentials
  Preset(
    id: 'auto_pop',
    nameEn: 'Pop',
    nameAr: 'حيوية',
    category: PresetCategory.essentials,
    adjustments: Adjustments(contrast: 0.15, vibrance: 0.3, clarity: 0.15, shadows: 0.15, highlights: -0.15),
  ),
  Preset(
    id: 'bright',
    nameEn: 'Bright',
    nameAr: 'مشرق',
    category: PresetCategory.essentials,
    adjustments: Adjustments(exposure: 0.35, shadows: 0.25, highlights: -0.2, vibrance: 0.1),
  ),
  Preset(
    id: 'crisp',
    nameEn: 'Crisp',
    nameAr: 'حاد',
    category: PresetCategory.essentials,
    adjustments: Adjustments(sharpen: 0.35, structure: 0.25, contrast: 0.1, dehaze: 0.1),
  ),
  Preset(
    id: 'warm',
    nameEn: 'Warm',
    nameAr: 'دافئ',
    category: PresetCategory.essentials,
    adjustments: Adjustments(temperature: 0.3, tint: 0.05, vibrance: 0.1),
  ),
  Preset(
    id: 'cool',
    nameEn: 'Cool',
    nameAr: 'بارد',
    category: PresetCategory.essentials,
    adjustments: Adjustments(temperature: -0.3, tint: -0.03, contrast: 0.05),
  ),
  // ---- Film
  Preset(
    id: 'portra',
    nameEn: 'Portra 400',
    nameAr: 'بورترا ٤٠٠',
    category: PresetCategory.film,
    adjustments: Adjustments(
      temperature: 0.12,
      contrast: -0.08,
      saturation: -0.08,
      fade: 0.12,
      grain: 0.18,
      hsl: HslAdjustments(
        hue: [0.1, 0.15, 0, -0.2, 0, -0.15, 0, 0],
        saturation: [0, -0.1, -0.15, -0.25, 0, -0.1, 0, 0],
        luminance: [0, 0.1, 0, 0, 0, 0, 0, 0],
      ),
      splitTone: SplitTone(shadowHue: 0.55, shadowSaturation: 0.12, highlightHue: 0.09, highlightSaturation: 0.15),
    ),
  ),
  Preset(
    id: 'kodachrome',
    nameEn: 'Chrome 64',
    nameAr: 'كروم ٦٤',
    category: PresetCategory.film,
    adjustments: Adjustments(
      contrast: 0.25,
      saturation: 0.15,
      temperature: 0.08,
      curves: CurveSet(master: _sCurve),
      hsl: HslAdjustments(
        hue: [0, 0, 0, 0, 0, 0.1, 0, 0],
        saturation: [0.2, 0.1, 0.1, -0.1, 0, 0.25, 0, 0],
        luminance: [-0.1, 0, 0, 0, 0, -0.2, 0, 0],
      ),
      grain: 0.12,
    ),
  ),
  Preset(
    id: 'velvia',
    nameEn: 'Velvet 50',
    nameAr: 'مخملي ٥٠',
    category: PresetCategory.film,
    adjustments: Adjustments(
      saturation: 0.35,
      vibrance: 0.2,
      contrast: 0.2,
      blacks: -0.1,
      hsl: HslAdjustments(saturation: [0.1, 0, 0, 0.3, 0.2, 0.3, 0.1, 0]),
    ),
  ),
  Preset(
    id: 'classic_chrome',
    nameEn: 'Classic Chrome',
    nameAr: 'كروم كلاسيكي',
    category: PresetCategory.film,
    adjustments: Adjustments(
      saturation: -0.25,
      contrast: 0.15,
      shadows: -0.1,
      curves: CurveSet(master: _sCurve),
      hsl: HslAdjustments(hue: [0, 0, 0, 0.2, 0, -0.1, 0, 0], saturation: [-0.1, 0, -0.2, -0.3, 0, -0.2, 0, 0]),
      splitTone: SplitTone(shadowHue: 0.5, shadowSaturation: 0.1),
    ),
  ),
  Preset(
    id: 'cinestill',
    nameEn: 'Tungsten 800',
    nameAr: 'تنجستن ٨٠٠',
    category: PresetCategory.film,
    adjustments: Adjustments(
      temperature: -0.25,
      tint: 0.08,
      contrast: 0.1,
      highlights: -0.15,
      grain: 0.25,
      grainSize: 0.6,
      splitTone: SplitTone(shadowHue: 0.52, shadowSaturation: 0.25, highlightHue: 0.98, highlightSaturation: 0.2),
    ),
  ),
  Preset(
    id: 'expired',
    nameEn: 'Expired',
    nameAr: 'فيلم منتهي',
    category: PresetCategory.film,
    adjustments: Adjustments(
      fade: 0.3,
      tint: 0.15,
      temperature: 0.15,
      saturation: -0.15,
      grain: 0.35,
      vignette: -0.25,
      curves: CurveSet(master: _fadeCurve),
      lutId: 'builtin:warm_film',
      lutIntensity: 0.5,
    ),
  ),
  Preset(
    id: 'instant',
    nameEn: 'Instant',
    nameAr: 'فوري',
    category: PresetCategory.film,
    adjustments: Adjustments(
      fade: 0.2,
      exposure: 0.15,
      contrast: -0.1,
      temperature: 0.1,
      vignette: -0.2,
      splitTone: SplitTone(shadowHue: 0.62, shadowSaturation: 0.15, highlightHue: 0.12, highlightSaturation: 0.2),
    ),
  ),
  // ---- Cinematic
  Preset(
    id: 'teal_orange',
    nameEn: 'Teal & Orange',
    nameAr: 'تركوازي وبرتقالي',
    category: PresetCategory.cinematic,
    adjustments: Adjustments(contrast: 0.15, lutId: 'builtin:teal_orange', lutIntensity: 0.85, vignette: -0.15),
  ),
  Preset(
    id: 'blockbuster',
    nameEn: 'Blockbuster',
    nameAr: 'سينمائي',
    category: PresetCategory.cinematic,
    adjustments: Adjustments(
      contrast: 0.3,
      clarity: 0.2,
      saturation: -0.1,
      temperature: -0.05,
      curves: CurveSet(master: _strongS),
      splitTone: SplitTone(shadowHue: 0.5, shadowSaturation: 0.3, highlightSaturation: 0.25),
      vignette: -0.3,
    ),
  ),
  Preset(
    id: 'bleach_bypass',
    nameEn: 'Bleach Bypass',
    nameAr: 'تجاوز التبييض',
    category: PresetCategory.cinematic,
    adjustments: Adjustments(lutId: 'builtin:bleach_bypass', lutIntensity: 0.9, clarity: 0.2),
  ),
  Preset(
    id: 'night_city',
    nameEn: 'Night City',
    nameAr: 'مدينة ليلية',
    category: PresetCategory.cinematic,
    adjustments: Adjustments(
      temperature: -0.2,
      tint: 0.2,
      contrast: 0.2,
      vibrance: 0.3,
      blacks: -0.15,
      hsl: HslAdjustments(hue: [0, -0.3, 0, 0, 0, 0.1, 0, 0], saturation: [0.1, 0.2, 0, 0, 0.2, 0.3, 0.3, 0.3]),
    ),
  ),
  Preset(
    id: 'desert_gold',
    nameEn: 'Desert Gold',
    nameAr: 'ذهب الصحراء',
    category: PresetCategory.cinematic,
    adjustments: Adjustments(
      temperature: 0.35,
      tint: 0.05,
      contrast: 0.12,
      dehaze: 0.1,
      hsl: HslAdjustments(
        hue: [0.1, 0.05, -0.1, 0, 0, 0, 0, 0],
        saturation: [0.1, 0.25, 0.2, -0.2, -0.2, -0.3, 0, 0],
        luminance: [0, 0.1, 0.1, 0, 0, -0.1, 0, 0],
      ),
      splitTone: SplitTone(highlightHue: 0.1, highlightSaturation: 0.25),
    ),
  ),
  Preset(
    id: 'moody',
    nameEn: 'Moody',
    nameAr: 'كئيب',
    category: PresetCategory.cinematic,
    adjustments: Adjustments(
      exposure: -0.2,
      contrast: 0.1,
      saturation: -0.3,
      highlights: -0.3,
      fade: 0.1,
      vignette: -0.35,
      temperature: -0.05,
    ),
  ),
  // ---- Portrait
  Preset(
    id: 'soft_skin',
    nameEn: 'Soft Skin',
    nameAr: 'بشرة ناعمة',
    category: PresetCategory.portrait,
    adjustments: Adjustments(
      clarity: -0.25,
      exposure: 0.1,
      highlights: -0.1,
      hsl: HslAdjustments(saturation: [-0.05, -0.1, 0, 0, 0, 0, 0, 0], luminance: [0.05, 0.15, 0, 0, 0, 0, 0, 0]),
    ),
  ),
  Preset(
    id: 'golden_hour',
    nameEn: 'Golden Hour',
    nameAr: 'الساعة الذهبية',
    category: PresetCategory.portrait,
    adjustments: Adjustments(
      temperature: 0.4,
      tint: 0.08,
      shadows: 0.2,
      vibrance: 0.2,
      vignette: -0.15,
      splitTone: SplitTone(highlightHue: 0.1, highlightSaturation: 0.3),
    ),
  ),
  Preset(
    id: 'airy',
    nameEn: 'Airy',
    nameAr: 'هوائي',
    category: PresetCategory.portrait,
    adjustments: Adjustments(
      exposure: 0.4,
      contrast: -0.2,
      highlights: -0.2,
      shadows: 0.3,
      saturation: -0.1,
      fade: 0.08,
    ),
  ),
  Preset(
    id: 'studio',
    nameEn: 'Studio',
    nameAr: 'استوديو',
    category: PresetCategory.portrait,
    adjustments: Adjustments(contrast: 0.12, clarity: 0.1, vibrance: 0.1, whites: 0.1, blacks: -0.08),
  ),
  // ---- Black & white
  Preset(
    id: 'mono',
    nameEn: 'Mono',
    nameAr: 'أحادي',
    category: PresetCategory.bw,
    adjustments: Adjustments(saturation: -1, contrast: 0.1),
  ),
  Preset(
    id: 'tri_x',
    nameEn: 'Tri 400',
    nameAr: 'تراي ٤٠٠',
    category: PresetCategory.bw,
    adjustments: Adjustments(
      saturation: -1,
      contrast: 0.35,
      grain: 0.35,
      clarity: 0.2,
      curves: CurveSet(master: _strongS),
    ),
  ),
  Preset(
    id: 'noir',
    nameEn: 'Noir',
    nameAr: 'نوار',
    category: PresetCategory.bw,
    adjustments: Adjustments(saturation: -1, contrast: 0.5, blacks: -0.25, vignette: -0.5, exposure: -0.15),
  ),
  Preset(
    id: 'silver',
    nameEn: 'Silver',
    nameAr: 'فضي',
    category: PresetCategory.bw,
    adjustments: Adjustments(
      saturation: -1,
      fade: 0.15,
      contrast: -0.05,
      splitTone: SplitTone(shadowHue: 0.6, shadowSaturation: 0.1),
    ),
  ),
  Preset(
    id: 'sepia',
    nameEn: 'Sepia',
    nameAr: 'بني عتيق',
    category: PresetCategory.bw,
    adjustments: Adjustments(
      duotone: Duotone(strength: 0.9, shadowColor: 0xFF2B1A0E, highlightColor: 0xFFF2DDB7),
      fade: 0.1,
      grain: 0.15,
    ),
  ),
  // ---- Creative
  Preset(
    id: 'cyberpunk',
    nameEn: 'Cyberpunk',
    nameAr: 'سايبربانك',
    category: PresetCategory.creative,
    adjustments: Adjustments(
      tint: 0.4,
      temperature: -0.3,
      contrast: 0.25,
      vibrance: 0.4,
      chromaticAberration: 0.25,
      splitTone: SplitTone(shadowHue: 0.72, shadowSaturation: 0.4, highlightHue: 0.5, highlightSaturation: 0.3),
    ),
  ),
  Preset(
    id: 'vhs',
    nameEn: 'VHS',
    nameAr: 'شريط فيديو',
    category: PresetCategory.creative,
    adjustments: Adjustments(
      glitch: 0.25,
      chromaticAberration: 0.4,
      grain: 0.3,
      fade: 0.15,
      saturation: -0.1,
      blur: 0.05,
    ),
  ),
  Preset(
    id: 'duotone_sunset',
    nameEn: 'Sunset Duo',
    nameAr: 'ثنائي الغروب',
    category: PresetCategory.creative,
    adjustments: Adjustments(
      duotone: Duotone(strength: 1, shadowColor: 0xFF2A0A4A, highlightColor: 0xFFFF9E57),
      contrast: 0.15,
    ),
  ),
  Preset(
    id: 'dreamy',
    nameEn: 'Dreamy',
    nameAr: 'حالم',
    category: PresetCategory.creative,
    adjustments: Adjustments(
      clarity: -0.4,
      exposure: 0.2,
      fade: 0.15,
      tint: 0.1,
      vignette: 0.2,
      splitTone: SplitTone(shadowHue: 0.75, shadowSaturation: 0.2, highlightHue: 0.95, highlightSaturation: 0.15),
    ),
  ),
];

Preset? presetById(String? id) {
  if (id == null) return null;
  for (final p in kBuiltInPresets) {
    if (p.id == id) return p;
  }
  return null;
}
