import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/video_editor/domain/crop_math.dart';
import 'package:lumora/features/video_editor/presentation/widgets/video_crop_sheet.dart';
import 'package:lumora/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Opens the sheet, runs [act], and returns what the sheet popped
/// (null = cancelled).
Future<List<double>?> _run(
  WidgetTester tester,
  Future<void> Function() act, {
  List<double> initial = const [0.1, 0.1, 0.9, 0.9],
  double frameAspect = 16 / 9,
}) async {
  List<double>? result = const [-1];
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async =>
                result = await showVideoCropSheet(context, initial: initial, frameAspect: frameAspect),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await act();
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('Apply returns the initial rect untouched', (tester) async {
    final r = await _run(tester, () => tester.tap(find.text('Apply')));
    expect(r, [0.1, 0.1, 0.9, 0.9]);
  });

  testWidgets('Cancel pops nothing', (tester) async {
    final r = await _run(tester, () => tester.tap(find.text('Cancel')));
    expect(r, isNull);
  });

  testWidgets('Reset restores the full frame', (tester) async {
    final r = await _run(tester, () async {
      await tester.tap(find.text('Reset'));
      await tester.pump();
      await tester.tap(find.text('Apply'));
    });
    expect(r, [0, 0, 1, 1]);
  });

  testWidgets('picking 1:1 gives a centred square crop', (tester) async {
    final r = await _run(tester, () async {
      await tester.tap(find.text('1:1'));
      await tester.pump();
      await tester.tap(find.text('Apply'));
    });
    expect(r, isNotNull);
    expect(cropAspect(r!, 16 / 9), closeTo(1, 1e-6));
  });

  testWidgets('dragging a corner shrinks the crop box', (tester) async {
    final r = await _run(tester, () async {
      // Grab the top-left handle of the full-frame box and pull it in.
      final area = tester.getRect(find.byType(AspectRatio));
      final g = await tester.startGesture(area.topLeft + const Offset(2, 2));
      // Small steps: the handle is grabbed where the drag is recognised.
      for (var i = 0; i < 20; i++) {
        await g.moveBy(Offset(area.width * 0.0125, area.height * 0.0125));
      }
      await g.up();
      await tester.pump();
      await tester.tap(find.text('Apply'));
    }, initial: const [0, 0, 1, 1]);
    expect(r, isNotNull);
    expect(r![0], greaterThan(0.1));
    expect(r[1], greaterThan(0.1));
    expect(r[2], closeTo(1, 1e-9));
    expect(r[3], closeTo(1, 1e-9));
  });
}
