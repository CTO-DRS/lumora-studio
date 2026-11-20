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
    DateTime? createdAt,
    this.thumbnailPath,
  }) : createdAt = createdAt ?? updatedAt;

  final String id;
  final String name;
  final ProjectKind kind;
  final String sourcePath;
  final String? thumbnailPath;
  final DateTime updatedAt;
  final DateTime createdAt;

  /// Whether the user gave this project a real name. Older versions named
  /// projects after the picked file (e.g. "38624"), which is treated as
  /// unnamed so the UI can show a friendly, dated title instead.
  bool get hasCustomName {
    final n = name.trim();
    if (n.isEmpty) return false;
    final base = sourcePath.split(RegExp(r'[\\/]')).last;
    final stem = base.contains('.') ? base.substring(0, base.lastIndexOf('.')) : base;
    return n != stem;
  }
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
          createdAt: r.createdAt,
        ),
    ],
  );

  /// Saves a photo project. The name is only written for new projects (or
  /// when given), so a rename is never overwritten by an autosave.
  Future<void> savePhoto({
    required String id,
    required String sourcePath,
    required EditState state,
    String? name,
    String? thumbnailPath,
  }) => _save(id, name, ProjectKind.photo, sourcePath, jsonEncode(state.toJson()), thumbnailPath);

  Future<void> saveVideo({required String id, required VideoProject project, String? name, String? thumbnailPath}) =>
      _save(
        id,
        name,
        ProjectKind.video,
        project.clips.isEmpty ? '' : project.clips.first.path,
        jsonEncode(project.toJson()),
        thumbnailPath,
      );

  Future<void> _save(String id, String? name, ProjectKind kind, String source, String json, String? thumb) async {
    final existing = await _db.byId(id);
    final now = DateTime.now();
    await _db.upsert(
      ProjectsCompanion(
        id: Value(id),
        name: Value(name ?? existing?.name ?? ''),
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

  Future<void> rename(String id, String name) => _db.rename(id, name.trim());

  /// Copies project [id] (same media, same edits) and returns the new id.
  Future<String?> duplicate(String id, {required String name}) async {
    final row = await _db.byId(id);
    if (row == null) return null;
    final copyId = newId();
    final now = DateTime.now();
    await _db.upsert(
      ProjectsCompanion(
        id: Value(copyId),
        name: Value(name),
        kind: Value(row.kind),
        sourcePath: Value(row.sourcePath),
        thumbnailPath: Value(row.thumbnailPath),
        editJson: Value(row.editJson),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    return copyId;
  }

  /// Edit recipe of a photo project, e.g. to copy its look.
  Future<EditState?> photoEdit(String id) async => (await loadPhoto(id))?.$2;
}
