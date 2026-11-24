import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/smart_edit/data/command_store.dart';
import 'package:lumora/features/smart_edit/domain/edit_ops.dart';
import 'package:lumora/features/smart_edit/domain/intent_engine.dart';
import 'package:lumora/features/smart_edit/domain/next_commands.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _e = RuleIntentEngine();

void main() {
  group('CommandMemory', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('history deduplicates, newest first, capped', () async {
      final m = CommandMemory(await SharedPreferences.getInstance());
      for (var i = 0; i < 30; i++) {
        m.record('command $i');
      }
      m.record('command 29');
      final h = m.history();
      expect(h.first, 'command 29');
      expect(h.length, 24);
      expect(h.where((c) => c == 'command 29'), hasLength(1));
    });

    test('favourites toggle and cap', () async {
      final m = CommandMemory(await SharedPreferences.getInstance());
      m.toggleFavourite('warmer');
      expect(m.isFavourite('warmer'), isTrue);
      m.toggleFavourite('warmer');
      expect(m.isFavourite('warmer'), isFalse);
      for (var i = 0; i < 15; i++) {
        m.toggleFavourite('fav $i');
      }
      expect(m.favourites().length, 12);
    });

    test('blank commands are ignored', () async {
      final m = CommandMemory(await SharedPreferences.getInstance());
      m.record('   ');
      m.toggleFavourite('  ');
      expect(m.history(), isEmpty);
      expect(m.favourites(), isEmpty);
    });
  });

  group('nextCommands', () {
    SmartEditPlan parse(String text) => _e.parse(text);

    test('every suggested phrase parses into a non-empty plan (EN)', () {
      final plans = [
        parse('brighter'),
        parse('more contrast'),
        parse('make it warmer'),
        parse('more vivid'),
        parse('more blur'),
        parse('add film grain'),
        parse('black and white'),
        parse('blur the background'),
        parse('remove the background'),
        parse('cut out the person'),
        parse('remove the person'),
        parse('smooth skin'),
        parse('upscale'),
      ];
      final seen = <String>{};
      for (final p in plans) {
        for (final c in nextCommands(lang: 'en', plan: p)) {
          seen.add(c);
          final back = _e.parse(c);
          expect(back.isEmpty, isFalse, reason: '"$c" must parse');
          expect(back.unrecognized, isEmpty, reason: '"$c" must be fully understood');
        }
      }
      expect(seen, containsAll(<String>['more contrast', 'add film grain', 'more blur', 'enhance']));
    });

    test('every suggested phrase parses into a non-empty plan (AR)', () {
      final plans = [
        parse('زد السطوع'),
        parse('زد التباين'),
        parse('اجعلها أدفأ'),
        parse('زد الحيوية'),
        parse('طمس الخلفية'),
        parse('أزل الخلفية'),
        parse('قص الشخص'),
        parse('أزل الشخص'),
        parse('حسن الوجه'),
        parse('كبر الصورة'),
        parse('أبيض وأسود'),
      ];
      final seen = <String>{};
      for (final p in plans) {
        for (final c in nextCommands(lang: 'ar', plan: p)) {
          seen.add(c);
          final back = _e.parse(c);
          expect(back.isEmpty, isFalse, reason: '"$c" must parse');
          expect(back.unrecognized, isEmpty, reason: '"$c" must be fully understood');
        }
      }
      expect(seen, containsAll(<String>['زد التباين', 'أضف حبيبات', 'زد التمويه', 'حسن الصورة']));
    });

    test('chains follow the edit that was just applied', () {
      expect(nextCommands(lang: 'en', plan: parse('brighter')).first, 'more contrast');
      expect(nextCommands(lang: 'en', plan: parse('more contrast')).first, 'reduce the highlights a bit');
      expect(nextCommands(lang: 'en', plan: parse('blur the background')).first, 'more blur');
      expect(nextCommands(lang: 'en', plan: parse('remove the person')).first, 'upscale');
      expect(nextCommands(lang: 'ar', plan: parse('زد السطوع')).first, 'زد التباين');
      expect(nextCommands(lang: 'ar', plan: parse('طمس الخلفية')).first, 'زد التمويه');
    });

    test('falls back to a generic chain and caps at three', () {
      final c = nextCommands(lang: 'en', plan: parse('rotate'));
      expect(c, ['more contrast', 'cinematic']);
    });
  });

  test('the follow-up chains stay model-free or ask before downloading', () {
    // Every op the suggested commands produce must be an instant slider/look
    // change or a documented model action — never an unrecognised guess.
    for (final c in nextCommands(
      lang: 'en',
      plan: const SmartEditPlan(ops: [ActionOp(SmartAction.reset)]),
    )) {
      final p = _e.parse(c);
      for (final op in p.ops) {
        expect(op, anyOf(isA<AdjustOp>(), isA<LookOp>(), isA<ActionOp>()));
        if (op is ActionOp) {
          expect(SmartAction.values, contains(op.action));
        }
      }
    }
  });
}
