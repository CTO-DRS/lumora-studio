import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/photo_editor/domain/preset_library.dart';
import 'package:lumora/features/photo_editor/domain/presets.dart';

void main() {
  const look = Adjustments(exposure: 0.3, contrast: 0.2, temperature: -0.1, lutId: 'builtin:teal_orange');
  const mine = Preset.custom(id: 'user:a', name: 'Mine', adjustments: look);

  group('Preset.remove', () {
    test('undoes apply for scalar sliders at any intensity', () {
      const base = Adjustments(exposure: 0.2, shadows: 0.1);
      for (final p in kBuiltInPresets) {
        for (final k in [0.3, 1.0]) {
          final applied = p.apply(base, intensity: k);
          final back = p.remove(applied, intensity: k);
          for (final param in AdjustmentParam.values) {
            if (param == AdjustmentParam.lutIntensity) continue;
            final target = param.read(p.adjustments);
            // Values clamped at a slider end cannot be recovered exactly.
            final applied2 = param.read(base) + (target - param.neutral) * k;
            if (applied2 < param.min || applied2 > param.max) continue;
            expect(param.read(back), closeTo(param.read(base), 1e-9), reason: '${p.id}.${param.name}');
          }
          expect(back.lutId, isNull);
        }
      }
    });
  });

  group('PresetLibrary', () {
    test('resolves built-in and custom ids', () {
      const lib = PresetLibrary(custom: [mine]);
      expect(lib.byId('noir')?.category, PresetCategory.bw);
      expect(lib.byId('user:a'), same(mine));
      expect(lib.byId('user:zzz'), isNull);
      expect(lib.byId(null), isNull);
    });

    test('favorites, rename, remove', () {
      var lib = const PresetLibrary(custom: [mine]);
      lib = lib.toggleFavorite('noir').toggleFavorite('user:a');
      expect(lib.presetsFor(null).map((p) => p.id), containsAll(['noir', 'user:a']));
      lib = lib.toggleFavorite('noir');
      expect(lib.isFavorite('noir'), isFalse);
      lib = lib.rename('user:a', 'Renamed');
      expect(lib.byId('user:a')!.nameEn, 'Renamed');
      expect(lib.byId('user:a')!.adjustments, look);
      lib = lib.remove('user:a');
      expect(lib.custom, isEmpty);
      expect(lib.favorites, isEmpty);
    });

    test('presetsFor returns a category or the user presets', () {
      const lib = PresetLibrary(custom: [mine]);
      expect(lib.presetsFor(PresetCategory.food).every((p) => p.category == PresetCategory.food), isTrue);
      expect(lib.presetsFor(PresetCategory.food), isNotEmpty);
      expect(lib.presetsFor(PresetCategory.custom), [mine]);
    });

    test('merge gives colliding presets new ids', () {
      const lib = PresetLibrary(custom: [mine]);
      var n = 0;
      final (merged, count) = lib.merge([
        mine,
        const Preset.custom(id: 'user:b', name: 'B', adjustments: look),
      ], () => 'user:new${n++}');
      expect(count, 2);
      expect(merged.custom.map((p) => p.id), ['user:a', 'user:new0', 'user:b']);
    });

    test('local persistence round-trips', () {
      final lib = const PresetLibrary(custom: [mine]).toggleFavorite('velvia');
      final back = decodeLibrary(encodeLibrary(lib));
      expect(back.custom.single.id, 'user:a');
      expect(back.custom.single.adjustments, look);
      expect(back.favorites, {'velvia'});
      expect(decodeLibrary('garbage').custom, isEmpty);
      expect(decodeLibrary(null).custom, isEmpty);
    });
  });

  group('preset files', () {
    test('export → import round-trips', () {
      final doc = encodePresetFile([mine]);
      final json = jsonDecode(doc) as Map<String, dynamic>;
      expect(json['format'], kPresetFileFormat);
      expect(json['version'], kPresetFileVersion);
      final back = decodePresetFile(doc);
      expect(back.single.nameEn, 'Mine');
      expect(back.single.adjustments, look);
      expect(back.single.isCustom, isTrue);
    });

    test('accepts a bare preset or a list', () {
      final single = jsonEncode(presetToJson(mine));
      expect(decodePresetFile(single).single.id, 'user:a');
      expect(decodePresetFile('[$single, $single]'), hasLength(2));
    });

    test('ids that are not user ids are replaced', () {
      final p = decodePresetFile(
        jsonEncode({
          'id': 'noir',
          'name': 'Fake',
          'adjustments': {'exposure': 0.1},
        }),
      ).single;
      expect(p.id, startsWith('user:'));
    });

    test('clamps out-of-range values', () {
      final p = decodePresetFile(
        jsonEncode({
          'name': 'Wild',
          'adjustments': {'exposure': 99, 'contrast': -7},
        }),
      ).single;
      expect(p.adjustments.exposure, 5);
      expect(p.adjustments.contrast, -1);
    });

    test('rejects malformed documents', () {
      for (final bad in [
        'not json',
        '42',
        '[]',
        '{"format":"other","presets":[]}',
        '{"format":"lumora.presets","version":99,"presets":[{"name":"x","adjustments":{}}]}',
        '{"presets":[{"adjustments":{}}]}',
        '{"presets":[{"name":"x"}]}',
        '{"presets":[1]}',
      ]) {
        expect(() => decodePresetFile(bad), throwsA(isA<PresetFormatException>()), reason: bad);
      }
    });
  });
}
