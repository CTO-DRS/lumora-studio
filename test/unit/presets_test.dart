import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/photo_editor/domain/edit_state.dart';
import 'package:lumora/features/photo_editor/domain/geometry.dart';
import 'package:lumora/features/photo_editor/domain/layers.dart';
import 'package:lumora/features/photo_editor/domain/presets.dart';

void main() {
  group('Presets', () {
    test('ship at least 45 looks with unique ids and both languages', () {
      expect(kBuiltInPresets.length, greaterThanOrEqualTo(45));
      final ids = kBuiltInPresets.map((p) => p.id).toSet();
      expect(ids.length, kBuiltInPresets.length);
      for (final p in kBuiltInPresets) {
        expect(p.nameEn, isNotEmpty);
        expect(p.nameAr, isNotEmpty);
        expect(p.adjustments.isNeutral, isFalse, reason: p.id);
      }
      final builtInCategories = PresetCategory.values.where((c) => c != PresetCategory.custom);
      expect(builtInCategories.every((c) => kBuiltInPresets.any((p) => p.category == c)), isTrue);
      expect(kBuiltInPresets.any((p) => p.isCustom), isFalse);
    });

    test('every scalar stays within its slider range', () {
      for (final p in kBuiltInPresets) {
        for (final param in AdjustmentParam.values) {
          final v = param.read(p.adjustments);
          expect(v, inInclusiveRange(param.min, param.max), reason: '${p.id}.${param.name}');
        }
      }
    });

    test('intensity 0 leaves adjustments untouched (scalars)', () {
      const base = Adjustments(exposure: 0.4, contrast: 0.1);
      for (final p in kBuiltInPresets) {
        final out = p.apply(base, intensity: 0);
        for (final param in AdjustmentParam.values) {
          if (param == AdjustmentParam.lutIntensity) continue;
          expect(param.read(out), closeTo(param.read(base), 1e-9), reason: '${p.id}.${param.name}');
        }
      }
    });

    test('full intensity adds preset deltas on top of user edits', () {
      final preset = presetById('bright')!;
      final out = preset.apply(const Adjustments(exposure: 0.2));
      expect(out.exposure, closeTo(0.55, 1e-9));
      expect(out.shadows, closeTo(0.25, 1e-9));
    });

    test('LUT presets reference bundled LUTs', () {
      for (final p in kBuiltInPresets.where((p) => p.adjustments.lutId != null)) {
        expect(p.adjustments.lutId, startsWith('builtin:'));
      }
    });

    test('presetById', () {
      expect(presetById('noir')?.category, PresetCategory.bw);
      expect(presetById('nope'), isNull);
      expect(presetById(null), isNull);
    });
  });

  test('EditState JSON round trip (project save/restore)', () {
    final state = EditState(
      adjustments: kBuiltInPresets.first
          .apply(const Adjustments(), intensity: 0.7)
          .copyWith(
            curves: const CurveSet(master: [CurvePoint(0, 0.1), CurvePoint(0.5, 0.6), CurvePoint(1, 1)]),
            lutId: 'builtin:teal_orange',
          ),
      geometry: const GeometryState(cropLeft: 0.1, quarterTurns: 1, straightenDegrees: 3),
      layers: const [
        OverlayLayer.text(id: 't', text: 'مرحبا'),
        OverlayLayer.sticker(id: 's', glyph: '🔥'),
        OverlayLayer.drawing(
          id: 'd',
          strokes: [
            Stroke(points: [0, 0, 1, 1]),
          ],
        ),
      ],
      localAdjustments: const [LocalAdjustment(id: 'm', kind: MaskKind.radial)],
      presetId: 'auto_pop',
    );
    final json = jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>;
    expect(EditState.fromJson(json), state);
  });
}
