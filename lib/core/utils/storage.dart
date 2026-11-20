import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Total size in bytes of every file under [dir].
Future<int> directorySize(Directory dir) async {
  if (!dir.existsSync()) return 0;
  var total = 0;
  await for (final e in dir.list(recursive: true, followLinks: false)) {
    if (e is File) total += await e.length();
  }
  return total;
}

/// Human readable size, e.g. `12.3 MB`.
String formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
}

/// Temporary working files (video thumbnails, export intermediates, shared
/// files). Safe to delete: nothing a project depends on lives here.
Future<Directory> cacheDirectory() async => Directory(p.join((await getTemporaryDirectory()).path, 'lumora'));

Future<int> cacheSize() async => directorySize(await cacheDirectory());

/// Deletes temporary files and returns how many bytes were freed.
Future<int> clearCache() async {
  final dir = await cacheDirectory();
  final size = await directorySize(dir);
  if (dir.existsSync()) await dir.delete(recursive: true);
  return size;
}
