import 'package:lumora/core/ui/lumora_tokens.dart';
import 'package:lumora/core/ui/slider_shapes.dart';
import 'package:material_ui/material_ui.dart';

/// Lumora v1.2 theme: calm navy glass with soft violet→blue accents.
///
/// Every Material component is tuned from [LumoraTokens] so existing
/// screens inherit the look; custom glass widgets live in `core/ui`.
abstract final class AppTheme {
  /// Brand violet (start of the primary gradient).
  static const seed = Color(0xFF6E5FE0);

  /// Brand blue (end of the primary gradient).
  static const accent2 = Color(0xFF4C7BD8);

  static ThemeData dark() => _build(LumoraTokens.dark);
  static ThemeData light() => _build(LumoraTokens.light);

  static ColorScheme scheme(Brightness b) => b == Brightness.dark ? _darkScheme : _lightScheme;

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFAFA4FF),
    onPrimary: Color(0xFF1C1748),
    primaryContainer: Color(0xFF2E2A63),
    onPrimaryContainer: Color(0xFFE0DBFF),
    secondary: Color(0xFF9DB7F2),
    onSecondary: Color(0xFF14254A),
    secondaryContainer: Color(0xFF233457),
    onSecondaryContainer: Color(0xFFD8E3FF),
    tertiary: Color(0xFF86CCD3),
    onTertiary: Color(0xFF0E3338),
    tertiaryContainer: Color(0xFF1F4549),
    onTertiaryContainer: Color(0xFFCDEFF2),
    error: Color(0xFFF2A3AD),
    onError: Color(0xFF4A0D18),
    errorContainer: Color(0xFF5E2430),
    onErrorContainer: Color(0xFFFFDADF),
    surface: Color(0xFF0E1022),
    onSurface: Color(0xFFE8EAF6),
    onSurfaceVariant: Color(0xFFA3A8C3),
    surfaceDim: Color(0xFF0B0D1C),
    surfaceBright: Color(0xFF2A2E52),
    surfaceContainerLowest: Color(0xFF0B0D1C),
    surfaceContainerLow: Color(0xFF13152B),
    surfaceContainer: Color(0xFF171A33),
    surfaceContainerHigh: Color(0xFF1D2040),
    surfaceContainerHighest: Color(0xFF25294C),
    outline: Color(0xFF555B80),
    outlineVariant: Color(0xFF2E3358),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFFE8EAF6),
    onInverseSurface: Color(0xFF171A33),
    inversePrimary: Color(0xFF5B4FD0),
    surfaceTint: Colors.transparent,
  );

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF5B4FD0),
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFE4E0FF),
    onPrimaryContainer: Color(0xFF221A66),
    secondary: Color(0xFF3F67C2),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFDCE5FB),
    onSecondaryContainer: Color(0xFF13285A),
    tertiary: Color(0xFF2F7F89),
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFD3EEF1),
    onTertiaryContainer: Color(0xFF0E3338),
    error: Color(0xFFB3384D),
    onError: Colors.white,
    errorContainer: Color(0xFFFFDADF),
    onErrorContainer: Color(0xFF4A0D18),
    surface: Color(0xFFF3F4FA),
    onSurface: Color(0xFF1B1D33),
    onSurfaceVariant: Color(0xFF5A5F7A),
    surfaceDim: Color(0xFFDDDFEA),
    surfaceBright: Color(0xFFFFFFFF),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF8F9FD),
    surfaceContainer: Color(0xFFEEF0F8),
    surfaceContainerHigh: Color(0xFFE8EAF5),
    surfaceContainerHighest: Color(0xFFE1E4F2),
    outline: Color(0xFF9DA2BF),
    outlineVariant: Color(0xFFD5D8EA),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFF25283F),
    onInverseSurface: Color(0xFFEDEEF8),
    inversePrimary: Color(0xFFAFA4FF),
    surfaceTint: Colors.transparent,
  );

  static ThemeData _build(LumoraTokens t) {
    final scheme = AppTheme.scheme(t.brightness);
    final base = ThemeData(colorScheme: scheme, brightness: t.brightness);
    final border = t.borderColors.first;
    final ctaFill = t.primaryGradient.first;
    final selectedFill = scheme.primary.withValues(alpha: t.isDark ? 0.2 : 0.14);
    const pill = StadiumBorder();
    final roundedSide = BorderSide(color: border);
    WidgetStateProperty<T> states<T>(T selected, T normal) =>
        WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? selected : normal);

    return base.copyWith(
      scaffoldBackgroundColor: t.background,
      canvasColor: t.background,
      extensions: [t],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: t.glassFill,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: roundedSide),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ctaFill,
          foregroundColor: Colors.white,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.1),
          shape: pill,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: roundedSide,
          shape: pill,
          backgroundColor: t.glassFill,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.primary, shape: pill),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: scheme.onSurface)),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: states(selectedFill, t.glassFill),
          foregroundColor: states(scheme.onSurface, t.textMuted),
          iconColor: states(scheme.primary, t.textMuted),
          side: WidgetStatePropertyAll(roundedSide),
          shape: const WidgetStatePropertyAll(pill),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: t.glassFill,
        selectedColor: selectedFill,
        disabledColor: t.glassFill,
        side: WidgetStateBorderSide.resolveWith(
          (s) => BorderSide(color: s.contains(WidgetState.selected) ? t.borderActiveColors.first : border),
        ),
        shape: pill,
        showCheckmark: false,
        labelStyle: base.textTheme.labelLarge?.copyWith(color: scheme.onSurface),
        secondaryLabelStyle: base.textTheme.labelLarge?.copyWith(color: scheme.onSurface),
        iconTheme: IconThemeData(color: scheme.primary, size: 16),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.sheetFill,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: roundedSide),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.sheetFill,
        modalBackgroundColor: t.sheetFill,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.onSurface.withValues(alpha: 0.28),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          side: roundedSide,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: t.isDark ? const Color(0xFF232747) : const Color(0xFF25283F),
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(color: const Color(0xFFE8EAF6)),
        actionTextColor: const Color(0xFFAFA4FF),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: roundedSide),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: t.sheetFill,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: roundedSide),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(t.sheetFill),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: roundedSide),
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: scheme.onSurface,
        unselectedLabelColor: t.textMuted,
        labelStyle: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        indicator: ShapeDecoration(
          color: selectedFill,
          shape: StadiumBorder(side: BorderSide(color: t.borderActiveColors.first.withValues(alpha: 0.6))),
        ),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: states(Colors.white, scheme.onSurfaceVariant),
        trackColor: states(ctaFill, t.glassFill),
        trackOutlineColor: states(Colors.transparent, border),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: states(ctaFill, Colors.transparent),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: BorderSide(color: scheme.outline, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(fillColor: states(scheme.primary, scheme.outline)),
      sliderTheme: base.sliderTheme.copyWith(
        trackHeight: 4,
        showValueIndicator: ShowValueIndicator.onDrag,
        activeTrackColor: scheme.primary,
        inactiveTrackColor: t.trackInactive,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.08),
        valueIndicatorColor: t.isDark ? const Color(0xFF2A2E52) : const Color(0xFF25283F),
        valueIndicatorTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        trackShape: GlowSliderTrackShape(colors: t.primaryGradient, inactive: t.trackInactive),
        thumbShape: GlowSliderThumbShape(
          colors: [lighten(t.primaryGradient.first, 0.08), t.primaryGradient.last],
          glow: t.glow,
        ),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: t.trackInactive,
        circularTrackColor: t.trackInactive,
        linearMinHeight: 5,
        borderRadius: BorderRadius.circular(4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.glassFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: roundedSide),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: roundedSide),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: t.borderActiveColors.first, width: 1.4),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: t.textMuted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.6), space: 1),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: t.isDark ? const Color(0xFF2A2E52) : const Color(0xFF25283F),
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(backgroundColor: WidgetStatePropertyAll(t.sheetFill)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: ctaFill,
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
      ),
    );
  }
}
