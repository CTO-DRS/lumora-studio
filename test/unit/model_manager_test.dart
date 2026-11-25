import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumora/features/ai/data/model_manager.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';

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
  mirrorUrl: mirror ?? '',
);

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('lumora_models'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('registry entries are well formed and mirrored', () {
    final ids = <String>{};
    for (final m in ModelRegistry.all) {
      expect(ids.add(m.id), isTrue);
      // Primary source: an upstream host (Hugging Face / GitHub) or, for
      // project-built artefacts (e.g. the int8 sky quantisation), the
      // project's own release directly.
      expect(
        m.url,
        anyOf(startsWith('https://huggingface.co/'), startsWith('https://github.com/')),
        reason: m.id,
      );
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(m.sha256), isTrue, reason: m.id);
      expect(m.sizeBytes, greaterThan(100000), reason: m.id);
      // Every model is mirrored on the project host with the same bytes:
      // models-1.3 for the v1.3 pack, models-1.4 for the v1.4 pack (and
      // project-built int8 files whose primary *is* the release).
      expect(
        m.mirrorUrl,
        anyOf('', 'https://github.com/CTO-DRS/lumora-studio/releases/download/models-1.3/${m.fileName}',
            'https://github.com/CTO-DRS/lumora-studio/releases/download/models-1.4/${m.fileName}'),
        reason: m.id,
      );
    }
    expect(ModelRegistry.forTask(AiTask.inpainting).length, 2);
    expect(ModelRegistry.byId('mobilesam_decoder_multi').sizeBytes, 16496559);
    expect(ModelRegistry.byId('mobilesam_decoder_multi').url, endsWith('sam_mask_decoder_multi.onnx'));
    // v1.4 models are registered with their verified contracts.
    expect(ModelRegistry.byId('yunet').sizeBytes, 232589);
    expect(ModelRegistry.byId('facemesh').sizeBytes, 4920995);
    expect(ModelRegistry.byId('skyseg_int8').sizeBytes, 44247982);
    expect(ModelRegistry.forTask(AiTask.faceDetection).length, 1);
    expect(ModelRegistry.forTask(AiTask.skySegmentation).length, 1);
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

  test('HTTP errors surface when there is no mirror', () async {
    final client = MockClient.streaming((req, _) async => http.StreamedResponse(const Stream.empty(), 404));
    final m = ModelManager(client: client, baseDir: () async => tmp);
    await expectLater(m.ensure(_spec([1, 2, 3])), throwsA(isA<HttpException>()));
  });

  test('falls back to the mirror when the primary URL fails', () async {
    final bytes = utf8.encode('fake-onnx-model' * 1000);
    final seen = <Uri>[];
    final client = MockClient.streaming((req, _) async {
      seen.add(req.url);
      if (req.url.host == 'example.com') return http.StreamedResponse(const Stream.empty(), 503);
      return http.StreamedResponse(Stream.value(bytes), 200, contentLength: bytes.length);
    });
    final m = ModelManager(client: client, baseDir: () async => tmp);
    final spec = _spec(bytes, mirror: 'https://mirror.example.org/m.onnx');
    final f = await m.ensure(spec);
    expect(f.readAsBytesSync(), bytes);
    expect(seen.map((u) => u.host), ['example.com', 'mirror.example.org']);
    expect(await m.verify(spec), isTrue);
  });

  test('falls back to the mirror after a checksum mismatch on the primary', () async {
    final good = utf8.encode('fake-onnx-model' * 1000);
    final tampered = utf8.encode('tampered-bytes!');
    final client = MockClient.streaming((req, _) async {
      final body = req.url.host == 'example.com' ? tampered : good;
      return http.StreamedResponse(Stream.value(body), 200, contentLength: body.length);
    });
    final m = ModelManager(client: client, baseDir: () async => tmp);
    final spec = _spec(good, mirror: 'https://mirror.example.org/m.onnx');
    final f = await m.ensure(spec);
    expect(f.readAsBytesSync(), good);
    expect(await m.isInstalled(spec), isTrue);
  });

  test('reports the primary error when the mirror fails too', () async {
    final client = MockClient.streaming(
      (req, _) async => http.StreamedResponse(const Stream.empty(), req.url.host == 'example.com' ? 404 : 500),
    );
    final m = ModelManager(client: client, baseDir: () async => tmp);
    await expectLater(
      m.ensure(_spec([1, 2, 3], mirror: 'https://mirror.example.org/m.onnx')),
      throwsA(isA<HttpException>()),
    );
    expect(Directory('${tmp.path}/models').listSync(), isEmpty);
  });
}
