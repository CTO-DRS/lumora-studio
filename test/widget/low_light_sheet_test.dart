import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/photo_editor/engine/low_light.dart';
import 'package:lumora/features/photo_editor/presentation/widgets/tool_panels.dart';
import 'package:lumora/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('low-light sheet shows three sliders and applies default params', (tester) async {
    LowLightParams? applied;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showLowLightSheet(context, (p) => applied = p),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Lift and denoise'), findsOneWidget);
    expect(find.text('Preserve detail'), findsOneWidget);
    expect(find.text('Colour noise'), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(3));

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(applied, isNotNull);
    expect(applied!.strength, closeTo(0.7, 1e-9));
    expect(applied!.preserveDetail, closeTo(0.5, 1e-9));
    expect(applied!.colourNoise, closeTo(0.6, 1e-9));
    expect(find.byType(Slider), findsNothing);
  });
}
