import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/core/app_info.dart';
import 'package:lumora/core/diagnostics/crash_log.dart';
import 'package:lumora/features/ai/data/model_manager.dart';
import 'package:lumora/features/ai/data/onnx_engine.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:lumora/features/ai/pipelines/ai_pipelines.dart';
import 'package:lumora/features/ai/presentation/ai_error_text.dart';
import 'package:lumora/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('session options', () {
    test('default is CPU only with KleidiAI disabled and bounded threads', () {
      final o = sessionOptionsFor(accelerated: false, android: true, apple: false, cores: 8);
      expect(o.providers, [OrtProvider.CPU]);
      expect(o.intraOpNumThreads, 4);
      expect(o.sessionConfigs, {'mlas.disable_kleidiai': '1'});
      expect(sessionOptionsFor(accelerated: false, android: true, apple: false, cores: 1).intraOpNumThreads, 1);
    });

    test('acceleration is opt-in and keeps a CPU fallback', () {
      final a = sessionOptionsFor(accelerated: true, android: true, apple: false, cores: 8);
      expect(a.providers, [OrtProvider.XNNPACK, OrtProvider.CPU]);
      expect(a.intraOpNumThreads, 1);
      final i = sessionOptionsFor(accelerated: true, android: false, apple: true, cores: 6);
      expect(i.providers, [OrtProvider.CORE_ML, OrtProvider.CPU]);
    });
  });

  group('engine guards', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('lumora_engine'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('a missing model fails with a Dart error before any native call', () async {
      final engine = OnnxInferenceEngine(ModelManager(baseDir: () async => tmp));
      await expectLater(
        engine.run(ModelRegistry.u2netp, {
          'input.1': (Float32List(3 * 320 * 320), [1, 3, 320, 320]),
        }),
        throwsA(isA<AiException>().having((e) => e.kind, 'kind', AiErrorKind.notDownloaded)),
      );
      // The queue keeps working after a failure.
      await engine.release();
    });

    test('every AI tool declares its models', () {
      for (final t in AiTool.values) {
        expect(aiToolModels(t), isNotEmpty, reason: t.name);
      }
      expect(aiToolModels(AiTool.eraser), [ModelRegistry.migan]);
      expect(aiToolModels(AiTool.cutOutPerson), [ModelRegistry.modnet]);
    });

    test('memory caps are in place', () {
      expect(InpaintPipeline.maxSide, lessThanOrEqualTo(4096));
      expect(UpscalePipeline.maxInputPixels * UpscalePipeline.scale * UpscalePipeline.scale, lessThan(13000000));
    });
  });

  group('error text', () {
    test('maps every kind to a localized sentence', () async {
      for (final locale in const [Locale('en'), Locale('ar')]) {
        final l = await AppLocalizations.delegate.load(locale);
        final texts = {for (final k in AiErrorKind.values) k: aiErrorText(l, AiException(k, detail: 'x'))};
        expect(texts.values.toSet().length, AiErrorKind.values.length, reason: locale.languageCode);
        expect(texts.values.any((t) => t.contains('AiException')), isFalse);
      }
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      expect(aiErrorText(en, ModelChecksumException('a', 'b')), en.aiErrChecksum);
      expect(aiErrorText(en, 'plain'), 'plain');
    });
  });

  group('crash log', () {
    late Directory tmp;
    setUp(() {
      tmp = Directory.systemTemp.createTempSync('lumora_log');
      CrashLog.instance.baseDir = () async => tmp;
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    test('records errors and breadcrumbs to a local file', () async {
      final log = CrashLog.instance;
      await log.init(installHooks: false);
      await log.clear();
      log
        ..breadcrumb('AI: run u2netp')
        ..record('Test', 'boom', StackTrace.current);
      final text = await log.read();
      expect(text, contains('AI: run u2netp'));
      expect(text, contains('ERROR Test'));
      expect(text, contains('boom'));
      expect(log.file!.path, startsWith(tmp.path));
      await log.clear();
      expect(await log.read(), isEmpty);
    });

    test('is trimmed when it grows too large', () async {
      final log = CrashLog.instance;
      await log.init(installHooks: false);
      final line = 'x' * 1000;
      for (var i = 0; i < 400; i++) {
        log.breadcrumb('$i $line');
      }
      expect(log.file!.lengthSync(), lessThan(CrashLog.maxBytes + 2000));
      expect(await log.read(), contains('399 '));
    });
  });

  test('app version matches pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version:\s*([^+\s]+)', multiLine: true).firstMatch(pubspec)!.group(1);
    expect(kAppVersion, version);
  });
}
