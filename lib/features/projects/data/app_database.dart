import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Saved editing projects. The edit recipe is stored as JSON so the source
/// media is never modified and every project can be reopened and re-edited.
@DataClassName('ProjectRow')
class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// `photo` or `video`.
  TextColumn get kind => text()();
  TextColumn get sourcePath => text()();
  TextColumn get thumbnailPath => text().nullable()();

  /// Serialized EditState / VideoProject.
  TextColumn get editJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Projects])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'lumora'));

  @override
  int get schemaVersion => 1;

  Stream<List<ProjectRow>> watchRecent({int limit = 50}) =>
      (select(projects)
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
            ..limit(limit))
          .watch();

  Future<ProjectRow?> byId(String id) => (select(projects)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsert(ProjectsCompanion row) => into(projects).insertOnConflictUpdate(row);

  Future<int> rename(String id, String name) =>
      (update(projects)..where((t) => t.id.equals(id))).write(ProjectsCompanion(name: Value(name)));

  Future<int> deleteById(String id) => (delete(projects)..where((t) => t.id.equals(id))).go();
}
