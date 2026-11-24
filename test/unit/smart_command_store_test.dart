import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/smart_edit/data/command_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late SmartCommandBookNotifier notifier;

  SmartCommandBook state() => container.read(smartCommandBookProvider);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
    addTearDown(container.dispose);
    notifier = container.read(smartCommandBookProvider.notifier);
  });

  group('SmartCommandBookNotifier', () {
    test('loads empty and marks loaded', () async {
      // With mock initial values the load completes synchronously.
      await pumpEventQueue();
      expect(state().loaded, isTrue);
      expect(state().recents, isEmpty);
      expect(state().favourites, isEmpty);
    });

    test('record keeps the most recent first and deduplicates', () async {
      await notifier.record('warmer');
      await notifier.record('more contrast');
      await notifier.record('warmer');
      expect(state().recents, ['warmer', 'more contrast']);
    });

    test('record ignores blank commands', () async {
      await notifier.record('   ');
      expect(state().recents, isEmpty);
    });

    test('history is capped at kSmartHistoryMax', () async {
      for (var i = 0; i < kSmartHistoryMax + 3; i++) {
        await notifier.record('command $i');
      }
      expect(state().recents.length, kSmartHistoryMax);
      expect(state().recents.first, 'command ${kSmartHistoryMax + 2}');
    });

    test('toggleFavourite stars and unstars in order', () async {
      await notifier.record('warmer');
      await notifier.record('noir');
      await notifier.toggleFavourite('warmer');
      await notifier.toggleFavourite('noir');
      expect(state().favourites, ['warmer', 'noir']);
      await notifier.toggleFavourite('warmer');
      expect(state().favourites, ['noir']);
      expect(state().recents, ['noir', 'warmer'], reason: 'starring never touches history');
    });

    test('forget removes one entry, clearHistory empties it', () async {
      await notifier.record('warmer');
      await notifier.record('more contrast');
      await notifier.toggleFavourite('warmer');
      await notifier.forget('warmer');
      expect(state().recents, ['more contrast']);
      expect(state().favourites, ['warmer']);
      await notifier.clearHistory();
      expect(state().recents, isEmpty);
      expect(state().favourites, ['warmer']);
    });

    test('book round-trips through SharedPreferences and reloads', () async {
      await notifier.record('cinematic');
      await notifier.record('warmer');
      await notifier.toggleFavourite('cinematic');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('smart.commandHistory'), ['warmer', 'cinematic']);
      expect(prefs.getStringList('smart.commandFavourites'), ['cinematic']);

      // A fresh notifier (a new app run) reads the persisted lists back.
      final container2 = ProviderContainer();
      addTearDown(container2.dispose);
      container2.read(smartCommandBookProvider.notifier);
      await pumpEventQueue();
      expect(container2.read(smartCommandBookProvider).recents, ['warmer', 'cinematic']);
      expect(container2.read(smartCommandBookProvider).favourites, ['cinematic']);
    });
  });
}
