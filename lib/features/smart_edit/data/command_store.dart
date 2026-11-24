import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted command history and favourites of the Smart bar (v1.3.x).
/// Stays on the device like every other Lumora setting.
class CommandMemory {
  CommandMemory(this._prefs);

  final SharedPreferences _prefs;

  static const _historyKey = 'smart.command_history';
  static const _favouritesKey = 'smart.command_favourites';
  static const _maxHistory = 24;
  static const _maxFavourites = 12;

  /// Most recent unique commands, newest first.
  List<String> history() => List<String>.of(_prefs.getStringList(_historyKey) ?? const []);

  /// Starred commands, newest first.
  List<String> favourites() => List<String>.of(_prefs.getStringList(_favouritesKey) ?? const []);

  /// Adds [command] to the top of the history (deduplicated, capped).
  void record(String command) {
    final t = command.trim();
    if (t.isEmpty) return;
    final h = history()
      ..remove(t)
      ..insert(0, t);
    if (h.length > _maxHistory) h.removeRange(_maxHistory, h.length);
    unawaited(_prefs.setStringList(_historyKey, h));
  }

  /// Stars [command], or removes the star when it is already starred.
  void toggleFavourite(String command) {
    final t = command.trim();
    if (t.isEmpty) return;
    final f = favourites();
    if (!f.remove(t)) f.insert(0, t);
    if (f.length > _maxFavourites) f.removeRange(_maxFavourites, f.length);
    unawaited(_prefs.setStringList(_favouritesKey, f));
  }

  bool isFavourite(String command) => favourites().contains(command.trim());
}

/// Loads the persisted memory (SharedPreferences is async).
final FutureProvider<CommandMemory> commandMemoryProvider = FutureProvider.autoDispose<CommandMemory>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return CommandMemory(prefs);
});
