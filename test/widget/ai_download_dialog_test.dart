import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumora/core/providers.dart';
import 'package:lumora/features/ai/data/model_manager.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:lumora/features/ai/presentation/model_download_dialog.dart';
import 'package:lumora/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

final _bytes = List<int>.generate(4096, (i) => i % 251);

final _spec = ModelSpec(
  id: 'dialog_test_model',
  task: AiTask.segmentation,
  displayName: 'Test model',
  url: 'https://example.com/m.onnx',
  sha256: sha256.convert(_bytes).toString(),
  sizeBytes: _bytes.length,
  license: 'MIT',
  source: '',
  inputNames: const ['x'],
  outputName: 'y',
);

/// Lets real file/HTTP futures started from the fake-async test zone finish.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('lumora_dialog'));
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<bool?> pumpAndAsk(WidgetTester tester, ModelManager manager, {required bool accept}) async {
    bool? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [modelManagerProvider.overrideWithValue(manager)],
        child: MaterialApp(
          localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () async => result = await ensureModelsDownloaded(context, ref, [_spec]),
                child: const Text('run'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('run'));
    await _settle(tester);
    expect(find.text('Download AI model?'), findsOneWidget);
    await tester.tap(find.text(accept ? 'Download' : 'Cancel'));
    await _settle(tester);
    return result;
  }

  testWidgets('asks before downloading and does nothing on cancel', (tester) async {
    var requests = 0;
    final manager = ModelManager(
      client: MockClient((_) async {
        requests++;
        return http.Response.bytes(_bytes, 200);
      }),
      baseDir: () async => tmp,
    );
    expect(await pumpAndAsk(tester, manager, accept: false), isFalse);
    expect(requests, 0);
  });

  testWidgets('downloads with a progress dialog, then reports ready', (tester) async {
    final manager = ModelManager(
      client: MockClient((_) async => http.Response.bytes(_bytes, 200)),
      baseDir: () async => tmp,
    );
    expect(await pumpAndAsk(tester, manager, accept: true), isTrue);
    expect(await tester.runAsync(() => manager.isInstalled(_spec)), isTrue);
    expect(find.text('Downloading AI model…'), findsNothing);
  });

  testWidgets('a failed download shows a readable error with retry', (tester) async {
    final manager = ModelManager(client: MockClient((_) async => http.Response('nope', 503)), baseDir: () async => tmp);
    await pumpAndAsk(tester, manager, accept: true);
    expect(find.textContaining("Couldn't download the AI model"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await _settle(tester);
    expect(find.text('Downloading AI model…'), findsNothing);
  });
}
