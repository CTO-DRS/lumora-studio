import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/photo_editor/domain/edit_state.dart';
import 'package:lumora/features/projects/data/app_database.dart';
import 'package:lumora/features/projects/data/project_repository.dart';

/// C3 recovery: a corrupt stored recipe must never crash the app — the load
/// returns null and the error goes to the crash log instead.
void main() {
  late AppDatabase db;
  late ProjectRepository repo;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ProjectRepository(db);
  });
  tearDown(() => db.close());

  test('photo round-trip: save then load restores the exact edit', () async {
    final edit = EditState.initial.copyWith(presetIntensity: 0.5);
    await repo.savePhoto(id: 'p1', sourcePath: '/a.jpg', state: edit);
    final loaded = await repo.loadPhoto('p1');
    expect(loaded, isNotNull);
    expect(loaded!.$1, '/a.jpg');
    expect(loaded.$2.presetIntensity, 0.5);
  });

  test('corrupt photo recipe loads as null, no throw', () async {
    final now = DateTime.now();
    await db.upsert(
      ProjectsCompanion(
        id: const Value('bad1'),
        name: const Value(''),
        kind: const Value('photo'),
        sourcePath: const Value('/b.jpg'),
        editJson: const Value('{not json'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    expect(await repo.loadPhoto('bad1'), isNull);
  });

  test('corrupt video recipe loads as null, no throw', () async {
    final now = DateTime.now();
    await db.upsert(
      ProjectsCompanion(
        id: const Value('bad2'),
        name: const Value(''),
        kind: const Value('video'),
        sourcePath: const Value('/c.mp4'),
        editJson: const Value('{"clips": 42}'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    expect(await repo.loadVideo('bad2'), isNull);
  });

  test('unknown id loads as null', () async {
    expect(await repo.loadPhoto('nope'), isNull);
    expect(await repo.loadVideo('nope'), isNull);
  });
}
