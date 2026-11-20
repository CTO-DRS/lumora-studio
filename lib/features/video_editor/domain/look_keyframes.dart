import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/photo_editor/domain/presets.dart';
import 'package:lumora/features/video_editor/domain/video_project.dart';

/// Look keyframes and per-clip timing helpers (pure, tested).
extension LookTimeline on VideoProject {
  List<LookKeyframe> get sortedKeyframes => [...lookKeyframes]..sort((a, b) => a.timeMs.compareTo(b.timeMs));

  bool get hasAnimatedLook => lookKeyframes.length > 1;

  /// Look strength at timeline time [ms].
  double lookIntensityAt(int ms) {
    final k = sortedKeyframes;
    if (k.isEmpty) return lookIntensity.clamp(0.0, 1.0);
    if (ms <= k.first.timeMs) return k.first.intensity;
    if (ms >= k.last.timeMs) return k.last.intensity;
    for (var i = 0; i < k.length - 1; i++) {
      final a = k[i];
      final b = k[i + 1];
      if (ms >= a.timeMs && ms <= b.timeMs) {
        final span = b.timeMs - a.timeMs;
        if (span == 0) return b.intensity;
        return a.intensity + (b.intensity - a.intensity) * (ms - a.timeMs) / span;
      }
    }
    return k.last.intensity;
  }

  /// Adds or replaces a keyframe at [ms] (within 100 ms counts as the same).
  VideoProject setKeyframe(int ms, double intensity) {
    final v = intensity.clamp(0.0, 1.0);
    final others = lookKeyframes.where((k) => (k.timeMs - ms).abs() > 100).toList();
    return copyWith(
      lookKeyframes: [...others, LookKeyframe(timeMs: ms, intensity: v)]..sort((a, b) => a.timeMs.compareTo(b.timeMs)),
    );
  }

  VideoProject removeKeyframeNear(int ms) =>
      copyWith(lookKeyframes: lookKeyframes.where((k) => (k.timeMs - ms).abs() > 100).toList());

  /// Keyframe within 100 ms of [ms], if any.
  LookKeyframe? keyframeNear(int ms) {
    for (final k in lookKeyframes) {
      if ((k.timeMs - ms).abs() <= 100) return k;
    }
    return null;
  }

  /// FFmpeg expression (variable `T`, seconds) for the look strength, or
  /// a constant. Used by the `blend` filter in fast export.
  String lookIntensityExpression() {
    final k = sortedKeyframes;
    String f(double v) => v.toStringAsFixed(4);
    if (k.isEmpty) return f(lookIntensity.clamp(0.0, 1.0));
    if (k.length == 1) return f(k.first.intensity);
    String seg(int i) {
      if (i >= k.length - 1) return f(k.last.intensity);
      final a = k[i];
      final b = k[i + 1];
      final t0 = a.timeMs / 1000;
      final t1 = b.timeMs / 1000;
      final lerp = t1 == t0
          ? f(b.intensity)
          : '${f(a.intensity)}+(${f(b.intensity - a.intensity)})*(T-${f(t0)})/${f(t1 - t0)}';
      return 'if(lt(T,${f(t1)}),$lerp,${seg(i + 1)})';
    }

    return 'if(lt(T,${f(k.first.timeMs / 1000)}),${f(k.first.intensity)},${seg(0)})';
  }
}

/// [look] scaled towards neutral by [k] (0 = no look, 1 = full look).
Adjustments scaleLook(Adjustments look, double k) {
  if (k >= 0.999) return look;
  return Preset(
    id: '_',
    nameEn: '',
    nameAr: '',
    category: PresetCategory.custom,
    adjustments: look,
  ).apply(Adjustments.neutral, intensity: k.clamp(0.0, 1.0));
}

/// Source time (ms) of a frame [localMs] into [clip] on the timeline.
int sourceTimeAt(VideoClip clip, int localMs) {
  final offset = (localMs * clip.speed).round();
  final t = clip.reversed ? clip.outMs - offset : clip.inMs + offset;
  return t.clamp(clip.inMs, clip.outMs);
}

/// vid.stab smoothing (frames) for a 0..1 strength.
int stabilizeSmoothing(double strength) => (5 + strength.clamp(0.0, 1.0) * 35).round();
