import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/video_editor/domain/caption_timeline.dart';
import 'package:lumora/features/video_editor/domain/video_project.dart';
import 'package:lumora/features/video_editor/presentation/video_editor_controller.dart';
import 'package:lumora/features/video_editor/presentation/widgets/caption_panel.dart';
import 'package:lumora/l10n/app_localizations.dart';
import 'package:lumora/l10n/app_localizations_ar.dart';
import 'package:lumora/l10n/app_localizations_en.dart';
import 'package:material_ui/material_ui.dart';

Widget _app(ProviderContainer c) => UncontrolledProviderScope(
  container: c,
  child: const MaterialApp(
    locale: Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: CaptionPanel()),
  ),
);

void main() {
  testWidgets('empty state offers generate; cues list, delete and remove all work', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(_app(c));
    expect(find.text('Generate captions'), findsOneWidget);

    c
        .read(videoEditorControllerProvider.notifier)
        .update(
          (p) => p.copyWith(
            texts: const [
              VideoText(id: 'cap_c1_0', text: 'hello', startMs: 1000, endMs: 2000),
              VideoText(id: 'cap_c1_1', text: 'مرحبا', startMs: 3000, endMs: 4000),
              VideoText(id: 'free', text: 'keep me'),
            ],
          ),
        );
    await tester.pump();
    expect(find.text('hello'), findsOneWidget);
    expect(find.text('مرحبا'), findsOneWidget);
    expect(find.text('keep me'), findsNothing);
    expect(find.text('Regenerate'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pump();
    expect(find.text('hello'), findsNothing);

    await tester.tap(find.text('Remove captions'));
    await tester.pump();
    final texts = c.read(videoEditorControllerProvider).project.texts;
    expect(texts.where(isCaptionText), isEmpty);
    expect(texts.map((t) => t.id), ['free']);
  });

  testWidgets('cue menu retimes, splits and merges; style row restyles all captions', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(_app(c));
    c
        .read(videoEditorControllerProvider.notifier)
        .update(
          (p) => p.copyWith(
            texts: const [
              VideoText(id: 'cap_c1_0', text: 'one two', startMs: 1000, endMs: 2000, backgroundColor: 0xAA000000),
              VideoText(id: 'cap_c1_1', text: 'three', startMs: 3000, endMs: 4000, backgroundColor: 0xAA000000),
            ],
          ),
        );
    await tester.pump();

    // Retime: +250 ms moves both ends, duration kept.
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('250 ms later'));
    await tester.pump();
    var t = c.read(videoEditorControllerProvider).project.texts.firstWhere((x) => x.id == 'cap_c1_0');
    expect(t.startMs, 1250);
    expect(t.endMs, 2250);

    // Split at middle breaks "one two" into two cues.
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Split at middle'));
    await tester.pump();
    expect(find.text('one'), findsOneWidget);
    expect(find.text('two'), findsOneWidget);

    // Merge joins the split halves back.
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Merge with next'));
    await tester.pump();
    t = c.read(videoEditorControllerProvider).project.texts.firstWhere((x) => x.id == 'cap_c1_0');
    expect(t.text, 'one two');

    // Style row: size chip restyles every caption; the background switch clears it.
    await tester.tap(find.text('L'));
    await tester.pump();
    final texts = c.read(videoEditorControllerProvider).project.texts;
    expect(texts.where(isCaptionText).every((x) => (x.fontSize - 0.06).abs() < 1e-6), isTrue);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    final cleared = c.read(videoEditorControllerProvider).project.texts;
    expect(cleared.where(isCaptionText).every((x) => x.backgroundColor == null), isTrue);
  });

  test('Arabic and English caption strings exist', () {
    expect(AppLocalizationsAr().captionsGenerate, 'إنشاء الترجمة');
    expect(AppLocalizationsEn().captionsGenerate, 'Generate captions');
    expect(AppLocalizationsAr().captionsProgress(40), contains('40'));
  });
}
