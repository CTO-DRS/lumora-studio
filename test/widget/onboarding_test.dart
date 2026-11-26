import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lumora/features/onboarding/presentation/onboarding_page.dart';
import 'package:lumora/features/settings/data/settings_controller.dart';
import 'package:lumora/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _open(WidgetTester tester, {Locale locale = const Locale('en')}) async {
  SharedPreferences.setMockInitialValues({});
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: TextButton(onPressed: () => context.push('/tips'), child: const Text('home')),
        ),
      ),
      GoRoute(path: '/tips', builder: (_, _) => const OnboardingPage()),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  // The app reads settings at launch; mirror that so the first load is done
  // before the tips write to them.
  final c = ProviderScope.containerOf(tester.element(find.text('home')));
  c.read(settingsControllerProvider);
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.tap(find.text('home'));
  await tester.pumpAndSettle();
  return c;
}

void main() {
  testWidgets('next walks the four tips, the last says Get started and finishing is remembered', (tester) async {
    final c = await _open(tester);
    expect(find.text('100% on your device'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Next'), findsNothing);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsNothing);
    expect(c.read(settingsControllerProvider).onboardingDone, isTrue);
  });

  testWidgets('skip closes the tips and also counts as done', (tester) async {
    final c = await _open(tester);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsNothing);
    expect(c.read(settingsControllerProvider).onboardingDone, isTrue);
  });

  testWidgets('Arabic shows localised buttons', (tester) async {
    await _open(tester, locale: const Locale('ar'));
    expect(find.text('تخطي'), findsOneWidget);
  });
}
