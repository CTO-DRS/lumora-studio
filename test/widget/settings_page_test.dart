import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/settings/data/settings_controller.dart';
import 'package:lumora/features/settings/presentation/settings_page.dart';
import 'package:lumora/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A1: the Settings page — sections render and the theme, haptics and
/// language controls drive the settings controller (persistence itself is
/// unit-covered by settings_controller_test.dart).
Widget _wrap(Widget child) => ProviderScope(
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  ),
);

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(SettingsPage)));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('sections and appearance controls render', (tester) async {
    await tester.pumpWidget(_wrap(const SettingsPage()));
    await tester.pump();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Haptic feedback'), findsOneWidget);
    expect(find.text('Export defaults'), findsOneWidget);
    // The remaining groups are below the fold of the lazily-built list;
    // scroll to build them, then match without the visibility filter.
    await tester.scrollUntilVisible(find.text('Storage', skipOffstage: false), 200);
    expect(find.text('Storage', skipOffstage: false), findsOneWidget);
    expect(find.text('AI models', skipOffstage: false), findsOneWidget);
    await tester.scrollUntilVisible(find.text('About', skipOffstage: false), 200);
    expect(find.text('About', skipOffstage: false), findsWidgets);
  });

  testWidgets('theme segmented button switches the controller', (tester) async {
    await tester.pumpWidget(_wrap(const SettingsPage()));
    await tester.pump();
    await tester.tap(find.text('Light'));
    await tester.pump();
    expect(_container(tester).read(settingsControllerProvider).themeMode, ThemeMode.light);
    await tester.tap(find.text('Dark'));
    await tester.pump();
    expect(_container(tester).read(settingsControllerProvider).themeMode, ThemeMode.dark);
  });

  testWidgets('haptics switch toggles the controller', (tester) async {
    await tester.pumpWidget(_wrap(const SettingsPage()));
    await tester.pump();
    final before = _container(tester).read(settingsControllerProvider).haptics;
    await tester.tap(find.text('Haptic feedback'));
    await tester.pump();
    expect(_container(tester).read(settingsControllerProvider).haptics, !before);
  });

  testWidgets('language dropdown sets an explicit locale', (tester) async {
    await tester.pumpWidget(_wrap(const SettingsPage()));
    await tester.pump();
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('العربية').last);
    await tester.pumpAndSettle();
    expect(_container(tester).read(settingsControllerProvider).locale?.languageCode, 'ar');
  });
}
