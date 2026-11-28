import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/photo_editor/domain/edit_state.dart';
import 'package:lumora/features/projects/data/app_database.dart';
import 'package:lumora/features/projects/data/project_repository.dart';
import 'package:lumora/features/video_editor/domain/video_project.dart';

/// C3 fuzz gate for the project store: whatever ends up in the edit_json
/// column — a corrupt write, a truncated autosave, a recipe from an older
/// app version — loading must never throw, hang or take the store down. It
/// yields the project or null, and the error goes to the crash log (the
/// recovery path pinned by project_repository_test.dart).
void main() {
  late AppDatabase db;
  late ProjectRepository repo;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ProjectRepository(db);
  });
  tearDown(() => db.close());

  final rng = Random(20261128);

  Future<void> seedRaw(String id, String kind, String json) async {
    final now = DateTime.now();
    await db.upsert(
      ProjectsCompanion(
        id: Value(id),
        name: const Value(''),
        kind: Value(kind),
        sourcePath: const Value('/src'),
        editJson: Value(json),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  /// Loads [id] as [kind]; the only allowed outcomes are a project or null.
  Future<void> expectBounded(String id, String kind) async {
    if (kind == 'photo') {
      await repo.loadPhoto(id);
    } else {
      await repo.loadVideo(id);
    }
  }

  String validPhotoJson() => jsonEncode(EditState.initial.copyWith(presetIntensity: 0.5).toJson());
  String validVideoJson() => jsonEncode(
    const VideoProject(
      clips: [VideoClip(id: 'c1', path: '/v.mp4', sourceDurationMs: 4000, outMs: 4000)],
      texts: [VideoText(id: 't1', text: 'أهلاً')],
    ).toJson(),
  );

  const alphabet =
      '{}[]",:0123456789.eE+-truefalsn \\✓أبج\t\n\r'
      '\$\u0000&#/%';

  String garbage() {
    final len = 1 + rng.nextInt(512);
    return String.fromCharCodes(List.generate(len, (_) => alphabet.codeUnitAt(rng.nextInt(alphabet.length))));
  }

  String mutateChar(String s) {
    final i = rng.nextInt(s.length);
    final c = alphabet.codeUnitAt(rng.nextInt(alphabet.length));
    return s.substring(0, i) + String.fromCharCode(c) + s.substring(i + 1);
  }

  test('valid seeds round-trip (sweep baseline)', () async {
    await seedRaw('okp', 'photo', validPhotoJson());
    await seedRaw('okv', 'video', validVideoJson());
    final p = await repo.loadPhoto('okp');
    final v = await repo.loadVideo('okv');
    expect(p, isNotNull);
    expect(p!.$2.presetIntensity, 0.5);
    expect(v, isNotNull);
    expect(v!.clips.single.id, 'c1');
    expect(v.texts.single.text, 'أهلاً');
  });

  test('400 random garbage payloads never throw', () async {
    for (var i = 0; i < 400; i++) {
      final kind = i.isEven ? 'photo' : 'video';
      await seedRaw('fz', kind, garbage());
      await expectBounded('fz', kind);
    }
  });

  test('every truncation point of a valid photo recipe never throws', () async {
    final json = validPhotoJson();
    for (var i = 0; i < json.length; i++) {
      await seedRaw('fz', 'photo', json.substring(0, i));
      await expectBounded('fz', 'photo');
    }
  });

  test('every truncation point of a valid video recipe never throws', () async {
    final json = validVideoJson();
    for (var i = 0; i < json.length; i++) {
      await seedRaw('fz', 'video', json.substring(0, i));
      await expectBounded('fz', 'video');
    }
  });

  test('400 single-character mutations of valid recipes never throw', () async {
    final photo = validPhotoJson();
    final video = validVideoJson();
    for (var i = 0; i < 400; i++) {
      final kind = i.isEven ? 'photo' : 'video';
      final mutated = mutateChar(kind == 'photo' ? photo : video);
      await seedRaw('fz', kind, mutated);
      await expectBounded('fz', kind);
    }
  });

  test('wrong-typed fields and unknown keys never throw', () async {
    final photo = EditState.initial.toJson();
    final video = const VideoProject().toJson();
    final variants = <(String, Map<String, dynamic>)>[
      ('photo', {...photo, 'presetIntensity': 'lots'}),
      ('photo', {...photo, 'adjustments': 42}),
      ('photo', {...photo, 'layers': 'yes'}),
      (
        'photo',
        {
          ...photo,
          'history': [1, 2, 3],
        },
      ),
      (
        'photo',
        {
          ...photo,
          'totallyUnknown': {'x': 1},
        },
      ),
      ('video', {...video, 'clips': 42}),
      (
        'video',
        {
          ...video,
          'clips': [42],
        },
      ),
      (
        'video',
        {
          ...video,
          'clips': [<String, dynamic>{}],
        },
      ),
      ('video', {...video, 'texts': 'captions'}),
      ('video', {...video, 'music': 7}),
      ('video', {...video, 'look': 'vivid'}),
      ('video', {...video, 'fps': 'thirty'}),
      (
        'video',
        {
          ...video,
          'aspect': [0, 0],
        },
      ),
      (
        'video',
        {
          ...video,
          'lookKeyframes': {'t': 1},
        },
      ),
    ];
    for (final (i, v) in variants.indexed) {
      await seedRaw('fz$i', v.$1, jsonEncode(v.$2));
      await expectBounded('fz$i', v.$1);
    }
    // Random top-level key corruptions of the video recipe.
    final keys = video.keys.toList();
    for (var i = 0; i < 100; i++) {
      final corrupted = Map<String, dynamic>.from(video);
      corrupted[keys[rng.nextInt(keys.length)]] = rng.nextBool() ? garbage() : rng.nextInt(1000);
      await seedRaw('fz', 'video', jsonEncode(corrupted));
      await expectBounded('fz', 'video');
    }
  });

  test('pathological payloads stay bounded', () async {
    final deep = '[' * 20000 + ']' * 20000;
    final cases = <String>[
      deep,
      '{"a":$deep}',
      '1e999999',
      '{"x": 1e999999}',
      '"${'a' * 1000000}"',
      '{"k":1,${List.generate(2000, (i) => '"k$i":$i').join(',')}}',
      '{"speed": 0.0000000000000000000000001}',
    ];
    for (final (i, c) in cases.indexed) {
      final kind = i.isEven ? 'photo' : 'video';
      await seedRaw('fz', kind, c);
      await expectBounded('fz', kind);
    }
  });

  test('the store still round-trips after the sweeps', () async {
    await seedRaw('okp', 'photo', validPhotoJson());
    expect((await repo.loadPhoto('okp'))!.$2.presetIntensity, 0.5);
    await seedRaw('okv', 'video', validVideoJson());
    expect((await repo.loadVideo('okv'))!.clips.single.id, 'c1');
  });
}
