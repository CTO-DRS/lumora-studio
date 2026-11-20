import 'dart:async';

import 'package:gal/gal.dart';
import 'package:lumora/core/providers.dart';
import 'package:lumora/features/photo_editor/data/preset_store.dart';
import 'package:lumora/features/photo_editor/domain/edit_history.dart';
import 'package:lumora/features/photo_editor/engine/photo_renderer.dart';
import 'package:lumora/features/video_editor/domain/look_keyframes.dart';
import 'package:lumora/features/video_editor/domain/timeline_ops.dart';
import 'package:lumora/features/video_editor/domain/video_project.dart';
import 'package:lumora/features/video_editor/engine/video_engine.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'video_editor_controller.g.dart';

class VideoEditorState {
  const VideoEditorState({
    required this.history,
    this.projectId,
    this.selectedClipId,
    this.selectedTextId,
    this.playheadMs = 0,
    this.thumbnails = const {},
    this.busy = false,
    this.progress,
    this.error,
  });

  final EditHistory<VideoProject> history;
  final String? projectId;
  final String? selectedClipId;
  final String? selectedTextId;
  final int playheadMs;
  final Map<String, List<String>> thumbnails;
  final bool busy;
  final double? progress;
  final String? error;

  VideoProject get project => history.present;

  VideoClip? get selectedClip => project.clips.where((c) => c.id == selectedClipId).firstOrNull;

  VideoEditorState copyWith({
    EditHistory<VideoProject>? history,
    String? projectId,
    String? Function()? selectedClipId,
    String? Function()? selectedTextId,
    int? playheadMs,
    Map<String, List<String>>? thumbnails,
    bool? busy,
    double? Function()? progress,
    String? Function()? error,
  }) => VideoEditorState(
    history: history ?? this.history,
    projectId: projectId ?? this.projectId,
    selectedClipId: selectedClipId != null ? selectedClipId() : this.selectedClipId,
    selectedTextId: selectedTextId != null ? selectedTextId() : this.selectedTextId,
    playheadMs: playheadMs ?? this.playheadMs,
    thumbnails: thumbnails ?? this.thumbnails,
    busy: busy ?? this.busy,
    progress: progress != null ? progress() : this.progress,
    error: error != null ? error() : this.error,
  );
}

const _uuid = Uuid();

@riverpod
class VideoEditorController extends _$VideoEditorController {
  @override
  VideoEditorState build() => VideoEditorState(history: EditHistory(const VideoProject()));

  VideoEngine get _engine => ref.read(videoEngineProvider);

  Future<void> openFiles(List<String> paths) async {
    state = VideoEditorState(
      history: EditHistory(const VideoProject()),
      projectId: ref.read(projectRepositoryProvider).newId(),
    );
    await addClips(paths);
    final first = state.project.clips.firstOrNull;
    if (first != null && first.sourceHeight > first.sourceWidth) {
      _set(state.project.copyWith(aspect: VideoAspect.portrait));
    }
    state = state.copyWith(history: EditHistory(state.project));
  }

  Future<void> openProject(String id) async {
    final project = await ref.read(projectRepositoryProvider).loadVideo(id);
    if (project == null) return;
    state = VideoEditorState(history: EditHistory(project), projectId: id);
    for (final c in project.clips) {
      unawaited(_loadThumbs(c));
    }
  }

  Future<void> addClips(List<String> paths) async {
    state = state.copyWith(busy: true);
    try {
      final clips = <VideoClip>[];
      for (final path in paths) {
        final info = await _engine.probe(path);
        clips.add(
          VideoClip(
            id: _uuid.v4(),
            path: path,
            sourceDurationMs: info.durationMs,
            outMs: info.durationMs,
            hasAudio: info.hasAudio,
            sourceWidth: info.width,
            sourceHeight: info.height,
          ),
        );
      }
      _set(state.project.appendClips(clips));
      for (final c in clips) {
        unawaited(_loadThumbs(c));
      }
      if (state.selectedClipId == null && clips.isNotEmpty) select(clips.first.id);
    } on Object catch (e) {
      state = state.copyWith(error: () => '$e');
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> _loadThumbs(VideoClip c) async {
    try {
      final thumbs = await _engine.thumbnails(c.path, c.sourceDurationMs);
      state = state.copyWith(thumbnails: {...state.thumbnails, c.path: thumbs});
    } on Object catch (e) {
      debugPrint('thumbnails failed: $e');
    }
  }

  void _set(VideoProject p, {bool live = false}) =>
      state = state.copyWith(history: live ? state.history.replace(p) : state.history.push(p));

  void update(VideoProject Function(VideoProject) f, {bool live = false}) => _set(f(state.project), live: live);

  void commit() => state = state.copyWith(history: state.history.commit());
  void undo() => state = state.copyWith(history: state.history.undo());
  void redo() => state = state.copyWith(history: state.history.redo());

  void select(String? clipId) => state = state.copyWith(selectedClipId: () => clipId);
  void selectText(String? id) => state = state.copyWith(selectedTextId: () => id);

  void seek(int ms) => state = state.copyWith(playheadMs: ms.clamp(0, state.project.totalDurationMs));

  void splitAtPlayhead() => update((p) => p.splitAt(state.playheadMs, newId: _uuid.v4()));

  void applyPreset(String? id) {
    final preset = ref.read(presetLibraryControllerProvider).byId(id);
    update(
      (p) => p.copyWith(
        presetId: id,
        look: preset == null ? p.look.copyWith(lutId: null) : preset.apply(const VideoProject().look),
      ),
    );
  }

  String addText(String text) {
    final id = _uuid.v4();
    final start = state.playheadMs;
    update(
      (p) => p.copyWith(
        texts: [
          ...p.texts,
          VideoText(id: id, text: text, startMs: start, endMs: start + 3000),
        ],
      ),
    );
    selectText(id);
    return id;
  }

  void updateText(String id, VideoText Function(VideoText) f, {bool live = false}) =>
      update((p) => p.copyWith(texts: [for (final t in p.texts) t.id == id ? f(t) : t]), live: live);

  void removeText(String id) {
    update((p) => p.copyWith(texts: p.texts.where((t) => t.id != id).toList()));
    selectText(null);
  }

  // ------------------------------------------------- look strength / keys

  void setLookIntensity(double v, {bool live = false}) {
    final ms = state.playheadMs;
    if (state.project.lookKeyframes.isEmpty) {
      update((p) => p.copyWith(lookIntensity: v.clamp(0.0, 1.0)), live: live);
    } else {
      update((p) => p.setKeyframe(ms, v), live: live);
    }
  }

  /// Adds a keyframe at the playhead with the current strength, or removes
  /// the one already there.
  void toggleKeyframeAtPlayhead() {
    final ms = state.playheadMs;
    final p = state.project;
    if (p.keyframeNear(ms) != null) {
      update((p) => p.removeKeyframeNear(ms));
    } else {
      update((p) => p.setKeyframe(ms, p.lookIntensityAt(ms)));
    }
  }

  void clearKeyframes() => update((p) => p.copyWith(lookKeyframes: const []));

  // --------------------------------------------------------- per clip

  void setStabilize(String clipId, {required bool enabled, double? strength}) => update(
    (p) => p.copyWith(
      clips: [
        for (final c in p.clips)
          c.id == clipId ? c.copyWith(stabilize: enabled, stabilizeStrength: strength ?? c.stabilizeStrength) : c,
      ],
    ),
  );

  /// Saves the frame under the playhead as a photo; returns its path.
  Future<String?> extractFrame() async {
    final hit = state.project.clipAt(state.playheadMs);
    if (hit == null) return null;
    final (index, local) = hit;
    try {
      final path = await _engine.extractFrame(state.project.clips[index], local);
      try {
        if (await Gal.requestPermission()) await Gal.putImage(path, album: 'Lumora');
      } on Object catch (e) {
        debugPrint('gallery: $e');
      }
      return path;
    } on Object catch (e) {
      state = state.copyWith(error: () => '$e');
      return null;
    }
  }

  Future<String?> exportGif({int width = 480, int fps = 12}) async {
    state = state.copyWith(busy: true, progress: () => 0, error: () => null);
    try {
      final out = await _engine.exportGif(
        state.project,
        width: width,
        fps: fps,
        maxMs: 30000,
        onProgress: (v) => state = state.copyWith(progress: () => v),
      );
      try {
        if (await Gal.requestPermission()) await Gal.putImage(out, album: 'Lumora');
      } on Object catch (e) {
        debugPrint('gallery: $e');
      }
      return out;
    } on Object catch (e) {
      state = state.copyWith(error: () => '$e');
      return null;
    } finally {
      state = state.copyWith(busy: false, progress: () => null);
    }
  }

  void setMusic(String? path) =>
      update((p) => path == null ? p.copyWith(music: null) : p.copyWith(music: AudioTrack(path: path)));

  Future<String?> export(VideoExportQuality quality) async {
    state = state.copyWith(busy: true, progress: () => 0, error: () => null);
    PhotoRenderer? renderer;
    try {
      renderer = quality == VideoExportQuality.studio ? await createPhotoRenderer(ref.read) : null;
      final out = await _engine.export(
        state.project,
        quality: quality,
        renderer: renderer,
        onProgress: (v) => state = state.copyWith(progress: () => v),
      );
      try {
        if (await Gal.requestPermission()) await Gal.putVideo(out, album: 'Lumora');
      } on Object catch (e) {
        debugPrint('gallery: $e');
      }
      await save();
      return out;
    } on Object catch (e) {
      state = state.copyWith(error: () => '$e');
      return null;
    } finally {
      renderer?.dispose();
      state = state.copyWith(busy: false, progress: () => null);
    }
  }

  Future<void> cancelExport() => _engine.cancel();

  Future<void> save() async {
    final id = state.projectId;
    if (id == null || state.project.clips.isEmpty) return;
    final first = state.project.clips.first;
    final thumbs = state.thumbnails[first.path];
    await ref
        .read(projectRepositoryProvider)
        .saveVideo(
          id: id,
          project: state.project,
          thumbnailPath: thumbs == null || thumbs.isEmpty ? null : thumbs.first,
        );
  }
}
