import 'package:freezed_annotation/freezed_annotation.dart';

part 'adjustments.freezed.dart';
part 'adjustments.g.dart';

/// A control point of a tone curve, both axes normalized to 0..1.
@freezed
abstract class CurvePoint with _$CurvePoint {
  const factory CurvePoint(double x, double y) = _CurvePoint;

  factory CurvePoint.fromJson(Map<String, dynamic> json) => _$CurvePointFromJson(json);
}

const List<CurvePoint> kIdentityCurve = [CurvePoint(0, 0), CurvePoint(1, 1)];

/// RGB master curve + per channel curves.
@freezed
abstract class CurveSet with _$CurveSet {
  const factory CurveSet({
    @Default(kIdentityCurve) List<CurvePoint> master,
    @Default(kIdentityCurve) List<CurvePoint> red,
    @Default(kIdentityCurve) List<CurvePoint> green,
    @Default(kIdentityCurve) List<CurvePoint> blue,
  }) = _CurveSet;

  const CurveSet._();

  factory CurveSet.fromJson(Map<String, dynamic> json) => _$CurveSetFromJson(json);

  bool get isIdentity => _isId(master) && _isId(red) && _isId(green) && _isId(blue);

  static bool _isId(List<CurvePoint> c) => c.every((p) => p.x == p.y);
}

/// Eight band HSL mixer. Each list holds 8 values in -1..1 for the bands
/// red, orange, yellow, green, aqua, blue, purple, magenta.
@freezed
abstract class HslAdjustments with _$HslAdjustments {
  const factory HslAdjustments({
    @Default(kZeroBands) List<double> hue,
    @Default(kZeroBands) List<double> saturation,
    @Default(kZeroBands) List<double> luminance,
  }) = _HslAdjustments;

  const HslAdjustments._();

  factory HslAdjustments.fromJson(Map<String, dynamic> json) => _$HslAdjustmentsFromJson(json);

  bool get isNeutral => hue.every((v) => v == 0) && saturation.every((v) => v == 0) && luminance.every((v) => v == 0);
}

const List<double> kZeroBands = [0, 0, 0, 0, 0, 0, 0, 0];

enum HslBand { red, orange, yellow, green, aqua, blue, purple, magenta }

/// Split toning colours (hues 0..1, saturation 0..1) and balance -1..1.
@freezed
abstract class SplitTone with _$SplitTone {
  const factory SplitTone({
    @Default(0.58) double shadowHue,
    @Default(0) double shadowSaturation,
    @Default(0.08) double highlightHue,
    @Default(0) double highlightSaturation,
    @Default(0) double balance,
  }) = _SplitTone;

  factory SplitTone.fromJson(Map<String, dynamic> json) => _$SplitToneFromJson(json);
}

/// Duotone mapping (ARGB ints) and strength 0..1.
@freezed
abstract class Duotone with _$Duotone {
  const factory Duotone({
    @Default(0) double strength,
    @Default(0xFF1B1035) int shadowColor,
    @Default(0xFFFFC46B) int highlightColor,
  }) = _Duotone;

  factory Duotone.fromJson(Map<String, dynamic> json) => _$DuotoneFromJson(json);
}

/// Every global, non-destructive photo adjustment. All sliders are
/// normalized: most are -1..1 with 0 as neutral, exposure is in EV.
@freezed
abstract class Adjustments with _$Adjustments {
  const factory Adjustments({
    // Light
    @Default(0) double exposure,
    @Default(0) double contrast,
    @Default(0) double highlights,
    @Default(0) double shadows,
    @Default(0) double whites,
    @Default(0) double blacks,
    // Colour
    @Default(0) double temperature,
    @Default(0) double tint,
    @Default(0) double vibrance,
    @Default(0) double saturation,
    @Default(HslAdjustments()) HslAdjustments hsl,
    @Default(SplitTone()) SplitTone splitTone,
    @Default(CurveSet()) CurveSet curves,
    @Default(0) double fade,
    // Detail
    @Default(0) double sharpen,
    @Default(0) double clarity,
    @Default(0) double structure,
    @Default(0) double dehaze,
    @Default(0) double blur,
    // Effects
    @Default(0) double vignette,
    @Default(0.5) double vignetteMidpoint,
    @Default(0) double vignetteRoundness,
    @Default(0.5) double vignetteFeather,
    @Default(0) double grain,
    @Default(0.5) double grainSize,
    @Default(0) double chromaticAberration,
    @Default(0) double glitch,
    @Default(Duotone()) Duotone duotone,
    // LUT
    String? lutId,
    @Default(1) double lutIntensity,
  }) = _Adjustments;

  const Adjustments._();

  factory Adjustments.fromJson(Map<String, dynamic> json) => _$AdjustmentsFromJson(json);

  static const neutral = Adjustments();

  bool get hasDetail => sharpen != 0 || clarity != 0 || structure != 0 || dehaze != 0;

  bool get hasEffects =>
      vignette != 0 || grain != 0 || chromaticAberration != 0 || glitch != 0 || duotone.strength != 0;

  bool get isNeutral => this == neutral;
}

/// Identifies one scalar slider of [Adjustments] so that UI, presets and
/// local adjustments can address parameters generically.
enum AdjustmentParam {
  exposure(-5, 5),
  contrast(-1, 1),
  highlights(-1, 1),
  shadows(-1, 1),
  whites(-1, 1),
  blacks(-1, 1),
  temperature(-1, 1),
  tint(-1, 1),
  vibrance(-1, 1),
  saturation(-1, 1),
  fade(0, 1),
  sharpen(0, 1),
  clarity(-1, 1),
  structure(-1, 1),
  dehaze(-1, 1),
  blur(0, 1),
  vignette(-1, 1),
  vignetteMidpoint(0, 1),
  vignetteFeather(0, 1),
  grain(0, 1),
  grainSize(0, 1),
  chromaticAberration(0, 1),
  glitch(0, 1),
  lutIntensity(0, 1);

  const AdjustmentParam(this.min, this.max);

  final double min;
  final double max;

  double read(Adjustments a) => switch (this) {
    exposure => a.exposure,
    contrast => a.contrast,
    highlights => a.highlights,
    shadows => a.shadows,
    whites => a.whites,
    blacks => a.blacks,
    temperature => a.temperature,
    tint => a.tint,
    vibrance => a.vibrance,
    saturation => a.saturation,
    fade => a.fade,
    sharpen => a.sharpen,
    clarity => a.clarity,
    structure => a.structure,
    dehaze => a.dehaze,
    blur => a.blur,
    vignette => a.vignette,
    vignetteMidpoint => a.vignetteMidpoint,
    vignetteFeather => a.vignetteFeather,
    grain => a.grain,
    grainSize => a.grainSize,
    chromaticAberration => a.chromaticAberration,
    glitch => a.glitch,
    lutIntensity => a.lutIntensity,
  };

  Adjustments write(Adjustments a, double v) {
    final x = v.clamp(min, max);
    return switch (this) {
      exposure => a.copyWith(exposure: x),
      contrast => a.copyWith(contrast: x),
      highlights => a.copyWith(highlights: x),
      shadows => a.copyWith(shadows: x),
      whites => a.copyWith(whites: x),
      blacks => a.copyWith(blacks: x),
      temperature => a.copyWith(temperature: x),
      tint => a.copyWith(tint: x),
      vibrance => a.copyWith(vibrance: x),
      saturation => a.copyWith(saturation: x),
      fade => a.copyWith(fade: x),
      sharpen => a.copyWith(sharpen: x),
      clarity => a.copyWith(clarity: x),
      structure => a.copyWith(structure: x),
      dehaze => a.copyWith(dehaze: x),
      blur => a.copyWith(blur: x),
      vignette => a.copyWith(vignette: x),
      vignetteMidpoint => a.copyWith(vignetteMidpoint: x),
      vignetteFeather => a.copyWith(vignetteFeather: x),
      grain => a.copyWith(grain: x),
      grainSize => a.copyWith(grainSize: x),
      chromaticAberration => a.copyWith(chromaticAberration: x),
      glitch => a.copyWith(glitch: x),
      lutIntensity => a.copyWith(lutIntensity: x),
    };
  }

  double get neutral => switch (this) {
    vignetteMidpoint || vignetteFeather || grainSize => 0.5,
    lutIntensity => 1,
    _ => 0,
  };
}
