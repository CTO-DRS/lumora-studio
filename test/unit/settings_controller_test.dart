import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/photo_editor/engine/image_exporter.dart';
import 'package:lumora/features/settings/data/settings_controller.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _boot([Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(initial);
  final c = ProviderContainer();
  addTearDown(c.dispose);
  c.read(settingsControllerProvider);
  // Let the async load settle.
  for (var i = 0; i < 20 && !c.read(settingsControllerProvider).loaded; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  return c;
}

void main() {
  test('fresh install: defaults, and the first-run tips are still to be shown', () async {
    final c = await _boot();
    final s = c.read(settingsControllerProvider);
    expect(s.loaded, isTrue);
    expect(s.locale, isNull);
    expect(s.themeMode, ThemeMode.dark);
    expect(s.exportQuality, 95);
    expect(s.exportMaxDimension, isNull);
    expect(s.aiAcceleration, isFalse);
    // No stored preferences at all means a new install: show the tips.
    expect(s.onboardingDone, isFalse);
  });

  test('an install that already has export preferences skips the tips', () async {
    final c = await _boot({'exportQuality': 80});
    expect(c.read(settingsControllerProvider).onboardingDone, isTrue);
  });

  test('out-of-range stored indexes are clamped and a zero max dimension means full size', () async {
    final c = await _boot({'themeMode': 99, 'exportFormat': 99, 'exportMaxDimension': 0});
    final s = c.read(settingsControllerProvider);
    expect(s.themeMode, ThemeMode.values.last);
    expect(s.exportFormat, ExportFormat.values.last);
    expect(s.exportMaxDimension, isNull);
  });

  test('setters persist and survive a restart', () async {
    final c = await _boot();
    final n = c.read(settingsControllerProvider.notifier);
    await n.setLocale(const Locale('ar'));
    await n.setThemeMode(ThemeMode.light);
    await n.setExport(quality: 70, keepExif: false);
    await n.setExportMaxDimension(2048);
    await n.setAiAcceleration(enabled: true);
    await n.setOnboardingDone();

    final prefs = await SharedPreferences.getInstance();
    final c2 = await _boot({for (final k in prefs.getKeys()) k: prefs.get(k)!});
    final s = c2.read(settingsControllerProvider);
    expect(s.locale, const Locale('ar'));
    expect(s.themeMode, ThemeMode.light);
    expect(s.exportQuality, 70);
    expect(s.keepExif, isFalse);
    expect(s.exportMaxDimension, 2048);
    expect(s.aiAcceleration, isTrue);
    expect(s.onboardingDone, isTrue);

    await c2.read(settingsControllerProvider.notifier).setLocale(null);
    expect(c2.read(settingsControllerProvider).locale, isNull);
    expect((await SharedPreferences.getInstance()).containsKey('locale'), isFalse);
  });

  test('a setter called before the first load finishes is still saved', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(settingsControllerProvider.notifier);
    await n.setThemeMode(ThemeMode.system);
    expect((await SharedPreferences.getInstance()).getInt('themeMode'), ThemeMode.system.index);
  });
}
