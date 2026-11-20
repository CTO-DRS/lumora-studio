import 'dart:math' as math;

import 'package:lumora/features/video_editor/domain/video_project.dart';

/// Pure timeline operations. All return a new [VideoProject].
extension TimelineOps on VideoProject {
  /// Effective duration of a transition between clip [i] and the next.
  int transitionAfter(int i) {
    if (i >= clips.length - 1) return 0;
    final c = clips[i];
    if (c.transitionOut == TransitionKind.none) return 0;
    final maxT = math.min(c.durationMs, clips[i + 1].durationMs) ~/ 2;
    return math.min(c.transitionMs, maxT);
  }

  /// Total output duration (transitions overlap neighbouring clips).
  int get totalDurationMs {
    var t = 0;
    for (var i = 0; i < clips.length; i++) {
      t += clips[i].durationMs - transitionAfter(i);
    }
    return math.max(0, t);
  }

  /// Timeline start of every clip.
  List<int> get clipStarts {
    final out = <int>[];
    var t = 0;
    for (var i = 0; i < clips.length; i++) {
      out.add(t);
      t += clips[i].durationMs - transitionAfter(i);
    }
    return out;
  }

  /// Index of the clip under timeline time [ms] and the local offset in it.
  (int, int)? clipAt(int ms) {
    final starts = clipStarts;
    for (var i = clips.length - 1; i >= 0; i--) {
      if (ms >= starts[i]) {
        return (i, math.min(ms - starts[i], clips[i].durationMs));
      }
    }
    return null;
  }

  /// Splits the clip under [ms] into two clips. No-op near clip edges.
  VideoProject splitAt(int ms, {required String newId}) {
    final hit = clipAt(ms);
    if (hit == null) return this;
    final (index, local) = hit;
    final c = clips[index];
    if (local < 100 || c.durationMs - local < 100) return this;
    final sourceOffset = (local * c.speed).round();
    final VideoClip first;
    final VideoClip second;
    if (c.reversed) {
      // Reversed clips play from outMs backwards.
      final cut = c.outMs - sourceOffset;
      first = c.copyWith(inMs: cut, transitionOut: TransitionKind.none);
      second = c.copyWith(id: newId, outMs: cut);
    } else {
      final cut = c.inMs + sourceOffset;
      first = c.copyWith(outMs: cut, transitionOut: TransitionKind.none);
      second = c.copyWith(id: newId, inMs: cut);
    }
    final list = [...clips]
      ..removeAt(index)
      ..insertAll(index, [first, second]);
    return copyWith(clips: list);
  }

  VideoProject trimClip(String id, {int? inMs, int? outMs}) => _update(id, (c) {
    final i = (inMs ?? c.inMs).clamp(0, c.sourceDurationMs - 100);
    final o = (outMs ?? c.outMs).clamp(i + 100, c.sourceDurationMs);
    return c.copyWith(inMs: i, outMs: o);
  });

  VideoProject setSpeed(String id, double speed) => _update(id, (c) => c.copyWith(speed: speed.clamp(0.25, 4.0)));

  VideoProject toggleReverse(String id) => _update(id, (c) => c.copyWith(reversed: !c.reversed));

  VideoProject rotateClip(String id) => _update(id, (c) => c.copyWith(quarterTurns: (c.quarterTurns + 1) % 4));

  VideoProject cropClip(String id, List<double> crop) => _update(id, (c) => c.copyWith(crop: crop));

  VideoProject setTransition(String id, TransitionKind kind, {int? ms}) =>
      _update(id, (c) => c.copyWith(transitionOut: kind, transitionMs: ms ?? c.transitionMs));

  VideoProject setClipVolume(String id, double v) => _update(id, (c) => c.copyWith(volume: v.clamp(0.0, 2.0)));

  VideoProject removeClip(String id) => copyWith(clips: clips.where((c) => c.id != id).toList());

  VideoProject duplicateClip(String id, {required String newId}) {
    final i = clips.indexWhere((c) => c.id == id);
    if (i < 0) return this;
    final list = [...clips]..insert(i + 1, clips[i].copyWith(id: newId));
    return copyWith(clips: list);
  }

  /// Moves a clip (merge/reorder) from [from] to [to].
  VideoProject moveClip(int from, int to) {
    if (from == to || from < 0 || from >= clips.length) return this;
    final list = [...clips];
    final c = list.removeAt(from);
    list.insert(to.clamp(0, list.length), c);
    return copyWith(clips: list);
  }

  VideoProject appendClips(List<VideoClip> more) => copyWith(clips: [...clips, ...more]);

  VideoProject _update(String id, VideoClip Function(VideoClip) f) =>
      copyWith(clips: [for (final c in clips) c.id == id ? f(c) : c]);
}
