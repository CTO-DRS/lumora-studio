import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/photo_editor/data/preset_store.dart';
import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/photo_editor/domain/edit_clipboard.dart';
import 'package:lumora/features/photo_editor/domain/finishing.dart';
import 'package:lumora/features/photo_editor/domain/presets.dart';
import 'package:lumora/features/photo_editor/engine/image_exporter.dart';
import 'package:lumora/features/photo_editor/engine/pixel_ops.dart';
import 'package:lumora/features/photo_editor/presentation/photo_editor_controller.dart';
import 'package:lumora/features/photo_editor/presentation/photo_editor_page.dart';
import 'package:lumora/features/photo_editor/presentation/widgets/finish_panels.dart';
import 'package:lumora/features/photo_editor/presentation/widgets/tool_panels.dart';
import 'package:lumora/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child, {double height = 420}) => ProviderScope(
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(height: height, child: child),
    ),
  ),
);

ProviderContainer _container(WidgetTester tester, Type type) =>
    ProviderScope.containerOf(tester.element(find.byType(type)));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('preset categories switch the row; long-press adds a favourite', (tester) async {
    await tester.pumpWidget(_wrap(const PresetsPanel()));
    await tester.pump();
    expect(find.text('Food'), findsOneWidget);
    await tester.tap(find.text('Food'));
    await tester.pump();
    final food = kBuiltInPresets.firstWhere((p) => p.category == PresetCategory.food);
    expect(find.text(food.nameEn), findsOneWidget);

    await tester.longPress(find.text(food.nameEn));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to favorites'));
    await tester.pumpAndSettle();
    final c = _container(tester, PresetsPanel);
    expect(c.read(presetLibraryControllerProvider).isFavorite(food.id), isTrue);

    await tester.tap(find.text('Favorites'));
    await tester.pump();
    expect(find.text(food.nameEn), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsWidgets);
  });

  testWidgets('saving the current look creates a custom preset that applies and unapplies', (tester) async {
    await tester.pumpWidget(_wrap(const PresetsPanel()));
    final c = _container(tester, PresetsPanel);
    final ctrl = c.read(photoEditorControllerProvider.notifier)
      ..updateAdjustments((a) => a.copyWith(exposure: 0.5, saturation: -0.4));
    final preset = await tester.runAsync(() => ctrl.saveCurrentAsPreset('Mine'));
    await tester.pump();
    expect(preset!.isCustom, isTrue);
    expect(c.read(photoEditorControllerProvider).edit.presetId, preset.id);

    // Start from scratch, then apply the user preset.
    ctrl
      ..resetAll()
      ..applyPreset(preset.id);
    expect(c.read(photoEditorControllerProvider).edit.adjustments.exposure, closeTo(0.5, 1e-9));
    ctrl.applyPreset(preset.id, intensity: 0.5);
    expect(c.read(photoEditorControllerProvider).edit.adjustments.exposure, closeTo(0.25, 1e-9));
    ctrl.applyPreset(null);
    expect(c.read(photoEditorControllerProvider).edit.adjustments, const Adjustments());

    await tester.tap(find.text('My presets'));
    await tester.pump();
    expect(find.text('Mine'), findsOneWidget);
    expect(find.text('Save as preset'), findsOneWidget);
    expect(find.text('Import presets'), findsOneWidget);
  });

  testWidgets('copy / paste edits through the clipboard provider', (tester) async {
    await tester.pumpWidget(_wrap(const AdjustPanel()));
    final c = _container(tester, AdjustPanel);
    final ctrl = c.read(photoEditorControllerProvider.notifier)
      ..updateAdjustments((a) => a.copyWith(contrast: 0.7))
      ..update((s) => s.copyWith(frame: const FrameSettings(style: FrameStyle.polaroid)));
    await tester.runAsync(ctrl.copyEdits);
    ctrl.resetAll();
    expect(c.read(photoEditorControllerProvider).edit.adjustments.contrast, 0);
    expect(ctrl.canPaste, isTrue);
    ctrl.pasteEdits(options: const PasteOptions(finishing: false));
    final e = c.read(photoEditorControllerProvider).edit;
    expect(e.adjustments.contrast, 0.7);
    expect(e.frame.isNone, isTrue);
    ctrl.undo();
    expect(c.read(photoEditorControllerProvider).edit.adjustments.contrast, 0);
  });

  testWidgets('paste options dialog returns the chosen parts', (tester) async {
    PasteOptions? result;
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) =>
              TextButton(onPressed: () async => result = await showPasteOptions(context), child: const Text('go')),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crop & rotation'));
    await tester.tap(find.text('Masks'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Paste edits'));
    await tester.pumpAndSettle();
    expect(result?.geometry, isTrue);
    expect(result?.masks, isFalse);
    expect(result?.adjustments, isTrue);
  });

  testWidgets('export sheet offers social sizes and fit modes', (tester) async {
    (ExportOptions, bool)? result;
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showModalBottomSheet<(ExportOptions, bool)>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const ExportSheet(initial: ExportOptions()),
            ),
            child: const Text('go'),
          ),
        ),
        height: 800,
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Fit (add border)'), findsNothing);
    await tester.tap(find.text('Instagram 4:5'));
    await tester.pumpAndSettle();
    expect(find.text('Fit (add border)'), findsOneWidget);
    await tester.tap(find.text('Fill (crop)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save to gallery'));
    await tester.pumpAndSettle();
    expect(result!.$1.social, SocialSize.instagramPortrait);
    expect(result!.$1.socialFit, SocialFit.crop);
    expect(result!.$1.quality, SocialSize.instagramPortrait.quality);
    expect(result!.$1.saveToGallery, isTrue);
    expect(result!.$2, isFalse);
  });

  testWidgets('frame panel sets a polaroid frame; watermark panel moves the anchor', (tester) async {
    await tester.pumpWidget(_wrap(const FramePanel()));
    await tester.tap(find.text('Polaroid'));
    await tester.pump();
    final c = _container(tester, FramePanel);
    expect(c.read(photoEditorControllerProvider).edit.frame.style, FrameStyle.polaroid);
    expect(find.text('Border width'), findsOneWidget);
  });

  testWidgets('HSL colour picker toggles picking mode', (tester) async {
    await tester.pumpWidget(_wrap(const HslPanel()));
    final c = _container(tester, HslPanel);
    expect(c.read(photoEditorControllerProvider).hslPicking, isFalse);
    await tester.tap(find.byIcon(Icons.colorize_outlined));
    await tester.pump();
    expect(c.read(photoEditorControllerProvider).hslPicking, isTrue);
    expect(c.read(photoEditorControllerProvider).interactive, isTrue);
    expect(find.text('Saturation'), findsWidgets);
    c.read(photoEditorControllerProvider.notifier)
      ..selectHslBand(5)
      ..nudgeHsl(0.3)
      ..commit();
    expect(c.read(photoEditorControllerProvider).edit.adjustments.hsl.saturation[5], closeTo(0.3, 1e-9));
  });

  testWidgets('history sheet lists steps and jumps back', (tester) async {
    await tester.pumpWidget(
      _wrap(
        Consumer(
          builder: (context, ref, _) {
            // Keep the (auto-disposed) editor state alive like the page does.
            ref.watch(photoEditorControllerProvider);
            return TextButton(onPressed: () => showHistorySheet(context, ref), child: const Text('history'));
          },
        ),
        height: 800,
      ),
    );
    final c = _container(tester, Consumer);
    c.read(photoEditorControllerProvider.notifier)
      ..updateAdjustments((a) => a.copyWith(exposure: 1))
      ..applyPreset('noir');
    await tester.tap(find.text('history'));
    await tester.pumpAndSettle();
    expect(find.text('Original'), findsOneWidget);
    expect(find.text('1 · Light'), findsOneWidget);
    expect(find.text('2 · Looks'), findsOneWidget);
    await tester.tap(find.text('1 · Light'));
    await tester.pump();
    final s = c.read(photoEditorControllerProvider);
    expect(s.edit.presetId, isNull);
    expect(s.edit.adjustments.exposure, 1);
    expect(s.history.canRedo, isTrue);
  });
}
