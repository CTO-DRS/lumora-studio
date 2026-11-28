import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/photo_editor/domain/edit_state.dart';
import 'package:lumora/features/photo_editor/engine/lut/lut_repository.dart';
import 'package:lumora/features/photo_editor/engine/photo_renderer.dart';
import 'package:lumora/features/photo_editor/engine/shader_library.dart';

/// Golden tests for the GPU develop shader (roadmap §6 gate). The probe that
/// preceded this file showed headless shader rendering is deterministic on
/// the build box (identity render is bit-exact), so the graded fixture is
/// pinned against a golden PNG with a tiny per-channel tolerance for driver
/// rounding on other machines. Regenerate after an intentional shader
/// change with:
///   LUMORA_UPDATE_GOLDENS=1 flutter test test/golden
void main() {
  const goldenDir = 'test/golden/files';
  final update = Platform.environment['LUMORA_UPDATE_GOLDENS'] == '1';

  const w = 64;
  const h = 64;

  /// Deterministic source: luma/chroma gradients plus saturated primaries,
  /// so tone and colour moves each have signal to bite on.
  Uint8List sourceRgba() {
    final rgba = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        if (y < 16) {
          // top band: grey ramp 0..252
          final v = (x * 4) & 0xFF;
          rgba[i] = v;
          rgba[i + 1] = v;
          rgba[i + 2] = v;
        } else if (y < 32) {
          rgba[i] = (x * 4) & 0xFF;
          rgba[i + 1] = 255 - ((x * 4) & 0xFF);
          rgba[i + 2] = (y * 8) & 0xFF;
        } else if (y < 48) {
          rgba[i] = 220;
          rgba[i + 1] = (x * 3) & 0xFF;
          rgba[i + 2] = 40;
        } else {
          rgba[i] = (x * 2) & 0xFF;
          rgba[i + 2] = 230;
          rgba[i + 1] = (y * 4) & 0xFF;
        }
        rgba[i + 3] = 255;
      }
    }
    return rgba;
  }

  Future<Uint8List> renderRaw(EditState state) async {
    final renderer = PhotoRenderer(await ShaderLibrary.load(), LutRepository());
    try {
      final src = await imageFromRgba(sourceRgba(), w, h);
      await renderer.prepare(state);
      final out = renderer.render(src, state, applyGeometry: false, includeOverlays: false, includeLocal: false);
      expect(out.width, w);
      expect(out.height, h);
      final data = await out.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      final px = Uint8List.fromList(data!.buffer.asUint8List());
      src.dispose();
      out.dispose();
      return px;
    } finally {
      renderer.dispose();
    }
  }

  Future<Uint8List> decodePngRaw(List<int> bytes) async {
    final img = await (await ui.instantiateImageCodec(Uint8List.fromList(bytes))).getNextFrame();
    final data = await img.image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    img.image.dispose();
    return Uint8List.fromList(data!.buffer.asUint8List());
  }

  Future<Uint8List> encodePng(Uint8List raw) async {
    final img = await imageFromRgba(raw, w, h);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    return Uint8List.fromList(data!.buffer.asUint8List());
  }

  Future<void> check(String name, EditState state, {int tolerance = 2}) async {
    final raw = await renderRaw(state);
    final file = File('$goldenDir/$name.png');
    if (update) {
      file.createSync(recursive: true);
      file.writeAsBytesSync(await encodePng(raw));
      return;
    }
    expect(file.existsSync(), isTrue, reason: 'missing golden $name — run with LUMORA_UPDATE_GOLDENS=1');
    final expected = await decodePngRaw(file.readAsBytesSync());
    expect(expected.length, raw.length, reason: name);
    var maxDiff = 0;
    var sum = 0;
    for (var i = 0; i < raw.length; i++) {
      final d = (raw[i] - expected[i]).abs();
      if (d > maxDiff) maxDiff = d;
      sum += d;
    }
    expect(
      maxDiff,
      lessThanOrEqualTo(tolerance),
      reason:
          '$name: max channel diff $maxDiff (mean ${(sum / raw.length).toStringAsFixed(4)}) — '
          'regenerate goldens if the shader change was intended',
    );
  }

  testWidgets('develop shader: neutral state is a bit-exact identity', (tester) async {
    await tester.runAsync(() async {
      final raw = await renderRaw(EditState.initial);
      final src = sourceRgba();
      var maxDiff = 0;
      for (var i = 0; i < raw.length; i++) {
        final d = (raw[i] - src[i]).abs();
        if (d > maxDiff) maxDiff = d;
      }
      expect(maxDiff, 0, reason: 'a neutral recipe must not touch a pixel');
    });
  });

  testWidgets('develop shader: graded render matches its golden', (tester) async {
    await tester.runAsync(
      () => check(
        'shader_grade',
        EditState.initial.copyWith(
          adjustments: const Adjustments(
            exposure: 0.4,
            contrast: 0.3,
            highlights: -0.5,
            shadows: 0.35,
            temperature: 0.25,
            tint: -0.1,
            vibrance: 0.3,
            saturation: -0.15,
            fade: 0.2,
          ),
        ),
      ),
    );
  });

  testWidgets('develop shader: heavy lift keeps the ramp ordered (no clipping reversal)', (tester) async {
    await tester.runAsync(() async {
      final raw = await renderRaw(
        EditState.initial.copyWith(adjustments: const Adjustments(exposure: 1.5, shadows: 1, contrast: 0.6)),
      );
      // The grey ramp (top band) must stay monotonically non-decreasing in
      // luma left to right: tone curves never reverse order. Allow a ±2
      // per-channel wobble (6 on the sum) for multi-pass 8-bit rounding;
      // a real clipping inversion is tens of units.
      var prev = -1;
      for (var x = 0; x < w; x++) {
        final i = (8 * w + x) * 4;
        final luma = raw[i] + raw[i + 1] + raw[i + 2];
        expect(luma, greaterThanOrEqualTo(prev - 6), reason: 'ramp reversed at x=$x ($luma < $prev)');
        prev = luma;
      }
    });
  });
}
