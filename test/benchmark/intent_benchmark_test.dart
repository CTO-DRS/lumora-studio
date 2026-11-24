import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/smart_edit/domain/edit_ops.dart';
import 'package:lumora/features/smart_edit/domain/intent_engine.dart';

import 'intent_benchmark_data.dart';

/// ROADMAP §5 (v1.3.x) intent benchmark: every command must produce its
/// exact plan. Acceptance is ≥ 95 % per language (AR and EN separately);
/// the printed table tracks regressions release over release.
const _engine = RuleIntentEngine();
const _threshold = 0.95;

void main() {
  test('intent benchmark (AR/EN exact-plan accuracy)', () {
    final total = <String, int>{'ar': 0, 'en': 0};
    final passed = <String, int>{'ar': 0, 'en': 0};
    final failures = <String>[];

    for (final entry in kIntentBenchmark) {
      total[entry.lang] = total[entry.lang]! + 1;
      final plan = _engine.parse(entry.text);
      final expected = [for (final j in entry.expected) EditOp.fromJson(j)];
      final ok = _sameOps(plan.ops, expected) && plan.unrecognized.isEmpty;
      if (ok) {
        passed[entry.lang] = passed[entry.lang]! + 1;
      } else {
        failures.add('${entry.lang}: "${entry.text}"\n   expected $expected\n   actual   ${plan.ops} ?${plan.unrecognized}');
      }
    }
    // The benchmark summary must be visible in CI logs; printing is intentional.
    // ignore: avoid_print
    print('── intent benchmark ─────────────────────────────');
    for (final lang in const ['ar', 'en']) {
      final acc = total[lang] == 0 ? 1.0 : passed[lang]! / total[lang]!;
      // Accuracy must be visible per release; printing is intentional.
      // ignore: avoid_print
      print('${lang.toUpperCase()}: ${passed[lang]}/${total[lang]} = ${(acc * 100).toStringAsFixed(1)} %');
      expect(acc, greaterThanOrEqualTo(_threshold), reason: '$lang accuracy below the v1.3.x acceptance bar');
    }
    // Keep the command count visible when the generator changes.
    // ignore: avoid_print
    print('total: ${kIntentBenchmark.length} commands');
    expect(failures, isEmpty, reason: failures.take(20).join('\n'));
  });

  test('benchmark covers 1000+ commands in both languages', () {
    expect(kIntentBenchmark.length, greaterThanOrEqualTo(1000));
    expect(kIntentBenchmark.where((e) => e.lang == 'ar').length, greaterThanOrEqualTo(400));
    expect(kIntentBenchmark.where((e) => e.lang == 'en').length, greaterThanOrEqualTo(400));
  });

  test('every expected op uses known params, looks and actions', () {
    for (final entry in kIntentBenchmark) {
      for (final json in entry.expected) {
        expect(() => EditOp.fromJson(json), returnsNormally, reason: '${entry.text}: $json');
      }
    }
  });
}

/// Order-insensitive comparison: the plan is the same edit if it carries
/// the same ops (types, targets and amounts) — clause boundaries can make
/// the engine emit a look before a slider of the same clause, and `_merge`
/// folds repeats, so a strict sequence would over-constrain.
bool _sameOps(List<EditOp> actual, List<EditOp> expected) {
  if (actual.length != expected.length) return false;
  String key(EditOp op) => switch (op) {
    AdjustOp(:final param, :final amount, :final absolute) =>
      'a|${param.name}|${amount.toStringAsFixed(6)}|$absolute',
    LookOp(:final presetId, :final intensity) => 'l|$presetId|${intensity.toStringAsFixed(6)}',
    ActionOp(:final action) => 'o|${action.name}',
  };
  final a = actual.map(key).toList()..sort();
  final b = expected.map(key).toList()..sort();
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
