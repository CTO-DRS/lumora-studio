import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/photo_editor/domain/edit_state.dart';
import 'package:lumora/features/photo_editor/domain/finishing.dart';
import 'package:lumora/features/photo_editor/domain/geometry.dart';
import 'package:lumora/features/photo_editor/domain/presets.dart';
import 'package:lumora/features/photo_editor/engine/finishing_renderer.dart';
import 'package:lumora/features/photo_editor/engine/lut/lut_repository.dart';
import 'package:lumora/features/photo_editor/engine/photo_renderer.dart';
import 'package:lumora/features/photo_editor/engine/pixel_ops.dart';
import 'package:lumora/features/photo_editor/engine/preset_thumbnails.dart';
import 'package:lumora/features/photo_editor/engine/shader_library.dart';

/// Real GPU (shader) tests for the v1.1 editor features.
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

  testWidgets('live preset thumbnails render the photo through each look', (tester) async {
    await tester.runAsync(() async {
      final shaders = await ShaderLibrary.load();
      final cache = PresetThumbnailCache(() async => PhotoRenderer(shaders, LutRepository()), maxSide: 48);
      final src = await gradient(200, 100);
      cache.update(preview: src, base: Adjustments.neutral, geometry: const GeometryState());
      final presets = [null, presetById('noir'), presetById('teal_orange'), presetById('bright')];
      for (final p in presets) {
        expect(cache.thumbnail(p), isNull, reason: 'first request schedules');
      }
      for (var i = 0; i < 100 && cache.cachedCount < presets.length; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(cache.cachedCount, presets.length);
      final none = cache.thumbnail(null)!;
      expect((none.width, none.height), (48, 24));
      final noir = await pixels(cache.thumbnail(presetById('noir'))!);
      // Black & white: channels equal.
      expect((noir[100] - noir[101]).abs(), lessThanOrEqualTo(3));
      final bright = await pixels(cache.thumbnail(presetById('bright'))!);
      final plain = await pixels(none);
      var sb = 0;
      var sp = 0;
      for (var i = 0; i < plain.length; i += 4) {
        sb += bright[i + 1];
        sp += plain[i + 1];
      }
      expect(sb, greaterThan(sp));
      // A crop change invalidates the cache.
      cache.update(preview: src, base: Adjustments.neutral, geometry: const GeometryState(cropRight: 0.5));
      expect(cache.cachedCount, 0);
      cache.dispose();
    });
  });

  testWidgets('clipping overlay marks blown and crushed pixels', (tester) async {
    await tester.runAsync(() async {
      final renderer = PhotoRenderer(await ShaderLibrary.load(), LutRepository());
      final px = Uint8List.fromList([255, 255, 255, 255, 0, 0, 0, 255, 128, 100, 90, 255, 10, 10, 10, 255]);
      final img = await imageFromRgba(px, 4, 1);
      final out = await pixels(renderer.clippingOverlay(img));
      expect(out[0], greaterThan(150), reason: 'white → red');
      expect(out[2], lessThan(100));
      expect(out[6], greaterThan(150), reason: 'black → blue');
      expect(out[11], 0, reason: 'mid tones untouched (transparent)');
      expect(out[15], 0);
      renderer.dispose();
    });
  });

  testWidgets('finishing preview frames the image; export patch draws the watermark', (tester) async {
    await tester.runAsync(() async {
      final finishing = FinishingRenderer();
      final src = await gradient(100, 50);
      const edit = EditState(frame: FrameSettings(style: FrameStyle.border, width: 0.2));
      final framed = finishing.preview(src, edit);
      expect((framed.width, framed.height), (120, 70));
      final fpx = await pixels(framed);
      expect(fpx.sublist(0, 4), [255, 255, 255, 255]);
      expect(identical(finishing.preview(src, EditState.initial), src), isTrue);

      final dark = Rgba(200, 100)..fill(0xFF000000);
      final marked = await finishing.finish(
        dark,
        const EditState(
          watermark: WatermarkSettings(text: 'LUMORA', size: 0.2, opacity: 1, anchor: WatermarkAnchor.center),
        ),
      );
      expect((marked.width, marked.height), (200, 100));
      var lit = 0;
      for (var i = 0; i < marked.data.length; i += 4) {
        if (marked.data[i] > 100) lit++;
      }
      expect(lit, greaterThan(20), reason: 'white text pixels were composited');
      expect(dark.data.every((v) => v == 0 || v == 255), isTrue, reason: 'input is not modified');
      finishing.dispose();
    });
  });

  testWidgets('a disposed renderer recreates its textures on the next prepare', (tester) async {
    await tester.runAsync(() async {
      final renderer = PhotoRenderer(await ShaderLibrary.load(), LutRepository());
      final src = await gradient(32, 16);
      const edit = EditState(
        adjustments: Adjustments(curves: CurveSet(master: [CurvePoint(0, 0.2), CurvePoint(1, 1)])),
      );
      await renderer.prepare(edit);
      await pixels(renderer.render(src, edit));
      renderer.dispose();
      await renderer.prepare(edit);
      final out = await pixels(renderer.render(src, edit));
      expect(out[0], greaterThan(30), reason: 'curve lifts the blacks again after re-preparing');
      renderer.dispose();
    });
  });
}
