import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:lumora/features/photo_editor/domain/edit_state.dart';
import 'package:lumora/features/projects/data/app_database.dart';
import 'package:lumora/features/video_editor/domain/video_project.dart';
import 'package:uuid/uuid.dart';

enum ProjectKind { photo, video }

class ProjectSummary {
  const ProjectSummary({
    required this.id,
    required this.name,
    required this.kind,
    required this.sourcePath,
    required this.updatedAt,
    this.thumbnailPath,
  });

  final String id;
  final String name;
  final ProjectKind kind;
  final String sourcePath;
  final String? thumbnailPath;
  final DateTime updatedAt;
}

/// Saves and restores photo/video projects.
class ProjectRepository {
  ProjectRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  String newId() => _uuid.v4();

  Stream<List<ProjectSummary>> watchRecent() => _db.watchRecent().map(
    (rows) => [
      for (final r in rows)
        ProjectSummary(
          id: r.id,
          name: r.name,
          kind: r.kind == 'video' ? ProjectKind.video : ProjectKind.photo,
          sourcePath: r.sourcePath,
          thumbnailPath: r.thumbnailPath,
          updatedAt: r.updatedAt,
        ),
    ],
  );

  Future<void> savePhoto({
    required String id,
    required String name,
    required String sourcePath,
    required EditState state,
    String? thumbnailPath,
  }) => _save(id, name, ProjectKind.photo, sourcePath, jsonEncode(state.toJson()), thumbnailPath);

  Future<void> saveVideo({
    required String id,
    required String name,
    required VideoProject project,
    String? thumbnailPath,
  }) => _save(
    id,
    name,
    ProjectKind.video,
    project.clips.isEmpty ? '' : project.clips.first.path,
    jsonEncode(project.toJson()),
    thumbnailPath,
  );

  Future<void> _save(String id, String name, ProjectKind kind, String source, String json, String? thumb) async {
    final existing = await _db.byId(id);
    final now = DateTime.now();
    await _db.upsert(
      ProjectsCompanion(
        id: Value(id),
        name: Value(name),
        kind: Value(kind.name),
        sourcePath: Value(source),
        thumbnailPath: Value(thumb ?? existing?.thumbnailPath),
        editJson: Value(json),
        createdAt: Value(existing?.createdAt ?? now),
        updatedAt: Value(now),
      ),
    );
  }

  Future<(String, EditState)?> loadPhoto(String id) async {
    final row = await _db.byId(id);
    if (row == null) return null;
    return (row.sourcePath, EditState.fromJson(jsonDecode(row.editJson) as Map<String, dynamic>));
  }

  Future<VideoProject?> loadVideo(String id) async {
    final row = await _db.byId(id);
    if (row == null) return null;
    return VideoProject.fromJson(jsonDecode(row.editJson) as Map<String, dynamic>);
  }

  Future<void> delete(String id) => _db.deleteById(id);
}
