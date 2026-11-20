import 'dart:typed_data';

/// Thrown when a `.cube` file cannot be parsed.
class CubeParseException implements Exception {
  CubeParseException(this.message, [this.line]);
  final String message;
  final int? line;

  @override
  String toString() => 'CubeParseException: $message${line != null ? ' (line $line)' : ''}';
}

/// A 3D colour lookup table as defined by the Adobe/Resolve `.cube` format.
///
/// [data] holds `size³` RGB triplets with red changing fastest, then green,
/// then blue – exactly the order of the file.
class CubeLut {
  CubeLut({
    required this.size,
    required this.data,
    this.title,
    this.domainMin = const [0, 0, 0],
    this.domainMax = const [1, 1, 1],
  }) : assert(data.length == size * size * size * 3, 'bad LUT data length');

  /// Identity LUT, handy for tests and as a neutral fallback.
  factory CubeLut.identity([int size = 17]) {
    final data = Float32List(size * size * size * 3);
    var i = 0;
    for (var b = 0; b < size; b++) {
      for (var g = 0; g < size; g++) {
        for (var r = 0; r < size; r++) {
          data[i++] = r / (size - 1);
          data[i++] = g / (size - 1);
          data[i++] = b / (size - 1);
        }
      }
    }
    return CubeLut(size: size, data: data, title: 'identity');
  }

  final int size;
  final Float32List data;
  final String? title;
  final List<double> domainMin;
  final List<double> domainMax;

  static const int maxSize = 65;

  /// Parses `.cube` text. Supports comments, `TITLE`, `LUT_3D_SIZE`,
  /// `DOMAIN_MIN`/`DOMAIN_MAX`, blank lines and scientific notation.
  static CubeLut parse(String source) {
    String? title;
    int? size;
    var domainMin = const <double>[0, 0, 0];
    var domainMax = const <double>[1, 1, 1];
    Float32List? data;
    var count = 0;

    final lines = source.split(RegExp(r'\r\n|\r|\n'));
    for (var ln = 0; ln < lines.length; ln++) {
      var line = lines[ln];
      final hash = line.indexOf('#');
      if (hash >= 0) line = line.substring(0, hash);
      line = line.trim();
      if (line.isEmpty) continue;

      final first = line.codeUnitAt(0);
      final isKeyword = (first >= 65 && first <= 90) || first == 95; // A-Z, _
      if (isKeyword) {
        final space = line.indexOf(RegExp(r'\s'));
        final key = space < 0 ? line : line.substring(0, space);
        final rest = space < 0 ? '' : line.substring(space).trim();
        switch (key) {
          case 'TITLE':
            title = rest.replaceAll('"', '');
          case 'LUT_3D_SIZE':
            size = int.tryParse(rest);
            if (size == null || size < 2 || size > maxSize) {
              throw CubeParseException('Invalid LUT_3D_SIZE "$rest"', ln + 1);
            }
            data = Float32List(size * size * size * 3);
          case 'LUT_1D_SIZE':
            throw CubeParseException('1D LUTs are not supported', ln + 1);
          case 'DOMAIN_MIN':
            domainMin = _triplet(rest, ln);
          case 'DOMAIN_MAX':
            domainMax = _triplet(rest, ln);
          default:
            // Unknown keywords (e.g. LUT_3D_INPUT_RANGE) are ignored.
            break;
        }
        continue;
      }

      if (data == null) {
        throw CubeParseException('Data before LUT_3D_SIZE', ln + 1);
      }
      final v = _triplet(line, ln);
      if (count * 3 >= data.length) {
        throw CubeParseException('Too many data rows', ln + 1);
      }
      data[count * 3] = v[0];
      data[count * 3 + 1] = v[1];
      data[count * 3 + 2] = v[2];
      count++;
    }

    if (size == null || data == null) {
      throw CubeParseException('Missing LUT_3D_SIZE');
    }
    if (count != size * size * size) {
      throw CubeParseException('Expected ${size * size * size} rows but found $count');
    }
    // Normalize into 0..1 if the domain differs.
    final needsNorm = domainMin.any((v) => v != 0) || domainMax.any((v) => v != 1);
    if (needsNorm) {
      for (var i = 0; i < data.length; i++) {
        final c = i % 3;
        final range = domainMax[c] - domainMin[c];
        data[i] = range == 0 ? 0 : (data[i] - domainMin[c]) / range;
      }
    }
    return CubeLut(size: size, data: data, title: title, domainMin: domainMin, domainMax: domainMax);
  }

  static List<double> _triplet(String s, int ln) {
    final parts = s.split(RegExp(r'\s+'));
    if (parts.length < 3) {
      throw CubeParseException('Expected 3 values, got "$s"', ln + 1);
    }
    final out = <double>[];
    for (var i = 0; i < 3; i++) {
      final v = double.tryParse(parts[i]);
      if (v == null || v.isNaN) {
        throw CubeParseException('Invalid number "${parts[i]}"', ln + 1);
      }
      out.add(v);
    }
    return out;
  }

  /// Looks up a colour with trilinear interpolation (CPU reference
  /// implementation, used for video thumbnails and tests).
  List<double> sample(double r, double g, double b) {
    final n = size - 1;
    double c(double v) => v.clamp(0.0, 1.0) * n;
    final rf = c(r);
    final gf = c(g);
    final bf = c(b);
    final r0 = rf.floor().clamp(0, n);
    final g0 = gf.floor().clamp(0, n);
    final b0 = bf.floor().clamp(0, n);
    final r1 = (r0 + 1).clamp(0, n);
    final g1 = (g0 + 1).clamp(0, n);
    final b1 = (b0 + 1).clamp(0, n);
    final dr = rf - r0;
    final dg = gf - g0;
    final db = bf - b0;
    final out = <double>[0, 0, 0];
    for (var ch = 0; ch < 3; ch++) {
      double at(int ri, int gi, int bi) => data[((bi * size + gi) * size + ri) * 3 + ch];
      final c00 = at(r0, g0, b0) * (1 - dr) + at(r1, g0, b0) * dr;
      final c10 = at(r0, g1, b0) * (1 - dr) + at(r1, g1, b0) * dr;
      final c01 = at(r0, g0, b1) * (1 - dr) + at(r1, g0, b1) * dr;
      final c11 = at(r0, g1, b1) * (1 - dr) + at(r1, g1, b1) * dr;
      final c0 = c00 * (1 - dg) + c10 * dg;
      final c1 = c01 * (1 - dg) + c11 * dg;
      out[ch] = c0 * (1 - db) + c1 * db;
    }
    return out;
  }

  /// Packs the LUT into an RGBA8 atlas of `(size*size) x size` pixels:
  /// x = blue * size + red, y = green. Consumed by `develop.frag`.
  Uint8List toAtlasRgba() {
    final w = size * size;
    final out = Uint8List(w * size * 4);
    for (var b = 0; b < size; b++) {
      for (var g = 0; g < size; g++) {
        for (var r = 0; r < size; r++) {
          final src = ((b * size + g) * size + r) * 3;
          final dst = (g * w + b * size + r) * 4;
          out[dst] = (data[src].clamp(0.0, 1.0) * 255).round();
          out[dst + 1] = (data[src + 1].clamp(0.0, 1.0) * 255).round();
          out[dst + 2] = (data[src + 2].clamp(0.0, 1.0) * 255).round();
          out[dst + 3] = 255;
        }
      }
    }
    return out;
  }

  int get atlasWidth => size * size;
  int get atlasHeight => size;
}
