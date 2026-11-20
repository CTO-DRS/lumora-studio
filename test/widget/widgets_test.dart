import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/core/widgets/labeled_slider.dart';
import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/photo_editor/domain/presets.dart';
import 'package:lumora/features/photo_editor/presentation/photo_editor_controller.dart';
import 'package:lumora/features/photo_editor/presentation/widgets/curves_editor.dart';
import 'package:lumora/features/photo_editor/presentation/widgets/tool_panels.dart';
import 'package:lumora/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

Widget _wrap(Widget child, {Locale locale = const Locale('en')}) => ProviderScope(
  child: MaterialApp(
    locale: locale,
    localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SizedBox(height: 400, child: child)),
  ),
);

void main() {
  testWidgets('LabeledSlider shows signed value and resets on double tap', (tester) async {
    var value = 0.42;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => LabeledSlider(
              label: 'Contrast',
              value: value,
              min: -1,
              max: 1,
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      ),
    );
    expect(find.text('+42'), findsOneWidget);
    await tester.tap(find.text('Contrast'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Contrast'));
    await tester.pumpAndSettle();
    expect(value, 0);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('Presets panel lists looks and applies one (with undo)', (tester) async {
    await tester.pumpWidget(_wrap(const PresetsPanel()));
    expect(find.text('None'), findsOneWidget);
    expect(find.text(kBuiltInPresets.first.nameEn), findsOneWidget);
    await tester.tap(find.text(kBuiltInPresets.first.nameEn));
    await tester.pump();
    final container = ProviderScope.containerOf(tester.element(find.byType(PresetsPanel)));
    final state = container.read(photoEditorControllerProvider);
    expect(state.edit.presetId, kBuiltInPresets.first.id);
    expect(state.edit.adjustments.isNeutral, isFalse);
    // Intensity slider appears once a preset is active.
    expect(find.text('Intensity'), findsOneWidget);
    container.read(photoEditorControllerProvider.notifier).undo();
    expect(container.read(photoEditorControllerProvider).edit.adjustments, const Adjustments());
  });

  testWidgets('Switching presets does not stack them', (tester) async {
    await tester.pumpWidget(_wrap(const PresetsPanel()));
    final container = ProviderScope.containerOf(tester.element(find.byType(PresetsPanel)));
    final ctrl = container.read(photoEditorControllerProvider.notifier)
      ..applyPreset('bright')
      ..applyPreset('warm');
    final a = container.read(photoEditorControllerProvider).edit.adjustments;
    expect(a.exposure, closeTo(0, 1e-9));
    expect(a.temperature, closeTo(0.3, 1e-9));
    ctrl.applyPreset(null);
    expect(container.read(photoEditorControllerProvider).edit.adjustments.temperature, closeTo(0, 1e-9));
  });

  testWidgets('Adjust panel is localized in Arabic (RTL)', (tester) async {
    await tester.pumpWidget(_wrap(const AdjustPanel(), locale: const Locale('ar')));
    await tester.pumpAndSettle();
    expect(find.text('التعريض'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('التعريض'))), TextDirection.rtl);
  });

  testWidgets('Curves editor adds a point on drag', (tester) async {
    var pts = kIdentityCurve;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: StatefulBuilder(
              builder: (c, setState) => CurvesEditor(
                points: pts,
                color: Colors.white,
                onChanged: (p) => setState(() => pts = p),
                onChangeEnd: () {},
              ),
            ),
          ),
        ),
      ),
    );
    final box = tester.getRect(find.byType(CurvesEditor));
    await tester.dragFrom(box.center, const Offset(0, -30));
    await tester.pumpAndSettle();
    expect(pts.length, 3);
    expect(pts[1].y, greaterThan(pts[1].x));
  });
}
