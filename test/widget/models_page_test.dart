import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumora/core/providers.dart';
import 'package:lumora/features/ai/data/model_manager.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:lumora/features/ai/presentation/models_page.dart';
import 'package:lumora/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _pump(WidgetTester tester, ModelManager manager) async {
  tester.view.physicalSize = const Size(900, 8000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [modelManagerProvider.overrideWithValue(manager)],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
        supportedLocales: AppLocalizations.supportedLocales,
        home: ModelsPage(),
      ),
    ),
  );
  await _settle(tester);
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('lumora_models_page'));
  tearDown(() => tmp.deleteSync(recursive: true));

  testWidgets('nothing installed: every model offers Download and shows its licence', (tester) async {
    await _pump(tester, ModelManager(baseDir: () async => tmp));
    expect(find.text('Installed'), findsNothing);
    expect(find.text('Download'), findsNWidgets(ModelRegistry.all.length));
    final first = ModelRegistry.all.first;
    expect(find.text(first.displayName), findsWidgets);
    expect(find.textContaining(first.license), findsWidgets);
  });

  testWidgets('an installed model shows Installed, and Delete removes the file', (tester) async {
    final manager = ModelManager(baseDir: () async => tmp);
    final spec = ModelRegistry.all.first;
    final file = await tester.runAsync(() => manager.fileFor(spec));
    file!.parent.createSync(recursive: true);
    final raf = file.openSync(mode: FileMode.write)..truncateSync(spec.sizeBytes);
    raf.closeSync();

    await _pump(tester, manager);
    expect(find.text('Installed'), findsOneWidget);
    expect(find.text('Download'), findsNWidgets(ModelRegistry.all.length - 1));

    await tester.tap(find.text('Delete'));
    await _settle(tester);
    expect(file.existsSync(), isFalse);
    expect(find.text('Installed'), findsNothing);
    expect(find.text('Download'), findsNWidgets(ModelRegistry.all.length));
  });

  testWidgets('a failed download shows an error and leaves the model not installed', (tester) async {
    final manager = ModelManager(client: MockClient((_) async => http.Response('nope', 503)), baseDir: () async => tmp);
    await _pump(tester, manager);
    await tester.tap(find.text('Download').first);
    await _settle(tester);
    expect(find.textContaining('Something went wrong'), findsOneWidget);
    expect(find.text('Installed'), findsNothing);
    expect(find.text('Download'), findsNWidgets(ModelRegistry.all.length));
  });
}
