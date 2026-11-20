import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/photo_editor/domain/edit_clipboard.dart';
import 'package:lumora/features/photo_editor/domain/edit_state.dart';
import 'package:lumora/features/photo_editor/domain/preset_library.dart';
import 'package:lumora/features/photo_editor/domain/presets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

part 'preset_store.g.dart';

const _kLibraryKey = 'presetLibrary.v1';
const _kClipboardKey = 'editClipboard.v1';
const _uuid = Uuid();

/// The user's presets and favourites, persisted in SharedPreferences.
@Riverpod(keepAlive: true)
class PresetLibraryController extends _$PresetLibraryController {
  SharedPreferences? _prefs;

  @override
  PresetLibrary build() {
    _load();
    return const PresetLibrary();
  }

  Future<void> _load() async {
    final prefs = _prefs = await SharedPreferences.getInstance();
    final loaded = decodeLibrary(prefs.getString(_kLibraryKey));
    // Keep anything added while loading.
    state = PresetLibrary(
      custom: [...loaded.custom, ...state.custom.where((c) => loaded.byId(c.id) == null)],
      favorites: {...loaded.favorites, ...state.favorites},
    );
  }

  Future<void> _persist() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setString(_kLibraryKey, encodeLibrary(state));
  }

  /// Saves [adjustments] as a new preset and returns it.
  Future<Preset> saveAs(String name, Adjustments adjustments) async {
    final preset = Preset.custom(id: 'user:${_uuid.v4()}', name: name.trim(), adjustments: adjustments);
    state = state.add(preset);
    await _persist();
    return preset;
  }

  Future<void> rename(String id, String name) async {
    state = state.rename(id, name.trim());
    await _persist();
  }

  Future<void> delete(String id) async {
    state = state.remove(id);
    await _persist();
  }

  Future<void> toggleFavorite(String id) async {
    state = state.toggleFavorite(id);
    await _persist();
  }

  /// Imports a preset document; returns how many presets were added.
  Future<int> importFile(String source) async {
    final presets = decodePresetFile(source);
    final (lib, count) = state.merge(presets, () => 'user:${_uuid.v4()}');
    state = lib;
    await _persist();
    return count;
  }

  /// Encodes [ids] (or every custom preset) as a shareable document.
  String exportFile([Iterable<String>? ids]) {
    final wanted = ids?.toSet();
    return encodePresetFile([
      for (final p in state.custom)
        if (wanted == null || wanted.contains(p.id)) p,
    ]);
  }
}

/// "Copy edits" clipboard shared by the editor, batch mode and the home
/// screen. Persisted so a copied look survives an app restart.
@Riverpod(keepAlive: true)
class EditClipboard extends _$EditClipboard {
  @override
  EditState? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state ??= decodeClipboard(prefs.getString(_kClipboardKey));
  }

  Future<void> copy(EditState s) async {
    state = clipboardCopy(s);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kClipboardKey, encodeClipboard(state!));
  }

  Future<void> clear() async {
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kClipboardKey);
  }
}
