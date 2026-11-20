import 'package:lumora/core/utils/haptics.dart';
import 'package:lumora/features/photo_editor/engine/image_exporter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'settings_controller.g.dart';

class AppSettings {
  const AppSettings({
    this.locale,
    this.themeMode = ThemeMode.dark,
    this.exportFormat = ExportFormat.jpeg,
    this.exportQuality = 95,
    this.keepExif = true,
    this.exportMaxDimension,
    this.haptics = true,
    this.onboardingDone = true,
    this.loaded = false,
  });

  /// null = follow the system language.
  final Locale? locale;
  final ThemeMode themeMode;
  final ExportFormat exportFormat;
  final int exportQuality;
  final bool keepExif;

  /// Default long-edge limit for photo exports (null = full resolution).
  final int? exportMaxDimension;
  final bool haptics;

  /// Whether the first-run tips were shown.
  final bool onboardingDone;

  /// True once the persisted values were read.
  final bool loaded;

  AppSettings copyWith({
    Locale? Function()? locale,
    ThemeMode? themeMode,
    ExportFormat? exportFormat,
    int? exportQuality,
    bool? keepExif,
    int? Function()? exportMaxDimension,
    bool? haptics,
    bool? onboardingDone,
    bool? loaded,
  }) => AppSettings(
    locale: locale != null ? locale() : this.locale,
    themeMode: themeMode ?? this.themeMode,
    exportFormat: exportFormat ?? this.exportFormat,
    exportQuality: exportQuality ?? this.exportQuality,
    keepExif: keepExif ?? this.keepExif,
    exportMaxDimension: exportMaxDimension != null ? exportMaxDimension() : this.exportMaxDimension,
    haptics: haptics ?? this.haptics,
    onboardingDone: onboardingDone ?? this.onboardingDone,
    loaded: loaded ?? this.loaded,
  );
}

/// Persisted user preferences (SharedPreferences).
@Riverpod(keepAlive: true)
class SettingsController extends _$SettingsController {
  SharedPreferences? _prefs;

  @override
  AppSettings build() {
    _load();
    return const AppSettings();
  }

  Future<void> _load() async {
    final prefs = _prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('locale');
    final maxDim = prefs.getInt('exportMaxDimension');
    final themeIndex = prefs.getInt('themeMode') ?? ThemeMode.dark.index;
    final formatIndex = prefs.getInt('exportFormat') ?? 0;
    state = AppSettings(
      locale: lang == null ? null : Locale(lang),
      themeMode: ThemeMode.values[themeIndex.clamp(0, ThemeMode.values.length - 1)],
      exportFormat: ExportFormat.values[formatIndex.clamp(0, ExportFormat.values.length - 1)],
      exportQuality: prefs.getInt('exportQuality') ?? 95,
      keepExif: prefs.getBool('keepExif') ?? true,
      exportMaxDimension: maxDim == null || maxDim <= 0 ? null : maxDim,
      haptics: prefs.getBool('haptics') ?? true,
      // Existing installs (who already have preferences) skip the tips.
      onboardingDone: prefs.getBool('onboardingDone') ?? prefs.containsKey('exportQuality'),
      loaded: true,
    );
    Haptics.enabled = state.haptics;
  }

  Future<void> setLocale(Locale? locale) async {
    state = state.copyWith(locale: () => locale);
    if (locale == null) {
      await _prefs?.remove('locale');
    } else {
      await _prefs?.setString('locale', locale.languageCode);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs?.setInt('themeMode', mode.index);
  }

  Future<void> setExport({ExportFormat? format, int? quality, bool? keepExif}) async {
    state = state.copyWith(exportFormat: format, exportQuality: quality, keepExif: keepExif);
    await _prefs?.setInt('exportFormat', state.exportFormat.index);
    await _prefs?.setInt('exportQuality', state.exportQuality);
    await _prefs?.setBool('keepExif', state.keepExif);
  }

  Future<void> setExportMaxDimension(int? px) async {
    state = state.copyWith(exportMaxDimension: () => px);
    await _prefs?.setInt('exportMaxDimension', px ?? 0);
  }

  Future<void> setHaptics({required bool enabled}) async {
    state = state.copyWith(haptics: enabled);
    Haptics.enabled = enabled;
    await _prefs?.setBool('haptics', enabled);
  }

  Future<void> setOnboardingDone({bool done = true}) async {
    state = state.copyWith(onboardingDone: done);
    await _prefs?.setBool('onboardingDone', done);
  }
}
