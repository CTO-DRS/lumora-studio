import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/app.dart';
import 'package:lumora/core/providers.dart';
import 'package:lumora/features/photo_editor/domain/edit_state.dart';
import 'package:lumora/features/projects/data/app_database.dart';
import 'package:lumora/features/projects/data/project_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app boots to the home screen and lists saved projects', (tester) async {
    SharedPreferences.setMockInitialValues({});
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
    // Drift streams keep timers alive; dispose the tree explicitly.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
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
