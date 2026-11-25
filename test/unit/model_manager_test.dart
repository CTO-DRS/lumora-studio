import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumora/features/ai/data/model_manager.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:path/path.dart' as p;

ModelSpec _spec(List<int> bytes, {String? sha, String? mirror}) => ModelSpec(
  id: 'test_model',
  task: AiTask.segmentation,
  displayName: 'test',
  url: 'https://example.com/m.onnx',
  sha256: sha ?? sha256.convert(bytes).toString(),
  sizeBytes: bytes.length,
  license: 'MIT',
  source: '',
  inputNames: const ['x'],
  outputName: 'y',
  mirrorUrl: mirror,
);

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('lumora_models'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('registry entries are well formed', () {
    final ids = <String>{};
    for (final m in ModelRegistry.all) {
      expect(ids.add(m.id), isTrue);
      // Every model is pinned: Hugging Face URLs by revision (the v1.3
      // models), the scene classifier by an immutable ONNX model zoo commit,
      // and the in-house int8 sky quantisation by its release asset. All
      // carry a recorded SHA-256 checked after download.
      expect(
        m.url,
        anyOf(
          startsWith('https://huggingface.co/'),
          startsWith('https://github.com/onnx/models/raw/'),
          startsWith('https://github.com/CTO-DRS/lumora-studio/releases/download/'),
        ),
        reason: m.id,
      );
      expect(m.mirrorUrl, startsWith('https://github.com/CTO-DRS/lumora-studio/releases/download/'), reason: m.id);
      expect(m.mirrorUrl, endsWith('${m.id}.onnx'), reason: m.id);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(m.sha256), isTrue, reason: m.id);
      // Smallest shipped model is YuNet (232 KB); a stub would be far below.
      expect(m.sizeBytes, greaterThan(100000));
    }
    expect(ModelRegistry.forTask(AiTask.inpainting).length, 2);
    expect(ModelRegistry.forTask(AiTask.interactiveSegmentation).length, 3);
    expect(ModelRegistry.forTask(AiTask.faceDetection).length, 1);
    expect(ModelRegistry.forTask(AiTask.faceLandmarks).length, 1);
    expect(ModelRegistry.forTask(AiTask.skySegmentation).length, 1);
    // v1.4 budget (ROADMAP §5): models added in this phase stay ≤ 50 MB
    // (older models such as LaMa are exempt).
    const v14Tasks = [AiTask.faceDetection, AiTask.faceLandmarks, AiTask.sceneClassification, AiTask.skySegmentation];
    final v14Models = [for (final t in v14Tasks) ...ModelRegistry.forTask(t)];
    expect(
      v14Models.every((m) => m.sizeBytes <= 50 * 1024 * 1024),
      isTrue,
      reason: v14Models.map((m) => '${m.id}: ${m.sizeBytes}').join(', '),
    );
  });

  test('downloads, verifies and caches', () async {
    final bytes = utf8.encode('fake-onnx-model' * 1000);
    var calls = 0;
    final client = MockClient.streaming((req, _) async {
      calls++;
      return http.StreamedResponse(Stream.value(bytes), 200, contentLength: bytes.length);
    });
    final m = ModelManager(client: client, baseDir: () async => tmp);
    final spec = _spec(bytes);
    final progress = <double>[];
    final f = await m.ensure(spec, onProgress: (p) => progress.add(p.fraction));
    expect(f.readAsBytesSync(), bytes);
    expect(progress.last, 1);
    expect(await m.isInstalled(spec), isTrue);
    expect(await m.verify(spec), isTrue);
    await m.ensure(spec);
    expect(calls, 1, reason: 'cached file must be reused');
    await m.delete(spec);
    expect(await m.isInstalled(spec), isFalse);
  });

  test('rejects checksum mismatch and leaves no file', () async {
    final bytes = utf8.encode('tampered');
    final client = MockClient.streaming((req, _) async => http.StreamedResponse(Stream.value(bytes), 200));
    final m = ModelManager(client: client, baseDir: () async => tmp);
    final spec = _spec(bytes, sha: '0' * 64);
    await expectLater(m.ensure(spec), throwsA(isA<ModelChecksumException>()));
    expect(await m.isInstalled(spec), isFalse);
    expect(Directory('${tmp.path}/models').listSync(), isEmpty);
  });

  test('HTTP errors surface', () async {
    final client = MockClient.streaming((req, _) async => http.StreamedResponse(const Stream.empty(), 404));
    final m = ModelManager(client: client, baseDir: () async => tmp);
    await expectLater(m.ensure(_spec([1, 2, 3])), throwsA(isA<HttpException>()));
  });

  group('mirror fallback', () {
    test('falls back to the mirror when the primary host fails', () async {
      final bytes = utf8.encode('mirror-copy' * 500);
      final requested = <String>[];
      final client = MockClient.streaming((req, _) async {
        requested.add(req.url.toString());
        if (req.url.host == 'example.com') return http.StreamedResponse(const Stream.empty(), 503);
        return http.StreamedResponse(Stream.value(bytes), 200, contentLength: bytes.length);
      });
      final m = ModelManager(client: client, baseDir: () async => tmp);
      final f = await m.ensure(_spec(bytes, mirror: 'https://mirror.example/m.onnx'));
      expect(f.readAsBytesSync(), bytes);
      expect(requested, hasLength(2));
      expect(requested.last, 'https://mirror.example/m.onnx');
    });

    test('falls back to the mirror on a checksum mismatch', () async {
      final good = utf8.encode('good-model-bytes' * 100);
      final bad = utf8.encode('tampered-bytes' * 100);
      final client = MockClient.streaming((req, _) async {
        final body = req.url.host == 'example.com' ? bad : good;
        return http.StreamedResponse(Stream.value(body), 200, contentLength: body.length);
      });
      final m = ModelManager(client: client, baseDir: () async => tmp);
      final spec = _spec(good, mirror: 'https://mirror.example/m.onnx');
      final f = await m.ensure(spec);
      expect(f.readAsBytesSync(), good);
      expect(await m.isInstalled(spec), isTrue);
      expect(Directory('${tmp.path}/models').listSync().map((e) => p.basename(e.path)), ['test_model.onnx']);
    });

    test('both sources failing reports the last error', () async {
      final client = MockClient.streaming((req, _) async => http.StreamedResponse(const Stream.empty(), 500));
      final m = ModelManager(client: client, baseDir: () async => tmp);
      await expectLater(m.ensure(_spec([1], mirror: 'https://mirror.example/m.onnx')), throwsA(isA<HttpException>()));
      expect(Directory('${tmp.path}/models').listSync(), isEmpty);
    });

    test('checksum mismatch on both sources throws', () async {
      final bytes = utf8.encode('garbage');
      final client = MockClient.streaming((req, _) async {
        return http.StreamedResponse(Stream.value(bytes), 200);
      });
      final m = ModelManager(client: client, baseDir: () async => tmp);
      await expectLater(
        m.ensure(_spec(bytes, sha: 'f' * 64, mirror: 'https://mirror.example/m.onnx')),
        throwsA(isA<ModelChecksumException>()),
      );
    });
  });
}
