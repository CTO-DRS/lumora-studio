import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/home/presentation/templates_page.dart';
import 'package:lumora/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A1: the Templates tab — browse looks by category, empty states.
Widget _wrap(Widget child) => ProviderScope(
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows title, subtitle, category chips and the essentials looks', (tester) async {
    await tester.pumpWidget(_wrap(const TemplatesPage()));
    await tester.pump();
    expect(find.text('Templates'), findsOneWidget);
    expect(find.text('Pick a look, then choose a photo to apply it to'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('Essentials'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    // The chip row is a lazily-built horizontal ListView: scroll it left
    // to build the trailing chips.
    for (var i = 0; i < 3; i++) {
      await tester.drag(find.byType(ListView), const Offset(-500, 0));
      await tester.pump();
    }
    expect(find.text('My presets'), findsOneWidget);
    // Essentials is the initial category; its looks fill the grid.
    expect(find.text('Pop'), findsOneWidget);
    expect(find.text('Fresh'), findsNothing); // a Food look, not shown yet
  });

  testWidgets('switching category filters the grid', (tester) async {
    await tester.pumpWidget(_wrap(const TemplatesPage()));
    await tester.pump();
    await tester.tap(find.text('Food'));
    await tester.pump();
    expect(find.text('Fresh'), findsOneWidget);
    expect(find.text('Pop'), findsNothing);
  });

  testWidgets('My presets with no saved looks shows the empty hint', (tester) async {
    await tester.pumpWidget(_wrap(const TemplatesPage()));
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await tester.drag(find.byType(ListView), const Offset(-500, 0));
      await tester.pump();
    }
    await tester.tap(find.text('My presets'));
    await tester.pump();
    expect(find.text('Save a look in the editor to see it here'), findsOneWidget);
    expect(find.text('Pop'), findsNothing);
  });
}
