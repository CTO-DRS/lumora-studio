import 'dart:io';

import 'package:flutter/services.dart';
import 'package:lumora/features/photo_editor/engine/lut/cube_lut.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Metadata about an available LUT.
class LutInfo {
  const LutInfo({required this.id, required this.name, required this.builtIn});
  final String id;
  final String name;
  final bool builtIn;
}

/// Bundled LUTs (`builtin:<name>`) live in `assets/luts`, user imported ones
/// (`user:<name>`) are copied into the app support directory.
class LutRepository {
  LutRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final Map<String, CubeLut> _cache = {};

  static const builtInNames = ['teal_orange', 'bleach_bypass', 'warm_film'];

  Future<Directory> _userDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'luts'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  Future<List<LutInfo>> list() async {
    final out = [for (final n in builtInNames) LutInfo(id: 'builtin:$n', name: _pretty(n), builtIn: true)];
    final dir = await _userDir();
    await for (final f in dir.list()) {
      if (f is File && f.path.toLowerCase().endsWith('.cube')) {
        final name = p.basenameWithoutExtension(f.path);
        out.add(LutInfo(id: 'user:$name', name: name, builtIn: false));
      }
    }
    return out;
  }

  Future<CubeLut> load(String id) async {
    final cached = _cache[id];
    if (cached != null) return cached;
    final String text;
    if (id.startsWith('builtin:')) {
      text = await _bundle.loadString('assets/luts/${id.substring(8)}.cube');
    } else if (id.startsWith('user:')) {
      final dir = await _userDir();
      text = await File(p.join(dir.path, '${id.substring(5)}.cube')).readAsString();
    } else {
      throw ArgumentError('Unknown LUT id $id');
    }
    final lut = CubeLut.parse(text);
    return _cache[id] = lut;
  }

  /// Validates and imports a `.cube` file, returning its id.
  Future<String> import(String path) async {
    final text = await File(path).readAsString();
    CubeLut.parse(text); // throws on invalid input
    final dir = await _userDir();
    final name = p.basenameWithoutExtension(path).replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
    await File(p.join(dir.path, '$name.cube')).writeAsString(text);
    _cache.remove('user:$name');
    return 'user:$name';
  }

  static String _pretty(String n) =>
      n.split('_').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
}
