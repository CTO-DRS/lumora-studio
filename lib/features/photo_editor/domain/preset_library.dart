import 'dart:convert';

import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/photo_editor/domain/presets.dart';

/// File format marker used when sharing presets between devices.
const kPresetFileFormat = 'lumora.presets';
const kPresetFileVersion = 1;

/// Thrown when an imported preset file cannot be understood.
class PresetFormatException implements Exception {
  PresetFormatException(this.message);
  final String message;
  @override
  String toString() => 'PresetFormatException: $message';
}

/// The user's own presets plus their favourites (ids of built-in or custom
/// presets). Immutable.
class PresetLibrary {
  const PresetLibrary({this.custom = const [], this.favorites = const {}});

  final List<Preset> custom;
  final Set<String> favorites;

  /// Resolves [id] against the built-in and the user's presets.
  Preset? byId(String? id) {
    if (id == null) return null;
    final builtIn = presetById(id);
    if (builtIn != null) return builtIn;
    for (final p in custom) {
      if (p.id == id) return p;
    }
    return null;
  }

  bool isFavorite(String id) => favorites.contains(id);

  /// Presets shown for [category]; `null` means the favourites row.
  List<Preset> presetsFor(PresetCategory? category) {
    if (category == null) {
      return [for (final id in favorites) ?byId(id)];
    }
    if (category == PresetCategory.custom) return custom;
    return [
      for (final p in kBuiltInPresets)
        if (p.category == category) p,
    ];
  }

  PresetLibrary copyWith({List<Preset>? custom, Set<String>? favorites}) =>
      PresetLibrary(custom: custom ?? this.custom, favorites: favorites ?? this.favorites);

  PresetLibrary toggleFavorite(String id) =>
      copyWith(favorites: favorites.contains(id) ? ({...favorites}..remove(id)) : {...favorites, id});

  PresetLibrary add(Preset p) => copyWith(custom: [...custom.where((c) => c.id != p.id), p]);

  PresetLibrary remove(String id) =>
      copyWith(custom: custom.where((c) => c.id != id).toList(), favorites: {...favorites}..remove(id));

  PresetLibrary rename(String id, String name) => copyWith(
    custom: [for (final c in custom) c.id == id ? Preset.custom(id: c.id, name: name, adjustments: c.adjustments) : c],
  );

  /// Merges [imported] presets, giving fresh ids to any that collide.
  (PresetLibrary, int) merge(List<Preset> imported, String Function() newId) {
    var lib = this;
    for (final p in imported) {
      final exists = lib.custom.any((c) => c.id == p.id) || presetById(p.id) != null;
      lib = lib.add(exists ? Preset.custom(id: newId(), name: p.nameEn, adjustments: p.adjustments) : p);
    }
    return (lib, imported.length);
  }
}

/// Serialises one custom preset.
Map<String, Object?> presetToJson(Preset p) => {'id': p.id, 'name': p.nameEn, 'adjustments': p.adjustments.toJson()};

Preset presetFromJson(Map<String, dynamic> json) {
  final name = json['name'];
  final adj = json['adjustments'];
  if (name is! String || name.trim().isEmpty) throw PresetFormatException('missing name');
  if (adj is! Map<String, dynamic>) throw PresetFormatException('missing adjustments');
  final rawId = json['id'];
  final id = rawId is String && rawId.startsWith('user:') ? rawId : 'user:${name.hashCode.abs()}';
  return Preset.custom(id: id, name: name.trim(), adjustments: _sanitize(Adjustments.fromJson(adj)));
}

/// Clamps every scalar to its slider range so foreign files cannot push the
/// shaders out of bounds.
Adjustments _sanitize(Adjustments a) {
  var out = a;
  for (final p in AdjustmentParam.values) {
    out = p.write(out, p.read(out));
  }
  return out;
}

/// Encodes presets as a shareable `.lumora-preset.json` document.
String encodePresetFile(List<Preset> presets) => const JsonEncoder.withIndent('  ').convert({
  'format': kPresetFileFormat,
  'version': kPresetFileVersion,
  'presets': [for (final p in presets) presetToJson(p)],
});

/// Decodes a preset document. Accepts the full file format, a bare list of
/// presets or a single preset object.
List<Preset> decodePresetFile(String source) {
  final Object? root;
  try {
    root = jsonDecode(source);
  } on FormatException catch (e) {
    throw PresetFormatException('invalid JSON: ${e.message}');
  }
  List<Object?> items;
  if (root is Map<String, dynamic> && root['presets'] is List) {
    final format = root['format'];
    if (format != null && format != kPresetFileFormat) throw PresetFormatException('unknown format $format');
    final version = root['version'];
    if (version is int && version > kPresetFileVersion) throw PresetFormatException('unsupported version $version');
    items = root['presets'] as List<Object?>;
  } else if (root is List) {
    items = root;
  } else if (root is Map<String, dynamic>) {
    items = [root];
  } else {
    throw PresetFormatException('unexpected document');
  }
  final out = <Preset>[];
  for (final item in items) {
    if (item is! Map<String, dynamic>) throw PresetFormatException('preset must be an object');
    try {
      out.add(presetFromJson(item));
    } on PresetFormatException {
      rethrow;
    } on Object catch (e) {
      throw PresetFormatException('bad preset: $e');
    }
  }
  if (out.isEmpty) throw PresetFormatException('no presets found');
  return out;
}

/// Encodes the library for local persistence.
String encodeLibrary(PresetLibrary lib) => jsonEncode({
  'custom': [for (final p in lib.custom) presetToJson(p)],
  'favorites': lib.favorites.toList(),
});

PresetLibrary decodeLibrary(String? source) {
  if (source == null || source.isEmpty) return const PresetLibrary();
  try {
    final root = jsonDecode(source) as Map<String, dynamic>;
    return PresetLibrary(
      custom: [for (final p in (root['custom'] as List? ?? const [])) presetFromJson(p as Map<String, dynamic>)],
      favorites: {for (final f in (root['favorites'] as List? ?? const [])) f as String},
    );
  } on Object {
    return const PresetLibrary();
  }
}
