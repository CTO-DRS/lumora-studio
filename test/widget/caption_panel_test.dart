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

  test('Arabic and English caption strings exist', () {
    expect(AppLocalizationsAr().captionsGenerate, 'إنشاء الترجمة');
    expect(AppLocalizationsEn().captionsGenerate, 'Generate captions');
    expect(AppLocalizationsAr().captionsProgress(40), contains('40'));
  });
}
