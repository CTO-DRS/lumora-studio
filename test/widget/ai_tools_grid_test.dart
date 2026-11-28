import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/core/providers.dart';
import 'package:lumora/features/ai/data/model_manager.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:lumora/features/ai/presentation/ai_tools_sheet.dart';
import 'package:lumora/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

Widget _app({required Widget home, required ModelManager manager}) => ProviderScope(
  overrides: [modelManagerProvider.overrideWithValue(manager)],
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

AiToolCard _card(String label, VoidCallback onTap, {AiTool? tool}) =>
    AiToolCard(icon: Icons.auto_fix_high, color: const Color(0xFF3366FF), label: label, onTap: onTap, tool: tool);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('lumora_ai_grid'));
  tearDown(() => tmp.deleteSync(recursive: true));

  testWidgets('tapping a plain card runs its action; disabled cards do not', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        home: Scaffold(
          body: Column(
            children: [
              AiToolsGrid(shrinkWrap: true, cards: [_card('Retouch', () => taps++)]),
              AiToolsGrid(shrinkWrap: true, enabled: false, cards: [_card('Locked', () => taps += 10)]),
            ],
          ),
        ),
        manager: ModelManager(baseDir: () async => tmp),
      ),
    );
    await _settle(tester);
    await tester.tap(find.text('Retouch'));
    await tester.tap(find.text('Locked'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('showAiToolsSheet pops first, then runs the chosen action', (tester) async {
    var ran = false;
    await tester.pumpWidget(
      _app(
        manager: ModelManager(baseDir: () async => tmp),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAiToolsSheet(context, [_card('Erase', () => ran = true), _card('Upscale', () {})]),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await _settle(tester);
    expect(find.text('AI tools'), findsOneWidget);
    expect(find.text('Erase'), findsOneWidget);

    await tester.tap(find.text('Erase'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(ran, isTrue);
  });

  testWidgets('a card backed by missing models shows the download size', (tester) async {
    await tester.pumpWidget(
      _app(
        manager: ModelManager(baseDir: () async => tmp),
        home: Scaffold(
          body: AiToolsGrid(
            shrinkWrap: true,
            cards: [
              _card('Remove background', () {}, tool: AiTool.removeBackground),
              _card('Plain', () {}),
            ],
          ),
        ),
      ),
    );
    await _settle(tester);
    // u2netp (4,574,861 bytes) formats to "4.4 MB" with a download arrow.
    expect(find.text('4.4 MB'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
  });

  testWidgets('an installed model removes the size and progress ring', (tester) async {
    final manager = ModelManager(baseDir: () async => tmp);
    const spec = ModelRegistry.u2netp;
    final file = await tester.runAsync(() => manager.fileFor(spec));
    file!.parent.createSync(recursive: true);
    final raf = file.openSync(mode: FileMode.write)..truncateSync(spec.sizeBytes);
    raf.closeSync();

    await tester.pumpWidget(
      _app(
        manager: manager,
        home: Scaffold(
          body: AiToolsGrid(
            shrinkWrap: true,
            cards: [_card('Remove background', () {}, tool: AiTool.removeBackground)],
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(find.text('4.4 MB'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
