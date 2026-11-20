import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/photo_editor/domain/edit_state.dart';
import 'package:lumora/features/photo_editor/domain/geometry.dart';
import 'package:lumora/features/photo_editor/engine/lut/lut_repository.dart';
import 'package:lumora/features/photo_editor/engine/photo_renderer.dart';
import 'package:lumora/features/photo_editor/engine/shader_library.dart';

/// Exercises the real GLSL shaders through the Flutter engine used by
/// `flutter test`. Skipped automatically when the test runner has no
/// runtime-effect support.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ui.Image> gradient(int w, int h) {
    final px = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final o = (y * w + x) * 4;
        px[o] = (x * 255 / (w - 1)).round();
        px[o + 1] = (y * 255 / (h - 1)).round();
        px[o + 2] = 128;
        px[o + 3] = 255;
      }
    }
    return imageFromRgba(px, w, h);
  }

  Future<Uint8List> pixels(ui.Image img) async =>
      (await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!.buffer.asUint8List();

  double meanLuma(Uint8List px) {
    var s = 0.0;
    for (var i = 0; i < px.length; i += 4) {
      s += 0.2126 * px[i] + 0.7152 * px[i + 1] + 0.0722 * px[i + 2];
    }
    return s / (px.length / 4);
  }

  testWidgets('GPU pipeline: neutral ≈ identity, exposure brightens, geometry resizes', (tester) async {
    await tester.runAsync(() async {
      final shaders = await ShaderLibrary.load();
      final renderer = PhotoRenderer(shaders, LutRepository());
      final src = await gradient(64, 32);
      final srcPx = await pixels(src);

      await renderer.prepare(EditState.initial);
      final neutral = renderer.render(src, EditState.initial);
      final nPx = await pixels(neutral);
      expect(neutral.width, 64);
      var maxDiff = 0;
      for (var i = 0; i < nPx.length; i++) {
        final d = (nPx[i] - srcPx[i]).abs();
        if (d > maxDiff) maxDiff = d;
      }
      expect(maxDiff, lessThanOrEqualTo(3), reason: 'neutral edit must not change pixels');

      const bright = EditState(adjustments: Adjustments(exposure: 1));
      await renderer.prepare(bright);
      final b = await pixels(renderer.render(src, bright));
      expect(meanLuma(b), greaterThan(meanLuma(srcPx) + 20));

      const bw = EditState(adjustments: Adjustments(saturation: -1));
      final g = await pixels(renderer.render(src, bw));
      expect((g[400] - g[401]).abs(), lessThanOrEqualTo(2));

      const all = EditState(
        adjustments: Adjustments(
          contrast: 0.3,
          sharpen: 0.5,
          clarity: 0.3,
          dehaze: 0.2,
          blur: 0.1,
          vignette: -0.5,
          grain: 0.3,
          chromaticAberration: 0.3,
          glitch: 0.2,
          duotone: Duotone(strength: 0.5),
          curves: CurveSet(master: [CurvePoint(0, 0.1), CurvePoint(1, 0.9)]),
          lutId: 'builtin:teal_orange',
        ),
        geometry: GeometryState(cropRight: 0.5, quarterTurns: 1),
      );
      await renderer.prepare(all);
      final out = renderer.render(src, all);
      expect((out.width, out.height), (16, 64));
      await pixels(out);
      renderer.dispose();
    });
  });
}
