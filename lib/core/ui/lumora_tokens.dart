import 'dart:ui' show lerpDouble;

import 'package:material_ui/material_ui.dart';

/// A soft background glow: a radial gradient centred at [alignment].
@immutable
class GlowBlob {
  const GlowBlob(this.alignment, this.radius, this.color);

  final Alignment alignment;

  /// Radius as a fraction of the shortest side of the area.
  final double radius;
  final Color color;
}

/// Lumora v1.2 design tokens ("calm glass"): frosted surfaces on a calm
/// navy background, soft violet→blue accents and muted pastel tool colours.
///
/// Colours are deliberately desaturated so long editing sessions stay easy
/// on the eyes. Glow is reserved for the active element and the main call
/// to action. Read them with `context.lumora`.
@immutable
class LumoraTokens extends ThemeExtension<LumoraTokens> {
  const LumoraTokens({
    required this.brightness,
    required this.background,
    required this.blobs,
    required this.glassFill,
    required this.glassFillStrong,
    required this.glassHighlight,
    required this.sheetFill,
    required this.borderColors,
    required this.borderActiveColors,
    required this.primaryGradient,
    required this.heroGradient,
    required this.glow,
    required this.trackInactive,
    required this.textMuted,
    required this.blue,
    required this.teal,
    required this.rose,
    required this.mint,
    required this.apricot,
    required this.violet,
    this.blurSigma = 18,
  });

  final Brightness brightness;

  /// Page background.
  final Color background;

  /// Very faint static glows painted over [background].
  final List<GlowBlob> blobs;

  /// Translucent fill of glass cards (used without blur in lists).
  final Color glassFill;

  /// Fill of bars and panels that float over content.
  final Color glassFillStrong;

  /// Top-left sheen of glass surfaces.
  final Color glassHighlight;

  /// Opaque-ish fill of bottom sheets, dialogs and menus.
  final Color sheetFill;

  /// Hairline border gradient (violet → blue), ~40 % opacity.
  final List<Color> borderColors;

  /// Border of the selected / active element.
  final List<Color> borderActiveColors;

  /// Main call-to-action gradient. White text on it meets WCAG AA.
  final List<Color> primaryGradient;

  /// Low-alpha gradient of the home hero card.
  final List<Color> heroGradient;

  /// Glow colour of the active element and the main CTA.
  final Color glow;

  final Color trackInactive;
  final Color textMuted;

  // Muted accent palette for tool orbs (white icons stay ≥ 3:1).
  final Color blue;
  final Color teal;
  final Color rose;
  final Color mint;
  final Color apricot;
  final Color violet;

  final double blurSigma;

  bool get isDark => brightness == Brightness.dark;

  /// Accent colours in the order quick tools use them.
  List<Color> get accents => [violet, teal, rose, mint, apricot, blue];

  static const LumoraTokens dark = LumoraTokens(
    brightness: Brightness.dark,
    background: Color(0xFF0E1022),
    blobs: [
      GlowBlob(Alignment(-1.1, -0.95), 0.95, Color(0x1E7C6CF2)), // 0.12
      GlowBlob(Alignment(1.15, -0.2), 0.8, Color(0x175B8DEF)), // 0.09
      GlowBlob(Alignment(-1.05, 0.55), 0.7, Color(0x146F8FD8)), // 0.08
      GlowBlob(Alignment(1.1, 1.05), 0.85, Color(0x147C6CF2)), // 0.08
    ],
    glassFill: Color(0x0FFFFFFF), // 6 %
    glassFillStrong: Color(0xE6161931),
    glassHighlight: Color(0x0DFFFFFF),
    sheetFill: Color(0xF5161931),
    borderColors: [Color(0x669486E8), Color(0x5C7896E6), Color(0x5277A7D6)],
    borderActiveColors: [Color(0xD9A396F5), Color(0xD98AA8F0)],
    primaryGradient: [Color(0xFF6E5FE0), Color(0xFF4C7BD8)],
    heroGradient: [Color(0x386E5FE0), Color(0x2B4C7BD8)],
    glow: Color(0x597468E6),
    trackInactive: Color(0x24FFFFFF),
    textMuted: Color(0xFFA3A8C3),
    blue: Color(0xFF5B7FD6),
    teal: Color(0xFF3D9AA8),
    rose: Color(0xFFC2668E),
    mint: Color(0xFF3F9F7E),
    apricot: Color(0xFFC47F4E),
    violet: Color(0xFF7A6AD8),
  );

  static const LumoraTokens light = LumoraTokens(
    brightness: Brightness.light,
    background: Color(0xFFF3F4FA),
    blobs: [
      GlowBlob(Alignment(-1.1, -0.95), 0.95, Color(0x1A7C6CF2)),
      GlowBlob(Alignment(1.15, -0.2), 0.8, Color(0x145B8DEF)),
      GlowBlob(Alignment(-1.05, 0.55), 0.7, Color(0x0F6F8FD8)),
      GlowBlob(Alignment(1.1, 1.05), 0.85, Color(0x127C6CF2)),
    ],
    glassFill: Color(0xB3FFFFFF),
    glassFillStrong: Color(0xD9FFFFFF),
    glassHighlight: Color(0x66FFFFFF),
    sheetFill: Color(0xFAF8F9FD),
    borderColors: [Color(0x598E80E0), Color(0x4D7896E6), Color(0x4277A7D6)],
    borderActiveColors: [Color(0xCC6E5FE0), Color(0xCC4C7BD8)],
    primaryGradient: [Color(0xFF6E5FE0), Color(0xFF4C7BD8)],
    heroGradient: [Color(0x336E5FE0), Color(0x264C7BD8)],
    glow: Color(0x406E5FE0),
    trackInactive: Color(0x1F1B1D33),
    textMuted: Color(0xFF5A5F7A),
    blue: Color(0xFF5B7FD6),
    teal: Color(0xFF3D9AA8),
    rose: Color(0xFFC2668E),
    mint: Color(0xFF3F9F7E),
    apricot: Color(0xFFC47F4E),
    violet: Color(0xFF7A6AD8),
  );

  @override
  LumoraTokens copyWith({Color? background, Color? glassFill}) => LumoraTokens(
    brightness: brightness,
    background: background ?? this.background,
    blobs: blobs,
    glassFill: glassFill ?? this.glassFill,
    glassFillStrong: glassFillStrong,
    glassHighlight: glassHighlight,
    sheetFill: sheetFill,
    borderColors: borderColors,
    borderActiveColors: borderActiveColors,
    primaryGradient: primaryGradient,
    heroGradient: heroGradient,
    glow: glow,
    trackInactive: trackInactive,
    textMuted: textMuted,
    blue: blue,
    teal: teal,
    rose: rose,
    mint: mint,
    apricot: apricot,
    violet: violet,
    blurSigma: blurSigma,
  );

  @override
  LumoraTokens lerp(covariant LumoraTokens? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    List<Color> l(List<Color> a, List<Color> b) => [for (var i = 0; i < a.length; i++) c(a[i], b[i % b.length])];
    return LumoraTokens(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: c(background, other.background),
      blobs: [
        for (var i = 0; i < blobs.length; i++)
          GlowBlob(
            blobs[i].alignment,
            lerpDouble(blobs[i].radius, other.blobs[i % other.blobs.length].radius, t)!,
            c(blobs[i].color, other.blobs[i % other.blobs.length].color),
          ),
      ],
      glassFill: c(glassFill, other.glassFill),
      glassFillStrong: c(glassFillStrong, other.glassFillStrong),
      glassHighlight: c(glassHighlight, other.glassHighlight),
      sheetFill: c(sheetFill, other.sheetFill),
      borderColors: l(borderColors, other.borderColors),
      borderActiveColors: l(borderActiveColors, other.borderActiveColors),
      primaryGradient: l(primaryGradient, other.primaryGradient),
      heroGradient: l(heroGradient, other.heroGradient),
      glow: c(glow, other.glow),
      trackInactive: c(trackInactive, other.trackInactive),
      textMuted: c(textMuted, other.textMuted),
      blue: c(blue, other.blue),
      teal: c(teal, other.teal),
      rose: c(rose, other.rose),
      mint: c(mint, other.mint),
      apricot: c(apricot, other.apricot),
      violet: c(violet, other.violet),
      blurSigma: lerpDouble(blurSigma, other.blurSigma, t)!,
    );
  }
}

extension LumoraTokensX on BuildContext {
  /// The Lumora design tokens of the current theme.
  LumoraTokens get lumora => Theme.of(this).extension<LumoraTokens>() ?? LumoraTokens.dark;

  /// Whether the user asked the OS to reduce motion.
  bool get reduceMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;
}

/// Lightens [c] for the top-left of an orb gradient.
Color lighten(Color c, [double amount = 0.14]) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness + amount).clamp(0, 1)).toColor();
}
