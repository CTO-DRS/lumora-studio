import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/photo_editor/domain/auto_enhance.dart';

Uint8List _image(int n, int r, int g, int b) {
  final px = Uint8List(n * 4);
  for (var i = 0; i < n; i++) {
    px
      ..[i * 4] = r
      ..[i * 4 + 1] = g
      ..[i * 4 + 2] = b
      ..[i * 4 + 3] = 255;
  }
  return px;
}

void main() {
  test('dark image gets positive exposure', () {
    final s = ImageStats.fromRgba(_image(100, 30, 30, 30), 10, 10);
    expect(autoEnhance(s).exposure, greaterThan(0.5));
  });

  test('bright image gets negative exposure', () {
    final s = ImageStats.fromRgba(_image(100, 240, 240, 240), 10, 10);
    expect(autoEnhance(s).exposure, lessThan(0));
  });

  test('blue cast is warmed, green cast pushed to magenta', () {
    final blue = autoEnhance(ImageStats.fromRgba(_image(100, 90, 110, 170), 10, 10));
    expect(blue.temperature, greaterThan(0));
    final green = autoEnhance(ImageStats.fromRgba(_image(100, 100, 160, 100), 10, 10));
    expect(green.tint, greaterThan(0));
  });

  test('transparent pixels are ignored', () {
    final s = ImageStats.fromRgba(Uint8List(400), 10, 10);
    expect(s.meanLuma, 0.5);
  });

  test('values stay in slider range', () {
    final a = autoEnhance(ImageStats.fromRgba(_image(100, 0, 0, 255), 10, 10));
    expect(a.exposure, inInclusiveRange(-1.5, 1.5));
    expect(a.temperature, inInclusiveRange(-0.4, 0.4));
    expect(a.vibrance, inInclusiveRange(-0.1, 0.4));
  });
}
