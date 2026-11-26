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
    this.aiAcceleration = false,
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

  /// Opt-in XNNPACK execution provider + KleidiAI kernels for on-device AI.
  /// Off by default: plain CPU is slower but the most compatible (some
  /// devices/graphs crash natively with the accelerated kernels).
  final bool aiAcceleration;

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
    bool? aiAcceleration,
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
    aiAcceleration: aiAcceleration ?? this.aiAcceleration,
    onboardingDone: onboardingDone ?? this.onboardingDone,
    loaded: loaded ?? this.loaded,
  );
}

/// Persisted user preferences (SharedPreferences).
@Riverpod(keepAlive: true)
class SettingsController extends _$SettingsController {
  // One shared future so a setter called before the first load finishes
  // still persists (it used to be dropped while the prefs were null).
  Future<void> _loaded = Future<void>.value();
  late final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  @override
  AppSettings build() {
    _loaded = _load();
    return const AppSettings();
  }

  Future<void> _load() async {
    final prefs = await _prefs;
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
      aiAcceleration: prefs.getBool('aiAcceleration') ?? false,
      // Existing installs (who already have preferences) skip the tips.
      onboardingDone: prefs.getBool('onboardingDone') ?? prefs.containsKey('exportQuality'),
      loaded: true,
    );
    Haptics.enabled = state.haptics;
  }

  Future<void> setLocale(Locale? locale) async {
    await _loaded;
    state = state.copyWith(locale: () => locale);
    if (locale == null) {
      await (await _prefs).remove('locale');
    } else {
      await (await _prefs).setString('locale', locale.languageCode);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _loaded;
    state = state.copyWith(themeMode: mode);
    await (await _prefs).setInt('themeMode', mode.index);
  }

  Future<void> setExport({ExportFormat? format, int? quality, bool? keepExif}) async {
    await _loaded;
    state = state.copyWith(exportFormat: format, exportQuality: quality, keepExif: keepExif);
    await (await _prefs).setInt('exportFormat', state.exportFormat.index);
    await (await _prefs).setInt('exportQuality', state.exportQuality);
    await (await _prefs).setBool('keepExif', state.keepExif);
  }

  Future<void> setExportMaxDimension(int? px) async {
    await _loaded;
    state = state.copyWith(exportMaxDimension: () => px);
    await (await _prefs).setInt('exportMaxDimension', px ?? 0);
  }

  Future<void> setHaptics({required bool enabled}) async {
    await _loaded;
    state = state.copyWith(haptics: enabled);
    Haptics.enabled = enabled;
    await (await _prefs).setBool('haptics', enabled);
  }

  Future<void> setAiAcceleration({required bool enabled}) async {
    await _loaded;
    state = state.copyWith(aiAcceleration: enabled);
    await (await _prefs).setBool('aiAcceleration', enabled);
  }

  Future<void> setOnboardingDone({bool done = true}) async {
    await _loaded;
    state = state.copyWith(onboardingDone: done);
    await (await _prefs).setBool('onboardingDone', done);
  }
}
