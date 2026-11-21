import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/app.dart';
import 'package:lumora/core/providers.dart';
import 'package:lumora/core/ui/ui.dart';
import 'package:lumora/features/collage/presentation/collage_page.dart';
import 'package:lumora/features/home/presentation/home_page.dart';
import 'package:lumora/features/home/presentation/projects_page.dart';
import 'package:lumora/features/home/presentation/templates_page.dart';
import 'package:lumora/features/projects/data/app_database.dart';
import 'package:lumora/features/scanner/presentation/scanner_page.dart';
import 'package:lumora/features/settings/presentation/settings_page.dart';
import 'package:material_ui/material_ui.dart' show BottomSheet;
import 'package:shared_preferences/shared_preferences.dart';

Future<AppDatabase> _boot(WidgetTester tester, {String location = '/', String? locale}) async {
  SharedPreferences.setMockInitialValues({'onboardingDone': true, 'locale': ?locale});
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: LumoraApp(initialLocation: location),
    ),
  );
  await tester.pumpAndSettle();
  return db;
}

Future<void> _dispose(WidgetTester tester) async {
  // Drift streams keep timers alive; dispose the tree explicitly.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

Finder _nav(String label) => find.descendant(of: find.byType(GlassNavBar), matching: find.text(label));

void main() {
  testWidgets('bottom navigation switches between the four tabs', (tester) async {
    await _boot(tester);
    expect(find.byType(GlassNavBar), findsOneWidget);
    expect(find.byType(HomePage), findsOneWidget);

    await tester.tap(_nav('Templates'));
    await tester.pumpAndSettle();
    expect(find.byType(TemplatesPage), findsOneWidget);
    expect(find.text('Pick a look, then choose a photo to apply it to'), findsOneWidget);

    await tester.tap(_nav('Projects'));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectsPage), findsOneWidget);
    expect(find.text('All projects'), findsOneWidget);

    await tester.tap(_nav('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);

    await tester.tap(_nav('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Edit photo'), findsWidgets);
    // Selected state is exposed to accessibility services.
    expect(
      tester.getSemantics(find.descendant(of: find.byType(GlassNavBar), matching: find.bySemanticsLabel('Home'))),
      isSemantics(isSelected: true, isButton: true),
    );
    await _dispose(tester);
  });

  testWidgets('home settings button opens the Settings tab', (tester) async {
    await _boot(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(GlassNavBar), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('create button opens a sheet whose tools open full screen', (tester) async {
    await _boot(tester);
    await tester.tap(find.bySemanticsLabel('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Create something new'), findsOneWidget);
    final sheet = find.byType(BottomSheet);
    for (final label in ['Edit photo', 'Edit video', 'Collage', 'Scan document', 'Batch edit']) {
      expect(find.descendant(of: sheet, matching: find.text(label)), findsOneWidget);
    }
    await tester.tap(find.descendant(of: sheet, matching: find.text('Collage')));
    await tester.pumpAndSettle();
    expect(find.byType(CollagePage), findsOneWidget);
    // Full-screen routes cover the navigation bar.
    expect(find.byType(GlassNavBar), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(GlassNavBar), findsOneWidget);
    expect(find.byType(HomePage), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('deep link to a tab opens it inside the shell', (tester) async {
    await _boot(tester, location: '/settings');
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(GlassNavBar), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('deep link to a tool opens it above the shell', (tester) async {
    await _boot(tester, location: '/scan');
    expect(find.byType(ScannerPage), findsOneWidget);
    expect(find.byType(GlassNavBar), findsNothing);
    await _dispose(tester);
  });

  testWidgets('AI tools sheet from Home lists the on-device tools (Arabic, RTL)', (tester) async {
    await _boot(tester, locale: 'ar');
    expect(find.text('الرئيسية'), findsOneWidget);
    await tester.dragUntilVisible(find.text('أدوات الذكاء'), find.byType(ListView).first, const Offset(300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('أدوات الذكاء'));
    await tester.pumpAndSettle();
    expect(find.text('أدوات الذكاء الاصطناعي'), findsOneWidget);
    expect(find.text('يعمل على جهازك'), findsOneWidget);
    expect(find.text('إزالة الخلفية'), findsWidgets);
    expect(find.text('ماسح المستندات'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('يعمل على جهازك'))), TextDirection.rtl);
    await _dispose(tester);
  });
}
