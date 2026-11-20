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
  });

  /// null = follow the system language.
  final Locale? locale;
  final ThemeMode themeMode;
  final ExportFormat exportFormat;
  final int exportQuality;
  final bool keepExif;

  AppSettings copyWith({
    Locale? Function()? locale,
    ThemeMode? themeMode,
    ExportFormat? exportFormat,
    int? exportQuality,
    bool? keepExif,
  }) => AppSettings(
    locale: locale != null ? locale() : this.locale,
    themeMode: themeMode ?? this.themeMode,
    exportFormat: exportFormat ?? this.exportFormat,
    exportQuality: exportQuality ?? this.exportQuality,
    keepExif: keepExif ?? this.keepExif,
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
    state = AppSettings(
      locale: lang == null ? null : Locale(lang),
      themeMode: ThemeMode.values[prefs.getInt('themeMode') ?? ThemeMode.dark.index],
      exportFormat: ExportFormat.values[prefs.getInt('exportFormat') ?? 0],
      exportQuality: prefs.getInt('exportQuality') ?? 95,
      keepExif: prefs.getBool('keepExif') ?? true,
    );
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
}
