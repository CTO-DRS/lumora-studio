import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user's smart-command history and favourites.
///
/// Both are plain, ordered string lists: history is most-recent-first with
/// duplicates removed (capped at [kSmartHistoryMax]), favourites keep the
/// order in which they were starred. Nothing here leaves the device; the
/// lists live in SharedPreferences (v1.3.x "command history & favourites").
@immutable
class SmartCommandBook {
  const SmartCommandBook({this.recents = const [], this.favourites = const [], this.loaded = false});

  /// Previously typed commands, most recent first (max [kSmartHistoryMax]).
  final List<String> recents;

  /// Starred commands, oldest star first.
  final List<String> favourites;

  /// True once the persisted lists have been read (rows stay hidden while
  /// loading to avoid a flash of stale content).
  final bool loaded;

  bool isFavourite(String command) => favourites.contains(command);

  SmartCommandBook copyWith({List<String>? recents, List<String>? favourites, bool? loaded}) => SmartCommandBook(
    recents: recents ?? this.recents,
    favourites: favourites ?? this.favourites,
    loaded: loaded ?? this.loaded,
  );

  static const _eq = ListEquality<String>();

  @override
  bool operator ==(Object other) =>
      other is SmartCommandBook &&
      other.loaded == loaded &&
      _eq.equals(other.recents, recents) &&
      _eq.equals(other.favourites, favourites);

  @override
  int get hashCode => Object.hash(_eq.hash(recents), _eq.hash(favourites), loaded);
}

/// History size cap: long lists would push the suggestions off screen.
const kSmartHistoryMax = 12;

const _kRecentsKey = 'smart.commandHistory';
const _kFavouritesKey = 'smart.commandFavourites';

List<String> _readList(SharedPreferences prefs, String key) => [
  for (final v in (prefs.getStringList(key) ?? const <String>[]))
    if (v.trim().isNotEmpty) v.trim(),
];

/// Holds and persists [SmartCommandBook]. The UI watches
/// [smartCommandBookProvider], calls [record] after a command ran and
/// [toggleFavourite] from a chip long-press.
class SmartCommandBookNotifier extends Notifier<SmartCommandBook> {
  SharedPreferences? _prefs;

  @override
  SmartCommandBook build() {
    _load();
    return const SmartCommandBook();
  }

  Future<void> _load() async {
    final prefs = _prefs = await SharedPreferences.getInstance();
    // Keep the newest entries only, in case an older version stored more.
    final recents = _readList(prefs, _kRecentsKey).take(kSmartHistoryMax).toList();
    state = SmartCommandBook(recents: recents, favourites: _readList(prefs, _kFavouritesKey), loaded: true);
  }

  /// Adds [command] to the top of the history (and removes a duplicate).
  Future<void> record(String command) async {
    final text = command.trim();
    if (text.isEmpty) return;
    final recents = [
      text,
      for (final c in state.recents)
        if (c != text) c,
    ].take(kSmartHistoryMax).toList();
    state = state.copyWith(recents: recents);
    await _prefs?.setStringList(_kRecentsKey, recents);
  }

  /// Stars (or unstars) [command]; starred commands stay reachable after
  /// they scroll out of the history.
  Future<void> toggleFavourite(String command) async {
    final text = command.trim();
    if (text.isEmpty) return;
    final starred = state.favourites.contains(text);
    final favourites = [
      for (final c in state.favourites)
        if (c != text) c,
      if (!starred) text,
    ];
    state = state.copyWith(favourites: favourites);
    await _prefs?.setStringList(_kFavouritesKey, favourites);
  }

  /// Drops one entry from the history (favourites are kept).
  Future<void> forget(String command) async {
    final recents = [
      for (final c in state.recents)
        if (c != command) c,
    ];
    state = state.copyWith(recents: recents);
    await _prefs?.setStringList(_kRecentsKey, recents);
  }

  /// Clears the history; favourites survive.
  Future<void> clearHistory() async {
    state = state.copyWith(recents: const []);
    await _prefs?.remove(_kRecentsKey);
  }
}

/// Hand-written provider (see [ModelDownloadProgress] in the AI sheet for
/// the precedent): the store is tiny and needs no codegen plumbing.
final NotifierProvider<SmartCommandBookNotifier, SmartCommandBook> smartCommandBookProvider =
    NotifierProvider<SmartCommandBookNotifier, SmartCommandBook>(SmartCommandBookNotifier.new);

/// Marker shown on favourited chips (a literal, so both languages match).
const kSmartFavouriteMark = '\u2605';
