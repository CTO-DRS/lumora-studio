import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/video_editor/domain/timeline_ops.dart';
import 'package:lumora/features/video_editor/domain/video_project.dart';
import 'package:lumora/features/video_editor/engine/ffmpeg_command_builder.dart';

VideoClip _clip(String id, int ms, {bool audio = true}) =>
    VideoClip(id: id, path: '/v/$id.mp4', sourceDurationMs: ms, outMs: ms, hasAudio: audio);

void main() {
  group('Timeline ops', () {
    final p = VideoProject(clips: [_clip('a', 4000), _clip('b', 6000)]);

    test('durations and clip lookup', () {
      expect(p.totalDurationMs, 10000);
      expect(p.clipStarts, [0, 4000]);
      expect(p.clipAt(4500), (1, 500));
      expect(p.clipAt(0), (0, 0));
    });

    test('speed changes timeline length', () {
      final fast = p.setSpeed('a', 2);
      expect(fast.clips.first.durationMs, 2000);
      expect(fast.totalDurationMs, 8000);
      expect(p.setSpeed('a', 100).clips.first.speed, 4);
    });

    test('split creates two contiguous clips', () {
      final s = p.splitAt(1500, newId: 'a2');
      expect(s.clips.length, 3);
      expect(s.clips[0].outMs, 1500);
      expect(s.clips[1].id, 'a2');
      expect(s.clips[1].inMs, 1500);
      expect(s.totalDurationMs, 10000);
      expect(p.splitAt(20, newId: 'x').clips.length, 2, reason: 'too close to edge');
    });

    test('split respects speed and reverse', () {
      final s = p.setSpeed('b', 2).splitAt(4000 + 1000, newId: 'b2');
      expect(s.clips[1].outMs, 2000);
      final r = p.toggleReverse('a').splitAt(1000, newId: 'r2');
      expect(r.clips[0].inMs, 3000);
      expect(r.clips[1].outMs, 3000);
    });

    test('trim clamps', () {
      final t = p.trimClip('a', inMs: -5, outMs: 99999);
      expect(t.clips.first.inMs, 0);
      expect(t.clips.first.outMs, 4000);
      final t2 = p.trimClip('a', inMs: 3990);
      expect(t2.clips.first.inMs, 3900);
    });

    test('transitions overlap clips', () {
      final t = p.setTransition('a', TransitionKind.fade, ms: 1000);
      expect(t.transitionAfter(0), 1000);
      expect(t.totalDurationMs, 9000);
      expect(t.setTransition('a', TransitionKind.fade, ms: 9000).transitionAfter(0), 2000);
    });

    test('move, duplicate, remove', () {
      expect(p.moveClip(0, 1).clips.map((c) => c.id), ['b', 'a']);
      expect(p.duplicateClip('a', newId: 'c').clips.map((c) => c.id), ['a', 'c', 'b']);
      expect(p.removeClip('a').clips.single.id, 'b');
      expect(p.rotateClip('a').rotateClip('a').clips.first.quarterTurns, 2);
    });
  });

  group('FfmpegCommandBuilder', () {
    const builder = FfmpegCommandBuilder();

    test('output size honours aspect and is even', () {
      expect(FfmpegCommandBuilder.outputSize(const VideoProject()), (1920, 1080));
      expect(FfmpegCommandBuilder.outputSize(const VideoProject(aspect: VideoAspect.portrait)), (1080, 1920));
      final (w, h) = FfmpegCommandBuilder.outputSize(
        const VideoProject(aspect: VideoAspect.social, resolution: VideoResolution.p720),
      );
      expect(w.isEven && h.isEven, isTrue);
    });

    test('atempo chain stays within 0.5..2', () {
      expect(FfmpegCommandBuilder.atempoChain(1), isEmpty);
      expect(FfmpegCommandBuilder.atempoChain(4), ['atempo=2.0', 'atempo=2']);
      expect(FfmpegCommandBuilder.atempoChain(0.25), ['atempo=0.5', 'atempo=0.5']);
      expect(FfmpegCommandBuilder.atempoChain(1.5), ['atempo=1.5']);
    });

    test('builds a concat graph with trims, speed, reverse, crop, rotation', () {
      final p = VideoProject(
        clips: [
          _clip('a', 4000).copyWith(inMs: 500, outMs: 3500, speed: 2, reversed: true),
          _clip('b', 6000, audio: false).copyWith(crop: [0.1, 0, 0.9, 1], quarterTurns: 1),
        ],
      );
      final args = builder.build(p, '/out.mp4');
      expect(args.where((a) => a == '-i').length, 2);
      final graph = args[args.indexOf('-filter_complex') + 1];
      expect(graph, contains('[0:v]trim=start=0.500:end=3.500,setpts=PTS-STARTPTS,reverse,setpts=PTS/2'));
      expect(graph, contains('areverse'));
      expect(graph, contains('atempo=2'));
      expect(graph, contains('crop=w=iw*0.8:h=ih*1:x=iw*0.1:y=ih*0'));
      expect(graph, contains('transpose=1'));
      expect(graph, contains('anullsrc=r=44100:cl=stereo,atrim=duration=6.000[a1]'));
      expect(graph, contains('[v0][v1]concat=n=2:v=1:a=0[vj1]'));
      expect(args, containsAllInOrder(['-map', '[vj1]', '-map', '[aj1]']));
      expect(args, containsAllInOrder(['-c:v', 'libx264']));
      expect(args.last, '/out.mp4');
    });

    test('xfade offsets account for previous transitions', () {
      final p = VideoProject(
        clips: [
          _clip('a', 4000).copyWith(transitionOut: TransitionKind.dissolve, transitionMs: 1000),
          _clip('b', 4000).copyWith(transitionOut: TransitionKind.wipeLeft, transitionMs: 500),
          _clip('c', 4000),
        ],
      );
      final graph = builder.build(p, '/o.mp4')[builder.build(p, '/o.mp4').indexOf('-filter_complex') + 1];
      expect(graph, contains('xfade=transition=dissolve:duration=1.000:offset=3.000[vj1]'));
      expect(graph, contains('xfade=transition=wipeleft:duration=0.500:offset=6.500[vj2]'));
      expect(graph, contains('acrossfade=d=1.000'));
    });

    test('look, LUT, text overlays and music', () {
      final p = VideoProject(
        clips: [_clip('a', 5000)],
        look: const Adjustments(
          exposure: 0.5,
          contrast: 0.3,
          temperature: 0.2,
          grain: 0.2,
          lutId: 'builtin:teal_orange',
          lutIntensity: 0.5,
        ),
        texts: const [VideoText(id: 't1', text: 'Hi', startMs: 1000, endMs: 2000)],
        music: const AudioTrack(path: '/m.mp3'),
      );
      final args = builder.build(
        p,
        '/o.mp4',
        assets: const ExportAssets(
          textOverlayPngs: {'t1': '/tmp/t1.png'},
          lutFiles: {'builtin:teal_orange': "/tmp/it's:lut.cube"},
        ),
      );
      final graph = args[args.indexOf('-filter_complex') + 1];
      expect(graph, contains('exposure=exposure=0.5'));
      expect(graph, contains('colortemperature=temperature=5900'));
      expect(graph, contains('eq=contrast=1.18'));
      expect(graph, contains(r"lut3d=file='/tmp/it'\''s\:lut.cube'"));
      expect(graph, contains('blend=all_mode=normal:all_opacity=0.5'));
      expect(graph, contains('noise=alls=6:allf=t'));
      expect(graph, contains("overlay=0:0:enable='between(t,1.000,2.000)'"));
      expect(graph, contains('amix=inputs=2:duration=first'));
      expect(args, containsAllInOrder(['-stream_loop', '-1', '-i', '/m.mp3']));
      expect(args, containsAllInOrder(['-i', '/tmp/t1.png']));
    });

    test('look can be skipped for the GPU studio path', () {
      final p = VideoProject(clips: [_clip('a', 5000)], look: const Adjustments(exposure: 1));
      final graph = builder.build(p, '/o.mp4', includeLook: false).join(' ');
      expect(graph, isNot(contains('exposure=')));
    });

    test('hardware encoders', () {
      final args = const FfmpegCommandBuilder(
        encoder: VideoEncoder.mediacodec,
      ).build(VideoProject(clips: [_clip('a', 1000)]), '/o.mp4');
      expect(args, containsAllInOrder(['-c:v', 'h264_mediacodec']));
    });

    test('empty project throws', () {
      expect(() => builder.build(const VideoProject(), '/o.mp4'), throwsArgumentError);
    });

    test('VideoProject JSON round trip', () {
      final p = VideoProject(
        clips: [_clip('a', 1000).copyWith(transitionOut: TransitionKind.zoomIn)],
        texts: const [VideoText(id: 't', text: 'نص')],
        music: const AudioTrack(path: '/m.mp3'),
      );
      expect(VideoProject.fromJson(p.toJson()), p);
    });
  });
}
