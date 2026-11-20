import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/video_editor/domain/crop_math.dart';
import 'package:lumora/features/video_editor/domain/look_keyframes.dart';
import 'package:lumora/features/video_editor/domain/video_project.dart';
import 'package:lumora/features/video_editor/engine/ffmpeg_command_builder.dart';

/// Tiny evaluator for the FFmpeg expressions we generate (if, lt, + - * /).
double evalExpr(String src, double t) {
  var i = 0;
  late double Function() expr;
  void skip() {
    while (i < src.length && src[i] == ' ') {
      i++;
    }
  }

  double number() {
    final m = RegExp(r'\d+(\.\d+)?').matchAsPrefix(src, i)!;
    i = m.end;
    return double.parse(m.group(0)!);
  }

  double factor() {
    skip();
    if (src.startsWith('if(', i)) {
      i += 3;
      final c = expr();
      i++; // ,
      final a = expr();
      i++; // ,
      final b = expr();
      i++; // )
      return c != 0 ? a : b;
    }
    if (src.startsWith('lt(', i)) {
      i += 3;
      final a = expr();
      i++;
      final b = expr();
      i++;
      return a < b ? 1 : 0;
    }
    if (src[i] == 'T') {
      i++;
      return t;
    }
    if (src[i] == '(') {
      i++;
      final v = expr();
      i++;
      return v;
    }
    if (src[i] == '-') {
      i++;
      return -factor();
    }
    return number();
  }

  double term() {
    var v = factor();
    while (i < src.length && (src[i] == '*' || src[i] == '/')) {
      final op = src[i++];
      final r = factor();
      v = op == '*' ? v * r : v / r;
    }
    return v;
  }

  expr = () {
    var v = term();
    while (i < src.length && (src[i] == '+' || src[i] == '-')) {
      final op = src[i++];
      final r = term();
      v = op == '+' ? v + r : v - r;
    }
    return v;
  };
  return expr();
}

void main() {
  const clip = VideoClip(id: 'c', path: '/v.mp4', sourceDurationMs: 10000, inMs: 1000, outMs: 9000);

  group('look keyframes', () {
    test('constant strength without keyframes', () {
      const p = VideoProject(lookIntensity: 0.4);
      expect(p.lookIntensityAt(0), 0.4);
      expect(p.lookIntensityExpression(), '0.4000');
    });

    test('linear interpolation and clamping at the ends', () {
      final p = const VideoProject().setKeyframe(4000, 1).setKeyframe(1000, 0).setKeyframe(6000, 0.5);
      expect(p.lookKeyframes.map((k) => k.timeMs), [1000, 4000, 6000]);
      expect(p.lookIntensityAt(0), 0);
      expect(p.lookIntensityAt(2500), closeTo(0.5, 1e-9));
      expect(p.lookIntensityAt(5000), closeTo(0.75, 1e-9));
      expect(p.lookIntensityAt(99999), 0.5);
      expect(p.hasAnimatedLook, isTrue);
    });

    test('setting near an existing keyframe replaces it; removal works', () {
      var p = const VideoProject().setKeyframe(1000, 0.2).setKeyframe(1050, 0.9);
      expect(p.lookKeyframes, hasLength(1));
      expect(p.keyframeNear(1000)?.intensity, 0.9);
      p = p.removeKeyframeNear(990);
      expect(p.lookKeyframes, isEmpty);
    });

    test('FFmpeg expression matches lookIntensityAt everywhere', () {
      final p = const VideoProject().setKeyframe(500, 0.1).setKeyframe(2000, 1).setKeyframe(3500, 0.3);
      final expr = p.lookIntensityExpression();
      for (var ms = 0; ms <= 5000; ms += 125) {
        expect(evalExpr(expr, ms / 1000), closeTo(p.lookIntensityAt(ms), 1e-3), reason: 't=$ms\n$expr');
      }
    });

    test('scaleLook lerps towards neutral', () {
      const look = Adjustments(exposure: 1, saturation: -1, lutId: 'x');
      final half = scaleLook(look, 0.5);
      expect(half.exposure, closeTo(0.5, 1e-9));
      expect(half.saturation, closeTo(-0.5, 1e-9));
      expect(half.lutIntensity, closeTo(0.5, 1e-9));
      expect(identical(scaleLook(look, 1), look), isTrue);
      expect(scaleLook(look, 0).exposure, 0);
    });
  });

  group('clip helpers', () {
    test('source time honours trim, speed and reverse', () {
      expect(sourceTimeAt(clip, 0), 1000);
      expect(sourceTimeAt(clip.copyWith(speed: 2), 1000), 3000);
      expect(sourceTimeAt(clip.copyWith(reversed: true), 1000), 8000);
      expect(sourceTimeAt(clip, 999999), 9000);
    });

    test('stabilisation smoothing range', () {
      expect(stabilizeSmoothing(0), 5);
      expect(stabilizeSmoothing(1), 40);
      expect(stabilizeSmoothing(0.5), 23);
    });
  });

  group('free-form crop', () {
    test('centred crops have the requested pixel aspect', () {
      for (final target in [1.0, 0.8, 9 / 16, 16 / 9]) {
        final r = centeredCrop(16 / 9, target);
        expect(cropAspect(r, 16 / 9), closeTo(target, 1e-9));
        expect(r.every((v) => v >= 0 && v <= 1), isTrue);
      }
    });

    test('dragging a corner keeps size limits and the locked aspect', () {
      var r = [0.0, 0.0, 1.0, 1.0];
      r = dragCropCorner(r, 2, -0.95, -0.95, frameAspect: 1);
      expect(r[2] - r[0], closeTo(kMinCrop, 1e-9));
      final locked = dragCropCorner(const [0.1, 0.1, 0.9, 0.9], 2, -0.2, 0, frameAspect: 16 / 9, targetAspect: 1);
      expect(cropAspect(locked, 16 / 9), closeTo(1, 1e-6));
      expect(locked[0], 0.1);
      expect(locked[1], 0.1);
    });

    test('moving the box stays inside the frame', () {
      final r = moveCrop(const [0.2, 0.2, 0.6, 0.7], 0.9, -0.9);
      expect(r, [closeTo(0.6, 1e-9), 0.0, closeTo(1, 1e-9), closeTo(0.5, 1e-9)]);
    });
  });

  group('FFmpeg commands', () {
    const builder = FfmpegCommandBuilder();
    const look = Adjustments(contrast: 0.3);

    String graph(List<String> args) => args[args.indexOf('-filter_complex') + 1];

    test('full-strength look is applied directly', () {
      final g = graph(builder.build(const VideoProject(clips: [clip], look: look), '/o.mp4'));
      expect(g, contains('eq=contrast'));
      expect(g, isNot(contains('blend=all_expr')));
    });

    test('partial or keyframed strength blends original and graded frames', () {
      final g = graph(builder.build(const VideoProject(clips: [clip], look: look, lookIntensity: 0.5), '/o.mp4'));
      expect(g, contains("blend=all_expr='A+(B-A)*(0.5000)'"));
      final animated = const VideoProject(clips: [clip], look: look).setKeyframe(0, 0).setKeyframe(2000, 1);
      expect(graph(builder.build(animated, '/o.mp4')), contains('if(lt(T,'));
      final off = graph(builder.build(const VideoProject(clips: [clip], look: look, lookIntensity: 0), '/o.mp4'));
      expect(off, isNot(contains('eq=contrast')));
    });

    test('stabilisation adds vidstabtransform right after trimming', () {
      final stab = clip.copyWith(stabilize: true, stabilizeStrength: 1);
      final g = graph(
        builder.build(
          VideoProject(clips: [stab]),
          '/o.mp4',
          assets: const ExportAssets(stabilizeFiles: {'c': '/tmp/s.trf'}),
        ),
      );
      expect(g, contains("setpts=PTS-STARTPTS,vidstabtransform=input='/tmp/s.trf':smoothing=40"));
      // Without the transforms file nothing is added.
      expect(graph(builder.build(VideoProject(clips: [stab]), '/o.mp4')), isNot(contains('vidstab')));
      final detect = FfmpegCommandBuilder.stabilizeDetectArgs(stab, '/tmp/s.trf');
      expect(detect, containsAllInOrder(['-ss', '1.000', '-t', '8.000', '-i', '/v.mp4', '-vf']));
      expect(detect[detect.indexOf('-vf') + 1], startsWith('vidstabdetect='));
      expect(detect.last, '-');
    });

    test('GIF uses a generated palette and loops', () {
      final args = FfmpegCommandBuilder.gifArgs('/in.mp4', '/out.gif', width: 320, fps: 10, maxMs: 5000);
      final g = args[args.indexOf('-filter_complex') + 1];
      expect(g, startsWith('fps=10,scale=320:-2'));
      expect(g, contains('palettegen'));
      expect(g, contains('[g1][gp]paletteuse'));
      expect(args, containsAllInOrder(['-t', '5.000', '-i', '/in.mp4', '-loop', '0', '/out.gif']));
    });

    test('frame grab seeks to the source time', () {
      expect(
        FfmpegCommandBuilder.frameArgs('/v.mp4', 2500, '/f.jpg'),
        containsAllInOrder(['-ss', '2.500', '-i', '/v.mp4', '-frames:v', '1']),
      );
    });
  });

  test('project JSON round-trips new fields', () {
    final p = VideoProject(clips: [clip.copyWith(stabilize: true)], lookIntensity: 0.7).setKeyframe(1000, 0.3);
    expect(VideoProject.fromJson(p.toJson()), p);
  });
}
