import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/photo_editor/presentation/photo_editor_controller.dart';
import 'package:lumora/features/smart_edit/domain/edit_ops.dart';
import 'package:lumora/features/smart_edit/presentation/smart_actions.dart';
import 'package:lumora/features/smart_edit/presentation/smart_panel.dart';
import 'package:lumora/l10n/app_localizations.dart';
import 'package:lumora/l10n/app_localizations_en.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child, {Locale locale = const Locale('en')}) => ProviderScope(
  child: MaterialApp(
    locale: locale,
    localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SizedBox(height: 360, child: child)),
  ),
);

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(SmartPanel)));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a typed English command edits the photo in one undo step', (tester) async {
    await tester.pumpWidget(_wrap(const SmartPanel()));
    await tester.pump();
    expect(find.text('Understood on your device — nothing is sent anywhere.'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('smart-command')), 'warmer, more contrast and black and white');
    await tester.tap(find.byKey(const ValueKey('smart-send')));
    await tester.pumpAndSettle();

    final c = _container(tester);
    final edit = c.read(photoEditorControllerProvider).edit;
    expect(edit.presetId, 'mono');
    expect(edit.adjustments.temperature, closeTo(0.2, 1e-9));
    expect(edit.adjustments.contrast, closeTo(0.2 + 0.1, 1e-9)); // +0.2 and Mono's own +0.1
    expect(find.textContaining('Done:'), findsOneWidget);

    c.read(photoEditorControllerProvider.notifier).undo();
    expect(c.read(photoEditorControllerProvider).edit.adjustments, const Adjustments());
    expect(c.read(photoEditorControllerProvider).edit.presetId, isNull);
  });

  testWidgets('Arabic commands work in the Arabic UI', (tester) async {
    await tester.pumpWidget(_wrap(const SmartPanel(), locale: const Locale('ar')));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('smart-command')), 'اجعلها أدفأ وزد السطوع قليلاً');
    await tester.tap(find.byKey(const ValueKey('smart-send')));
    await tester.pumpAndSettle();
    final a = _container(tester).read(photoEditorControllerProvider).edit.adjustments;
    expect(a.temperature, closeTo(0.2, 1e-9));
    expect(a.exposure, closeTo(0.175, 1e-9));
    expect(find.textContaining('تم:'), findsOneWidget);
  });

  testWidgets('example chips run their command; nonsense is reported', (tester) async {
    await tester.pumpWidget(_wrap(const SmartPanel()));
    await tester.pump();
    await tester.tap(find.text('more contrast'));
    await tester.pumpAndSettle();
    expect(_container(tester).read(photoEditorControllerProvider).edit.adjustments.contrast, closeTo(0.2, 1e-9));

    await tester.enterText(find.byKey(const ValueKey('smart-command')), 'qwerty zxcv');
    await tester.tap(find.byKey(const ValueKey('smart-send')));
    await tester.pumpAndSettle();
    expect(find.textContaining("Didn't understand"), findsOneWidget);
  });

  testWidgets('next commands appear after an edit and run on tap', (tester) async {
    await tester.pumpWidget(_wrap(const SmartPanel()));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('smart-command')), 'brighter');
    await tester.tap(find.byKey(const ValueKey('smart-send')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('smart-next')), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    await tester.tap(
      find.descendant(of: find.byKey(const ValueKey('smart-next')), matching: find.text('more contrast')),
    );
    await tester.pumpAndSettle();
    expect(_container(tester).read(photoEditorControllerProvider).edit.adjustments.contrast, closeTo(0.2, 1e-9));
  });

  testWidgets('commands land in the history; long press stars them', (tester) async {
    await tester.pumpWidget(_wrap(const SmartPanel()));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('smart-command')), 'warmer');
    await tester.tap(find.byKey(const ValueKey('smart-send')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('smart-history')), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);

    await tester.longPress(
      find.descendant(of: find.byKey(const ValueKey('smart-history')), matching: find.text('warmer')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('smart-favourites')), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);

    // The starred chip runs too.
    await tester.tap(
      find.descendant(of: find.byKey(const ValueKey('smart-favourites')), matching: find.text('warmer')),
    );
    await tester.pumpAndSettle();
    expect(_container(tester).read(photoEditorControllerProvider).edit.adjustments.temperature, closeTo(0.4, 1e-9));
  });

  testWidgets('rotate, flip and reset are instant', (tester) async {
    await tester.pumpWidget(_wrap(const SmartPanel()));
    final ctrl = _container(tester).read(photoEditorControllerProvider.notifier);
    final pending = await ctrl.applySmartPlan(
      const SmartEditPlan(
        ops: [
          ActionOp(SmartAction.rotateRight),
          ActionOp(SmartAction.flipHorizontal),
          ActionOp(SmartAction.removeBackground),
        ],
      ),
    );
    final g = _container(tester).read(photoEditorControllerProvider).edit.geometry;
    expect(g.quarterTurns, 1);
    expect(g.flipHorizontal, isTrue);
    expect(pending, [SmartAction.removeBackground]);
    await ctrl.applySmartPlan(const SmartEditPlan(ops: [ActionOp(SmartAction.reset)]));
    expect(_container(tester).read(photoEditorControllerProvider).edit.geometry.quarterTurns, 0);
  });

  test('plan summaries are readable', () {
    final l = AppLocalizationsEn();
    const plan = SmartEditPlan(
      ops: [
        AdjustOp(AdjustmentParam.exposure, -0.35),
        AdjustOp(AdjustmentParam.temperature, 0.2),
        AdjustOp(AdjustmentParam.vignette, -0.3, absolute: true),
        ActionOp(SmartAction.removeBackground),
      ],
    );
    expect(
      describePlan(l, 'en', plan, (_) => null),
      'Exposure −0.35 EV · Temperature +20 · Vignette = −30 · Remove background',
    );
    for (final a in SmartAction.values) {
      expect(smartActionLabel(l, a), isNotEmpty);
    }
  });
}
