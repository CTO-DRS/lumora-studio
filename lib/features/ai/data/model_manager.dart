import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ModelChecksumException implements Exception {
  ModelChecksumException(this.expected, this.actual);
  final String expected;
  final String actual;

  @override
  String toString() => 'Checksum mismatch: expected $expected, got $actual';
}

/// Progress of a model download (bytes).
class DownloadProgress {
  const DownloadProgress(this.received, this.total);
  final int received;
  final int total;
  double get fraction => total <= 0 ? 0 : received / total;
}

/// Downloads, verifies (SHA-256) and caches ONNX models in the app support
/// directory. Downloads are resumable-safe: data is streamed to a `.part`
/// file, hashed on the fly, and only renamed once the checksum matches.
class ModelManager {
  ModelManager({http.Client? client, Future<Directory> Function()? baseDir})
    : _client = client ?? http.Client(),
      _baseDir = baseDir ?? getApplicationSupportDirectory;

  final http.Client _client;
  final Future<Directory> Function() _baseDir;
  final Map<String, Future<File>> _inFlight = {};

  Future<Directory> modelsDir() async {
    final dir = Directory(p.join((await _baseDir()).path, 'models'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> fileFor(ModelSpec spec) async => File(p.join((await modelsDir()).path, spec.fileName));

  /// Bytes used by downloaded models (including partial downloads).
  Future<int> installedBytes() async {
    final dir = await modelsDir();
    if (!dir.existsSync()) return 0;
    var total = 0;
    await for (final e in dir.list()) {
      if (e is File) total += await e.length();
    }
    return total;
  }

  /// Deletes every downloaded model.
  Future<void> deleteAll() async {
    final dir = await modelsDir();
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  Future<bool> isInstalled(ModelSpec spec) async {
    final f = await fileFor(spec);
    return f.existsSync() && f.lengthSync() == spec.sizeBytes;
  }

  Future<void> delete(ModelSpec spec) async {
    final f = await fileFor(spec);
    if (f.existsSync()) await f.delete();
  }

  /// Returns the local model file, downloading it first when needed.
  Future<File> ensure(ModelSpec spec, {void Function(DownloadProgress)? onProgress}) {
    // Note: the callback must not return the removed future, otherwise
    // whenComplete would wait for itself.
    return _inFlight[spec.id] ??= _ensure(spec, onProgress).whenComplete(() {
      _inFlight.remove(spec.id);
    });
  }

  Future<File> _ensure(ModelSpec spec, void Function(DownloadProgress)? onProgress) async {
    final file = await fileFor(spec);
    if (await isInstalled(spec)) return file;

    final part = File('${file.path}.part');
    // Try the primary URL, then the project-hosted mirror (identical bytes,
    // same SHA-256). Only if every source fails does the error surface.
    final urls = [spec.url, if (spec.mirrorUrl.isNotEmpty) spec.mirrorUrl];
    assert(urls.isNotEmpty, 'a model always has at least a primary URL');
    for (final (i, url) in urls.indexed) {
      if (part.existsSync()) await part.delete();
      try {
        return await _download(spec, url, file, part, onProgress);
      } catch (e) {
        // A source that serves different bytes than advertised is just as
        // broken as one that cannot be reached – fall through to the mirror.
        if (i == urls.length - 1) rethrow;
      }
    }
    throw StateError('unreachable'); // urls is never empty
  }

  Future<File> _download(
    ModelSpec spec,
    String url,
    File file,
    File part,
    void Function(DownloadProgress)? onProgress,
  ) async {
    final request = http.Request('GET', Uri.parse(url));
    final response = await _client.send(request);
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode} for $url');
    }
    final total = response.contentLength ?? spec.sizeBytes;
    final digestSink = _DigestSink();
    final hasher = sha256.startChunkedConversion(digestSink);
    final sink = part.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        hasher.add(chunk);
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(DownloadProgress(received, total));
      }
    } finally {
      await sink.close();
    }
    hasher.close();
    final actual = digestSink.value.toString();
    if (actual != spec.sha256) {
      await part.delete();
      throw ModelChecksumException(spec.sha256, actual);
    }
    return part.rename(file.path);
  }

  /// Verifies an installed model against its checksum (slow for big files).
  Future<bool> verify(ModelSpec spec) async {
    final f = await fileFor(spec);
    if (!f.existsSync()) return false;
    final digest = await sha256.bind(f.openRead()).first;
    return digest.toString() == spec.sha256;
  }
}

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
