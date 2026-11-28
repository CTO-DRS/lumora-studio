import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/photo_editor/engine/lut/cube_lut.dart';

/// C3 fuzz gate for the .cube LUT importer, same contract as the RAW and
/// subtitle gates: random garbage, every truncation point and single-character
/// mutations of a valid file must raise only the bounded CubeParseException —
/// never a crash, and never hang.
void main() {
  String identityCube(int n) {
    final b = StringBuffer('# comment\nTITLE "id"\nLUT_3D_SIZE $n\n\n');
    for (var bi = 0; bi < n; bi++) {
      for (var gi = 0; gi < n; gi++) {
        for (var ri = 0; ri < n; ri++) {
          b.writeln('${ri / (n - 1)} ${gi / (n - 1)} ${bi / (n - 1)}');
        }
      }
    }
    return b.toString();
  }

  final good = identityCube(3);
  const corpus = 400;

  void expectBounded(void Function() body, String label) {
    try {
      body();
    } on CubeParseException {
      // expected
    } catch (e) {
      fail('$label threw an unbounded error: $e');
    }
  }

  test('random garbage stays bounded', () {
    final rnd = Random(20261128);
    const alphabet = '0123456789.eE+- \n\t#TITLELUT_3D_SIZE"ab';
    for (var i = 0; i < corpus; i++) {
      final len = rnd.nextInt(160);
      final s = String.fromCharCodes(List.generate(len, (_) => alphabet.codeUnitAt(rnd.nextInt(alphabet.length))));
      expectBounded(() => CubeLut.parse(s), 'random#$i');
    }
  });

  test('every truncation point of a valid file stays bounded', () {
    expect(CubeLut.parse(good).size, 3);
    for (var cut = 0; cut <= good.length; cut++) {
      expectBounded(() => CubeLut.parse(good.substring(0, cut)), 'cut#$cut');
    }
  });

  test('single-character mutations stay bounded', () {
    final rnd = Random(17);
    const swaps = '09.eE-X_ \n#S"';
    for (var i = 0; i < corpus; i++) {
      final chars = good.split('');
      chars[rnd.nextInt(chars.length)] = swaps[rnd.nextInt(swaps.length)];
      final mutated = chars.join();
      expectBounded(() => CubeLut.parse(mutated), 'mut#$i');
    }
  });

  test('pathological LUT_3D_SIZE is capped, not OOM', () {
    expect(() => CubeLut.parse('LUT_3D_SIZE 999999\n'), throwsA(isA<CubeParseException>()));
  });
}
