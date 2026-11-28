import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/core/providers.dart';
import 'package:lumora/features/home/presentation/projects_page.dart';
import 'package:lumora/features/projects/data/project_repository.dart';
import 'package:lumora/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A1: the Projects tab with a faked project stream (a real drift database
/// hangs the test harness).
ProjectSummary _p(String name, ProjectKind kind) => ProjectSummary(
  id: name,
  name: name,
  kind: kind,
  sourcePath: '/x/${name.length}.jpg',
  updatedAt: DateTime(2026, 11),
);

Widget _wrap(List<ProjectSummary> items) => ProviderScope(
  overrides: [recentProjectsProvider.overrideWith((ref) => Stream.value(items))],
  child: const MaterialApp(
    locale: Locale('en'),
    localizationsDelegates: [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
    supportedLocales: AppLocalizations.supportedLocales,
    home: ProjectsPage(),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('empty list shows the empty state', (tester) async {
    await tester.pumpWidget(_wrap(const []));
    await tester.pump();
    await tester.pump();
    expect(find.text('Nothing here yet'), findsOneWidget);
  });

  testWidgets('lists projects and search filters them', (tester) async {
    await tester.pumpWidget(_wrap([_p('Beach', ProjectKind.photo), _p('Birthday clip', ProjectKind.video)]));
    await tester.pump();
    await tester.pump();
    expect(find.text('Beach'), findsOneWidget);
    expect(find.text('Birthday clip'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'beach');
    await tester.pump();
    expect(find.text('Beach'), findsOneWidget);
    expect(find.text('Birthday clip'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('No projects match your search'), findsOneWidget);
  });
}
