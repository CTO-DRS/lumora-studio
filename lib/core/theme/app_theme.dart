import 'package:material_ui/material_ui.dart';

/// Lumora design tokens: deep graphite surfaces with an amber→violet accent.
abstract final class AppTheme {
  static const seed = Color(0xFFFFB547);
  static const accent2 = Color(0xFF8B7CFF);

  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness b) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: seed,
          brightness: b,
          dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
        ).copyWith(
          surface: b == Brightness.dark ? const Color(0xFF0E0E12) : null,
          surfaceContainer: b == Brightness.dark ? const Color(0xFF17171D) : null,
          surfaceContainerHigh: b == Brightness.dark ? const Color(0xFF1F1F27) : null,
          secondary: accent2,
        );
    final base = ThemeData(colorScheme: scheme, brightness: b);
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      sliderTheme: base.sliderTheme.copyWith(
        trackHeight: 3,
        showValueIndicator: ShowValueIndicator.onDrag,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: scheme.surfaceContainer, showDragHandle: true),
      chipTheme: base.chipTheme.copyWith(shape: const StadiumBorder(), side: BorderSide.none),
    );
  }
}
