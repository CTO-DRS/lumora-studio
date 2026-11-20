import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/app.dart';
import 'package:lumora/core/providers.dart';
import 'package:lumora/features/photo_editor/domain/edit_state.dart';
import 'package:lumora/features/projects/data/app_database.dart';
import 'package:lumora/features/projects/data/project_repository.dart';
import 'package:material_ui/material_ui.dart' show Icons;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app boots to the home screen and lists saved projects', (tester) async {
    SharedPreferences.setMockInitialValues({'onboardingDone': true});
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await ProjectRepository(db).savePhoto(id: 'p1', name: 'Sunset', sourcePath: '/nope.jpg', state: EditState.initial);

    await tester.pumpWidget(
      ProviderScope(overrides: [appDatabaseProvider.overrideWithValue(db)], child: const LumoraApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lumora Studio'), findsWidgets);
    expect(find.text('Edit photo'), findsOneWidget);
    expect(find.text('Edit video'), findsOneWidget);
    expect(find.text('Sunset'), findsOneWidget);
    // Quick tools row.
    expect(find.text('Scan document'), findsOneWidget);
    expect(find.text('Batch edit', skipOffstage: false), findsOneWidget);
    // Drift streams keep timers alive; dispose the tree explicitly.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('first launch shows the tips, then the home screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(overrides: [appDatabaseProvider.overrideWithValue(db)], child: const LumoraApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text('100% on your device'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text('Edit photo'), findsWidgets);
    expect(find.text('Nothing here yet'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboardingDone'), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('unnamed projects get a dated title; empty filter shows the empty state', (tester) async {
    SharedPreferences.setMockInitialValues({'onboardingDone': true});
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    // Older versions stored the picked file name ("38624") as the name.
    await ProjectRepository(
      db,
    ).savePhoto(id: 'p1', name: '38624', sourcePath: '/x/38624.jpg', state: EditState.initial);
    await tester.pumpWidget(
      ProviderScope(overrides: [appDatabaseProvider.overrideWithValue(db)], child: const LumoraApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text('38624'), findsNothing);
    expect(find.textContaining('Photo · '), findsOneWidget);
    await tester.tap(find.byIcon(Icons.movie_outlined).last);
    await tester.pumpAndSettle();
    expect(find.text('Nothing here yet'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  test('rename, duplicate and autosave keep names', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = ProjectRepository(db);
    await repo.savePhoto(id: 'a', sourcePath: '/p/IMG_1.jpg', state: EditState.initial);
    var list = await repo.watchRecent().first;
    expect(list.single.name, '');
    expect(list.single.hasCustomName, isFalse);
    await repo.rename('a', '  Trip  ');
    await repo.savePhoto(
      id: 'a',
      sourcePath: '/p/IMG_1.jpg',
      state: const EditState(presetId: 'noir'),
    );
    list = await repo.watchRecent().first;
    expect(list.single.name, 'Trip');
    expect(list.single.hasCustomName, isTrue);
    final copy = await repo.duplicate('a', name: 'Trip (copy)');
    expect(copy, isNotNull);
    final edit = await repo.photoEdit(copy!);
    expect(edit?.presetId, 'noir');
    expect((await repo.watchRecent().first).length, 2);
    expect(await repo.duplicate('missing', name: 'x'), isNull);
    await db.close();
  });

  test('project repository round-trips a photo edit', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = ProjectRepository(db);
    const state = EditState(presetId: 'noir');
    await repo.savePhoto(id: 'x', name: 'n', sourcePath: '/a.jpg', state: state);
    final loaded = await repo.loadPhoto('x');
    expect(loaded?.$1, '/a.jpg');
    expect(loaded?.$2, state);
    await repo.delete('x');
    expect(await repo.loadPhoto('x'), isNull);
    await db.close();
  });
}
