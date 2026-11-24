import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/smart_edit/domain/edit_ops.dart';
import 'package:lumora/features/smart_edit/domain/next_commands.dart';
import 'package:lumora/features/smart_edit/domain/intent_engine.dart';

const _engine = RuleIntentEngine();

void main() {
  group('nextCommands', () {
    test('no plan yet: the starter set', () {
      expect(nextCommands(null), kDefaultNextCommands);
      expect(nextCommands(const SmartEditPlan()), kDefaultNextCommands);
    });

    test('after a look: remove it first, then colour/detail commands', () {
      final plan = _engine.parse('cinematic');
      expect(nextCommands(plan), [NextCommand.removeLook, NextCommand.contrast, NextCommand.sharpen]);
    });

    test('after warmer: cool it back down', () {
      final plan = _engine.parse('a bit warmer');
      expect(nextCommands(plan), [NextCommand.cooler, NextCommand.sharpen, NextCommand.mono]);
    });

    test('after cooler: warm it back up', () {
      final plan = _engine.parse('cooler');
      expect(nextCommands(plan), [NextCommand.warmer, NextCommand.sharpen, NextCommand.mono]);
    });

    test('after a model action: contrast, mono, upscale follow-ups', () {
      final plan = _engine.parse('remove the background');
      expect(nextCommands(plan), [NextCommand.contrast, NextCommand.mono, NextCommand.upscale]);
    });

    test('after an absolute number: generic detail follow-ups, capped', () {
      final plan = _engine.parse('contrast 50');
      expect(nextCommands(plan).length, 3);
    });

    test('respects the max argument', () {
      final plan = _engine.parse('cinematic');
      expect(nextCommands(plan, max: 2).length, 2);
      expect(nextCommands(plan, max: 8).length, lessThanOrEqualTo(NextCommand.values.length));
    });
  });
}
