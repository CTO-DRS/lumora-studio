import 'dart:math' as math;

import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/photo_editor/engine/curves/tone_curve.dart';
import 'package:lumora/features/video_editor/domain/look_keyframes.dart';
import 'package:lumora/features/video_editor/domain/timeline_ops.dart';
import 'package:lumora/features/video_editor/domain/video_project.dart';

enum VideoEncoder {
  /// Software x264 (best quality/size, GPL build).
  x264('libx264'),

  /// Android MediaCodec hardware encoder.
  mediacodec('h264_mediacodec'),

  /// Apple VideoToolbox hardware encoder.
  videotoolbox('h264_videotoolbox');

  const VideoEncoder(this.ffmpegName);
  final String ffmpegName;
}

/// Inputs that exist only at export time (rendered by Flutter).
class ExportAssets {
  const ExportAssets({this.textOverlayPngs = const {}, this.lutFiles = const {}, this.stabilizeFiles = const {}});

  /// Full-frame transparent PNG per [VideoText.id].
  final Map<String, String> textOverlayPngs;

  /// `.cube` file path per LUT id (built-ins are copied to disk first).
  final Map<String, String> lutFiles;

  /// vid.stab transforms file per [VideoClip.id] (from the detect pass).
  final Map<String, String> stabilizeFiles;
}

/// Builds FFmpeg argument lists for a [VideoProject]. Pure Dart and fully
/// unit tested; the result is passed to `FFmpegKit.executeWithArguments`,
/// so no shell quoting is involved.
class FfmpegCommandBuilder {
  const FfmpegCommandBuilder({
    this.encoder = VideoEncoder.x264,
    this.crf = 20,
    this.preset = 'medium',
    this.audioBitrate = '192k',
  });

  final VideoEncoder encoder;
  final int crf;
  final String preset;
  final String audioBitrate;

  /// Output frame size for [p] honoring aspect and resolution (even values).
  static (int, int) outputSize(VideoProject p) {
    final shortSide = p.resolution.height;
    final a = p.aspect;
    int w;
    int h;
    if (a.w >= a.h) {
      h = shortSide;
      w = (shortSide * a.w / a.h).round();
    } else {
      w = shortSide;
      h = (shortSide * a.h / a.w).round();
    }
    return (w ~/ 2 * 2, h ~/ 2 * 2);
  }

  List<String> build(
    VideoProject p,
    String outputPath, {
    ExportAssets assets = const ExportAssets(),
    bool includeLook = true,
    bool includeTexts = true,
  }) {
    if (p.clips.isEmpty) throw ArgumentError('Project has no clips');
    final (w, h) = outputSize(p);
    final args = <String>['-y', '-hide_banner'];
    final filters = <String>[];

    // ---- inputs: clips
    for (final c in p.clips) {
      args.addAll(['-i', c.path]);
    }
    var nextInput = p.clips.length;

    // ---- per clip chains
    for (var i = 0; i < p.clips.length; i++) {
      final c = p.clips[i];
      filters.add('[$i:v]${_videoChain(c, w, h, p.fps, stabilizeFile: assets.stabilizeFiles[c.id])}[v$i]');
      filters.add(_audioChain(i, c, p.originalVolume));
    }

    // ---- join with transitions
    var vCur = 'v0';
    var aCur = 'a0';
    var length = p.clips.first.durationMs;
    for (var i = 1; i < p.clips.length; i++) {
      final t = p.transitionAfter(i - 1);
      final vOut = 'vj$i';
      final aOut = 'aj$i';
      if (t > 0) {
        final kind = p.clips[i - 1].transitionOut.ffmpegName;
        filters.add('[$vCur][v$i]xfade=transition=$kind:duration=${_s(t)}:offset=${_s(length - t)}[$vOut]');
        filters.add('[$aCur][a$i]acrossfade=d=${_s(t)}:c1=tri:c2=tri[$aOut]');
        length += p.clips[i].durationMs - t;
      } else {
        filters.add('[$vCur][v$i]concat=n=2:v=1:a=0[$vOut]');
        filters.add('[$aCur][a$i]concat=n=2:v=0:a=1[$aOut]');
        length += p.clips[i].durationMs;
      }
      vCur = vOut;
      aCur = aOut;
    }

    // ---- look (fast FFmpeg approximation of the photo pipeline)
    if (includeLook) {
      final look = lookFilters(p.look, lutPath: p.look.lutId == null ? null : assets.lutFiles[p.look.lutId]);
      final animated = p.lookKeyframes.isNotEmpty;
      final constant = p.lookIntensity.clamp(0.0, 1.0);
      if (look.isNotEmpty && (animated || constant > 0.001)) {
        if (!animated && constant >= 0.999) {
          filters.add('[$vCur]$look[vlook]');
        } else {
          // Blend original (A) and graded (B) frames by the keyframed
          // strength: out = A + (B - A) * k(T).
          final k = p.lookIntensityExpression();
          filters
            ..add('[$vCur]split[lk0][lk1]')
            ..add('[lk1]$look[lk2]')
            ..add("[lk0][lk2]blend=all_expr='A+(B-A)*($k)'[vlook]");
        }
        vCur = 'vlook';
      }
    }

    // ---- text overlays
    if (includeTexts) {
      for (final t in p.texts) {
        final png = assets.textOverlayPngs[t.id];
        if (png == null) continue;
        args.addAll(['-i', png]);
        final out = 'vt${t.id.hashCode.abs()}';
        filters.add("[$vCur][$nextInput:v]overlay=0:0:enable='between(t,${_s(t.startMs)},${_s(t.endMs)})'[$out]");
        vCur = out;
        nextInput++;
      }
    }

    // ---- music
    final music = p.music;
    if (music != null) {
      if (music.loop) args.addAll(['-stream_loop', '-1']);
      args.addAll(['-i', music.path]);
      final total = _s(length);
      final fadeOutStart = _s(math.max(0, length - music.fadeOutMs));
      final chain = StringBuffer('[$nextInput:a]')
        ..write('atrim=start=${_s(music.startOffsetMs)},asetpts=PTS-STARTPTS,')
        ..write('atrim=duration=$total,')
        ..write('aformat=sample_rates=44100:channel_layouts=stereo,')
        ..write('volume=${_f(music.volume)}');
      if (music.fadeInMs > 0) chain.write(',afade=t=in:st=0:d=${_s(music.fadeInMs)}');
      if (music.fadeOutMs > 0) {
        chain.write(',afade=t=out:st=$fadeOutStart:d=${_s(music.fadeOutMs)}');
      }
      chain.write('[mus]');
      filters
        ..add(chain.toString())
        ..add('[$aCur][mus]amix=inputs=2:duration=first:dropout_transition=0:normalize=0[amix]');
      aCur = 'amix';
      nextInput++;
    }

    args
      ..addAll(['-filter_complex', filters.join(';')])
      ..addAll(['-map', '[$vCur]', '-map', '[$aCur]'])
      ..addAll(_videoCodecArgs())
      ..addAll(['-r', '${p.fps}', '-c:a', 'aac', '-b:a', audioBitrate])
      ..addAll(['-movflags', '+faststart', outputPath]);
    return args;
  }

  List<String> _videoCodecArgs() => switch (encoder) {
    VideoEncoder.x264 => ['-c:v', 'libx264', '-preset', preset, '-crf', '$crf', '-pix_fmt', 'yuv420p'],
    VideoEncoder.mediacodec => ['-c:v', 'h264_mediacodec', '-b:v', '12M', '-pix_fmt', 'yuv420p'],
    VideoEncoder.videotoolbox => ['-c:v', 'h264_videotoolbox', '-b:v', '12M', '-pix_fmt', 'yuv420p'],
  };

  static String _videoChain(VideoClip c, int w, int h, int fps, {String? stabilizeFile}) {
    final parts = <String>[
      'trim=start=${_s(c.inMs)}:end=${_s(c.outMs)}',
      'setpts=PTS-STARTPTS',
      if (c.stabilize && stabilizeFile != null) ...stabilizeTransform(stabilizeFile, c.stabilizeStrength),
      if (c.reversed) 'reverse',
      if (c.speed != 1) 'setpts=PTS/${_f(c.speed)}',
      if (c.isCropped)
        'crop=w=iw*${_f(c.crop[2] - c.crop[0])}:h=ih*${_f(c.crop[3] - c.crop[1])}:x=iw*${_f(c.crop[0])}:y=ih*${_f(c.crop[1])}',
      ..._rotation(c.quarterTurns),
      'scale=w=$w:h=$h:force_original_aspect_ratio=decrease',
      'pad=$w:$h:(ow-iw)/2:(oh-ih)/2:color=black',
      'setsar=1',
      'fps=$fps',
      'format=yuv420p',
    ];
    return parts.join(',');
  }

  /// Second vid.stab pass (applied right after trimming).
  static List<String> stabilizeTransform(String trfPath, double strength) => [
    "vidstabtransform=input='${escapeFilterPath(trfPath)}':smoothing=${stabilizeSmoothing(strength)}:optzoom=1:interpol=bilinear",
    'unsharp=5:5:0.6:3:3:0.3',
  ];

  /// First vid.stab pass: analyses the trimmed clip and writes [trfPath].
  static List<String> stabilizeDetectArgs(VideoClip c, String trfPath) => [
    '-y',
    '-hide_banner',
    '-ss',
    _s(c.inMs),
    '-t',
    _s(c.outMs - c.inMs),
    '-i',
    c.path,
    '-vf',
    "vidstabdetect=shakiness=6:accuracy=12:result='${escapeFilterPath(trfPath)}'",
    '-f',
    'null',
    '-',
  ];

  /// High-quality GIF from [input] with a generated palette.
  static List<String> gifArgs(String input, String output, {int width = 480, int fps = 12, int? maxMs}) => [
    '-y',
    '-hide_banner',
    if (maxMs != null) ...['-t', _s(maxMs)],
    '-i',
    input,
    '-filter_complex',
    [
      'fps=$fps,scale=$width:-2:flags=lanczos,split[g0][g1]',
      '[g0]palettegen=max_colors=192:stats_mode=diff[gp]',
      '[g1][gp]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle',
    ].join(';'),
    '-loop',
    '0',
    output,
  ];

  /// Grabs one frame at [sourceMs] of [path] as a high-quality JPEG.
  static List<String> frameArgs(String path, int sourceMs, String output) => [
    '-y',
    '-hide_banner',
    '-ss',
    _s(sourceMs),
    '-i',
    path,
    '-frames:v',
    '1',
    '-q:v',
    '1',
    output,
  ];

  static List<String> _rotation(int turns) => switch (turns % 4) {
    1 => ['transpose=1'],
    2 => ['hflip', 'vflip'],
    3 => ['transpose=2'],
    _ => [],
  };

  static String _audioChain(int i, VideoClip c, double master) {
    final vol = c.volume * master;
    if (!c.hasAudio) {
      return 'anullsrc=r=44100:cl=stereo,atrim=duration=${_s(c.durationMs)}[a$i]';
    }
    final parts = <String>[
      'atrim=start=${_s(c.inMs)}:end=${_s(c.outMs)}',
      'asetpts=PTS-STARTPTS',
      if (c.reversed) 'areverse',
      ...atempoChain(c.speed),
      'volume=${_f(vol)}',
      'aformat=sample_rates=44100:channel_layouts=stereo',
    ];
    return '[$i:a]${parts.join(',')}[a$i]';
  }

  /// `atempo` accepts 0.5..2.0, so larger factors are chained.
  static List<String> atempoChain(double speed) {
    if (speed == 1) return const [];
    final out = <String>[];
    var s = speed;
    while (s > 2.0) {
      out.add('atempo=2.0');
      s /= 2.0;
    }
    while (s < 0.5) {
      out.add('atempo=0.5');
      s /= 0.5;
    }
    out.add('atempo=${_f(s)}');
    return out;
  }

  /// Maps photo [Adjustments] to FFmpeg filters. This "fast" path covers
  /// tone, white balance, colour, curves, LUT, detail and effects; the
  /// "studio" export renders every frame through the GPU shaders instead.
  static String lookFilters(Adjustments a, {String? lutPath}) {
    final f = <String>[];
    if (a.exposure != 0) f.add('exposure=exposure=${_f(a.exposure)}');
    if (a.temperature != 0) {
      f.add('colortemperature=temperature=${(6500 - a.temperature * 3000).round()}');
    }
    if (a.tint != 0) f.add('colorbalance=gm=${_f(-a.tint * 0.3)}');
    final contrast = 1 + a.contrast * 0.6;
    final sat = (1 + a.saturation).clamp(0.0, 3.0);
    if (contrast != 1 || sat != 1) {
      f.add('eq=contrast=${_f(contrast)}:saturation=${_f(sat)}');
    }
    if (a.vibrance != 0) f.add('vibrance=intensity=${_f(a.vibrance.clamp(-2.0, 2.0))}');

    // Highlights/shadows/whites/blacks/fade folded into one master curve,
    // combined with the user's curves.
    final toneCurve = _toneCurvePoints(a);
    final curves = a.curves;
    if (toneCurve != null || !curves.isIdentity) {
      final master = toneCurve ?? _curveString(curves.master);
      final b = StringBuffer("curves=master='$master'");
      if (toneCurve != null && !curves.isIdentity) {
        // Apply tone first, then the user's own curves.
        f.add(b.toString());
        b
          ..clear()
          ..write("curves=master='${_curveString(curves.master)}'");
      }
      if (!curves.isIdentity) {
        b
          ..write(":r='${_curveString(curves.red)}'")
          ..write(":g='${_curveString(curves.green)}'")
          ..write(":b='${_curveString(curves.blue)}'");
      }
      f.add(b.toString());
    }

    if (lutPath != null) {
      final lut = "lut3d=file='${escapeFilterPath(lutPath)}':interp=tetrahedral";
      if (a.lutIntensity >= 0.999) {
        f.add(lut);
      } else {
        f.add('split[lA][lB];[lB]$lut[lC];[lA][lC]blend=all_mode=normal:all_opacity=${_f(a.lutIntensity)}');
      }
    }
    if (a.sharpen > 0) f.add('unsharp=5:5:${_f(a.sharpen * 1.5)}:5:5:0');
    if (a.clarity != 0 || a.structure != 0) {
      final amt = (a.clarity * 0.6 + a.structure * 0.8).clamp(-1.5, 1.5);
      f.add('unsharp=13:13:${_f(amt)}:13:13:0');
    }
    if (a.blur > 0) f.add('gblur=sigma=${_f(a.blur * 20)}');
    if (a.chromaticAberration > 0) {
      final px = (a.chromaticAberration * 6).round();
      if (px > 0) f.add('rgbashift=rh=-$px:bh=$px');
    }
    if (a.vignette < 0) {
      f.add('vignette=angle=${_f(0.3 + -a.vignette * 0.6)}');
    }
    if (a.grain > 0) f.add('noise=alls=${(a.grain * 30).round()}:allf=t');
    return f.join(',');
  }

  static String? _toneCurvePoints(Adjustments a) {
    if (a.highlights == 0 && a.shadows == 0 && a.whites == 0 && a.blacks == 0 && a.fade == 0) {
      return null;
    }
    final inBlack = a.blacks < 0 ? -a.blacks * 0.12 : 0.0;
    final outBlack = math.max(a.fade * 0.08, a.blacks > 0 ? a.blacks * 0.12 : 0.0);
    final inWhite = a.whites > 0 ? 1 - a.whites * 0.18 : 1.0;
    final outWhite = a.whites < 0 ? 1 + a.whites * 0.18 : 1.0;
    final shadowY = (0.25 + a.shadows * 0.08 + outBlack * 0.5).clamp(0.02, 0.6);
    final highY = (0.75 + a.highlights * 0.08).clamp(0.4, 0.98);
    return [
      '${_f(inBlack)}/${_f(outBlack)}',
      '0.25/${_f(shadowY)}',
      '0.75/${_f(highY)}',
      '${_f(inWhite)}/${_f(outWhite)}',
    ].join(' ');
  }

  static String _curveString(List<CurvePoint> pts) {
    // Resample through the monotone spline so FFmpeg's interpolation
    // matches the photo editor.
    final curve = ToneCurve(pts);
    return [for (var i = 0; i <= 8; i++) '${_f(i / 8)}/${_f(curve.evaluate(i / 8))}'].join(' ');
  }

  /// Escapes a path for use inside a single-quoted filter option.
  static String escapeFilterPath(String path) =>
      path.replaceAll(r'\', r'\\').replaceAll("'", r"'\''").replaceAll(':', r'\:');

  static String _s(int ms) => (ms / 1000).toStringAsFixed(3);
  static String _f(double v) {
    final s = v.toStringAsFixed(4);
    return s.contains('.') ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '') : s;
  }
}
