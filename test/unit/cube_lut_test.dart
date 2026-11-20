import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/photo_editor/engine/lut/cube_lut.dart';

String _identityCube(int n, {String extra = ''}) {
  final b = StringBuffer('# comment\nTITLE "id"\n$extra\nLUT_3D_SIZE $n\n\n');
  for (var bi = 0; bi < n; bi++) {
    for (var gi = 0; gi < n; gi++) {
      for (var ri = 0; ri < n; ri++) {
        b.writeln('${ri / (n - 1)} ${gi / (n - 1)} ${bi / (n - 1)}');
      }
    }
  }
  return b.toString();
}

void main() {
  group('CubeLut.parse', () {
    test('parses identity cube with metadata', () {
      final lut = CubeLut.parse(_identityCube(4));
      expect(lut.size, 4);
      expect(lut.title, 'id');
      expect(lut.data.length, 4 * 4 * 4 * 3);
      // red fastest: second row is r = 1/3
      expect(lut.data[3], closeTo(1 / 3, 1e-6));
      expect(lut.data[4], 0);
    });

    test('identity LUT samples back the input (trilinear)', () {
      final lut = CubeLut.parse(_identityCube(5));
      final out = lut.sample(0.3, 0.62, 0.91);
      expect(out[0], closeTo(0.3, 1e-5));
      expect(out[1], closeTo(0.62, 1e-5));
      expect(out[2], closeTo(0.91, 1e-5));
    });

    test('handles CRLF, scientific notation and inline comments', () {
      const src = 'LUT_3D_SIZE 2\r\n0 0 0\r\n1e0 0 0 # red\r\n0 1 0\r\n1 1 0\r\n0 0 1\r\n1 0 1\r\n0 1 1\r\n1 1 1\r\n';
      final lut = CubeLut.parse(src);
      expect(lut.size, 2);
      expect(lut.sample(1, 1, 1), [1, 1, 1]);
    });

    test('normalizes custom DOMAIN', () {
      const src =
          'LUT_3D_SIZE 2\nDOMAIN_MIN 0 0 0\nDOMAIN_MAX 2 2 2\n'
          '0 0 0\n2 0 0\n0 2 0\n2 2 0\n0 0 2\n2 0 2\n0 2 2\n2 2 2\n';
      final lut = CubeLut.parse(src);
      expect(lut.sample(1, 0, 0)[0], closeTo(1, 1e-6));
    });

    test('rejects malformed files', () {
      expect(() => CubeLut.parse('0 0 0'), throwsA(isA<CubeParseException>()));
      expect(() => CubeLut.parse('LUT_3D_SIZE 1\n0 0 0'), throwsA(isA<CubeParseException>()));
      expect(() => CubeLut.parse('LUT_1D_SIZE 16\n'), throwsA(isA<CubeParseException>()));
      expect(() => CubeLut.parse('LUT_3D_SIZE 2\n0 0 0\n'), throwsA(isA<CubeParseException>()));
      expect(() => CubeLut.parse('LUT_3D_SIZE 2\n0 x 0\n'), throwsA(isA<CubeParseException>()));
      expect(() => CubeLut.parse(''), throwsA(isA<CubeParseException>()));
    });

    test('atlas layout: x = b*N + r, y = g', () {
      final lut = CubeLut.identity(3);
      final atlas = lut.toAtlasRgba();
      expect(lut.atlasWidth, 9);
      expect(lut.atlasHeight, 3);
      // pixel for r=2,g=1,b=2 => x = 2*3+2 = 8, y = 1
      const o = (1 * 9 + 8) * 4;
      expect(atlas[o], 255);
      expect(atlas[o + 1], 128);
      expect(atlas[o + 2], 255);
      expect(atlas[o + 3], 255);
    });

    test('bundled LUT assets are valid', () {
      for (final f in Directory('assets/luts').listSync().whereType<File>()) {
        final lut = CubeLut.parse(f.readAsStringSync());
        expect(lut.size, 17, reason: f.path);
        for (final v in lut.data) {
          expect(v, inInclusiveRange(0, 1));
        }
      }
    });
  });
}
