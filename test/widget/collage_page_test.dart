import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/collage/presentation/collage_page.dart';
import 'package:lumora/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// A1: the Collage screen — empty state before any photos are picked (the
/// picker itself is platform UI; the arranged state is unit-covered by
/// collage_batch_test.dart and the painter by the screenshot harness).
Widget _wrap(Widget child) => ProviderScope(
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  ),
);

void main() {
  testWidgets('empty state: intro and pick button, no export actions yet', (tester) async {
    await tester.pumpWidget(_wrap(const CollagePage()));
    await tester.pump();
    expect(find.text('Collage'), findsOneWidget);
    expect(find.text('Pick up to 9 photos to arrange them in a layout with borders and a background.'), findsOneWidget);
    expect(find.text('Choose photos'), findsOneWidget);
    // Nothing to export or share before the first photo.
    expect(find.text('Export'), findsNothing);
    expect(find.byIcon(Icons.share_outlined), findsNothing);
  });
}
