import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/batch/presentation/batch_page.dart';
import 'package:lumora/features/photo_editor/domain/presets.dart';
import 'package:lumora/features/photo_editor/engine/image_exporter.dart';
import 'package:lumora/features/photo_editor/presentation/photo_editor_controller.dart';
import 'package:lumora/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap() => const ProviderScope(
  child: MaterialApp(
    locale: Locale('en'),
    localizationsDelegates: [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
    supportedLocales: AppLocalizations.supportedLocales,
    home: BatchPage(),
  ),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap());
    await tester.pump();
  }

  testWidgets('empty state explains the flow and hides the start button', (tester) async {
    await pump(tester);
    expect(find.text('Batch edit'), findsOneWidget);
    expect(find.textContaining('Pick photos, choose a look'), findsOneWidget);
    expect(find.text('0 photos'), findsOneWidget);
    expect(find.text('Add photos'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('choosing a preset reveals the intensity slider', (tester) async {
    await pump(tester);
    expect(find.text('Intensity'), findsNothing);
    await tester.tap(find.byType(DropdownButton<String?>));
    await tester.pumpAndSettle();
    final preset = kBuiltInPresets.first;
    await tester.tap(find.text(preset.nameEn).last);
    await tester.pumpAndSettle();
    expect(find.text('Intensity'), findsOneWidget);
  });

  testWidgets('copied-edits switch unlocks once the clipboard holds edits', (tester) async {
    await pump(tester);
    var tile = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Use copied edits'));
    expect(tile.onChanged, isNull);
    expect(find.text('Copy edits in the photo editor first'), findsOneWidget);

    final container = ProviderScope.containerOf(tester.element(find.byType(BatchPage)));
    final ctrl = container.read(photoEditorControllerProvider.notifier)
      ..updateAdjustments((a) => a.copyWith(exposure: 1));
    await tester.runAsync(ctrl.copyEdits);
    await tester.pump();

    tile = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Use copied edits'));
    expect(tile.onChanged, isNotNull);
    expect(tile.value, isFalse);
    await tester.tap(find.text('Use copied edits'));
    await tester.pump();
    tile = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Use copied edits'));
    expect(tile.value, isTrue);
  });

  testWidgets('size chips and format segments track the current choice', (tester) async {
    await pump(tester);
    var chip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Original'));
    expect(chip.selected, isTrue);

    await tester.tap(find.text('Instagram 1:1'));
    await tester.pump();
    chip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Instagram 1:1'));
    expect(chip.selected, isTrue);
    chip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Original'));
    expect(chip.selected, isFalse);

    // The format override follows taps and defaults to the saved setting.
    var seg = tester.widget<SegmentedButton<ExportFormat>>(find.byType(SegmentedButton<ExportFormat>));
    expect(seg.selected, {ExportFormat.jpeg});
    await tester.tap(find.text('PNG'));
    await tester.pump();
    seg = tester.widget<SegmentedButton<ExportFormat>>(find.byType(SegmentedButton<ExportFormat>));
    expect(seg.selected, {ExportFormat.png});
  });

  testWidgets('auto enhance toggles without a preset', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Auto enhance'));
    await tester.pump();
    final tile = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Auto enhance'));
    expect(tile.value, isTrue);
  });
}
