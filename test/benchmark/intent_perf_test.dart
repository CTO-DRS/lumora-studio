import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/smart_edit/domain/intent_engine.dart';

import 'intent_benchmark_data.dart';

/// ROADMAP §5 budget (C2): Smart command (rule engine) ≤ 10 ms parse.
/// Measured here on the slow shared build box so CI catches a complexity
/// regression long before a phone would: the mean must stay under 2 ms
/// (5x margin) and no single command may exceed 25 ms even here. The
/// printed table keeps the numbers visible release over release.
void main() {
  test('rule-engine parse stays far under the 10 ms budget', () {
    const engine = RuleIntentEngine();
    // Warm-up: JIT and regex caches.
    for (final e in kIntentBenchmark) {
      engine.parse(e.text);
    }
    const rounds = 5;
    final times = <int>[];
    for (var r = 0; r < rounds; r++) {
      for (final e in kIntentBenchmark) {
        final sw = Stopwatch()..start();
        engine.parse(e.text);
        times.add(sw.elapsedMicroseconds);
      }
    }
    times.sort();
    final mean = times.reduce((a, b) => a + b) / times.length;
    final p95 = times[(times.length * 0.95).floor()];
    final max = times.last;
    // Perf numbers must be visible in CI logs; printing is intentional.
    // ignore: avoid_print
    print(
      '── intent parse perf ───────────────────────────\n'
      'parses: ${times.length} (${kIntentBenchmark.length} commands x $rounds)\n'
      'mean: ${mean.toStringAsFixed(1)} us   p95: $p95 us   max: $max us   (budget: 10000 us on device)',
    );
    expect(mean, lessThan(2000), reason: 'mean parse ${mean.toStringAsFixed(1)} us regressed toward the 10 ms budget');
    expect(max, lessThan(25000), reason: 'slowest command took $max us even on this box');
  });
}
