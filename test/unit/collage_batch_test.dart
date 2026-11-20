import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/batch/domain/batch_edit.dart';
import 'package:lumora/features/collage/domain/collage.dart';
import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/photo_editor/domain/auto_enhance.dart';
import 'package:lumora/features/photo_editor/domain/edit_state.dart';
import 'package:lumora/features/photo_editor/domain/finishing.dart';
import 'package:lumora/features/photo_editor/domain/geometry.dart';
import 'package:lumora/features/photo_editor/domain/presets.dart';

void main() {
  group('collage layouts', () {
    test('every layout tiles the unit square without overlaps', () {
      final ids = <String>{};
      for (final l in kCollageLayouts) {
        expect(ids.add(l.id), isTrue, reason: 'unique id ${l.id}');
        var area = 0.0;
        for (final c in l.cells) {
          expect(c.left, greaterThanOrEqualTo(0));
          expect(c.right, lessThanOrEqualTo(1 + 1e-9));
          expect(c.width, greaterThan(0));
          area += c.width * c.height;
        }
        // '5center' intentionally overlaps (a centred photo on a 2x2 grid).
        if (l.id != '5center') expect(area, closeTo(1, 1e-9), reason: l.id);
      }
    });

    test('layouts exist for 1 to 9 photos', () {
      for (var n = 1; n <= 9; n++) {
        final ls = layoutsFor(n);
        expect(ls, isNotEmpty);
        expect(ls.every((l) => l.cells.length >= n), isTrue);
      }
      expect(layoutById('nope'), kCollageLayouts.first);
    });

    test('cell rects respect margin and spacing', () {
      final left = cellRect(const UnitRect(0, 0, 0.5, 1), 1000, 500, spacing: 20, margin: 10);
      final right = cellRect(const UnitRect(0.5, 0, 1, 1), 1000, 500, spacing: 20, margin: 10);
      expect(left.left, 10);
      expect(left.top, 10);
      expect(left.height, 480);
      expect(right.left - (left.left + left.width), closeTo(20, 1e-9));
      expect(right.left + right.width, closeTo(990, 1e-9));
    });

    test('cover source fills the cell and pans within the image', () {
      final s = coverSource(4000, 3000, 100, 100, const CellTransform());
      expect((s.width, s.height), (3000, 3000));
      expect(s.left, 500);
      final zoomed = coverSource(4000, 3000, 100, 100, const CellTransform(scale: 2, panX: 1));
      expect(zoomed.width, 1500);
      expect(zoomed.left + zoomed.width, closeTo(4000, 1e-9));
      final tall = coverSource(1000, 1000, 50, 100, const CellTransform(panY: -1));
      expect(tall.width, 500);
      expect(tall.top, 0);
      expect(const CellTransform().copyWith(scale: 99, panX: -5).scale, 6);
    });

    test('output size keeps the aspect ratio', () {
      expect(collageOutputSize(1), (3000, 3000));
      expect(collageOutputSize(9 / 16), (1688, 3000));
      expect(collageOutputSize(16 / 9), (3000, 1688));
    });
  });

  group('batch recipe', () {
    test('preset only', () {
      final noir = presetById('noir')!;
      final e = buildBatchEdit(BatchRecipe(preset: noir, intensity: 0.5));
      expect(e.presetId, 'noir');
      expect(e.presetIntensity, 0.5);
      expect(e.adjustments.saturation, closeTo(-0.5, 1e-9));
    });

    test('copied edits keep the look but not the crop or AI pixels', () {
      const copied = EditState(
        adjustments: Adjustments(contrast: 0.4),
        geometry: GeometryState(cropRight: 0.5),
        frame: FrameSettings(style: FrameStyle.border),
        rasterPath: '/ai.png',
      );
      final e = buildBatchEdit(const BatchRecipe(copied: copied));
      expect(e.adjustments.contrast, 0.4);
      expect(e.geometry.isIdentity, isTrue);
      expect(e.rasterPath, isNull);
      expect(e.frame.style, FrameStyle.border);
    });

    test('auto enhance uses each photo statistics', () {
      // A dark, flat image gets brightened.
      final px = Uint8List(64 * 64 * 4);
      for (var i = 0; i < px.length; i += 4) {
        px[i] = 30 + (i ~/ 4) % 20;
        px[i + 1] = 30 + (i ~/ 4) % 20;
        px[i + 2] = 30 + (i ~/ 4) % 20;
        px[i + 3] = 255;
      }
      final stats = ImageStats.fromRgba(px, 64, 64);
      final e = buildBatchEdit(const BatchRecipe(autoEnhance: true), stats: stats);
      expect(e.adjustments.isNeutral, isFalse);
      expect(const BatchRecipe().isEmpty, isTrue);
    });
  });
}
