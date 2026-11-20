import 'dart:async';
import 'dart:ui' as ui;

/// Loads and caches every compiled fragment program used by the engine.
class ShaderLibrary {
  ShaderLibrary._({
    required this.develop,
    required this.detail,
    required this.effects,
    required this.blur,
    required this.maskBlend,
    required this.warp,
    required this.videoFilter,
  });

  final ui.FragmentProgram develop;
  final ui.FragmentProgram detail;
  final ui.FragmentProgram effects;
  final ui.FragmentProgram blur;
  final ui.FragmentProgram maskBlend;
  final ui.FragmentProgram warp;
  final ui.FragmentProgram videoFilter;

  static Future<ShaderLibrary>? _instance;

  static Future<ShaderLibrary> load() => _instance ??= _load();

  static Future<ShaderLibrary> _load() async {
    final programs = await Future.wait([
      ui.FragmentProgram.fromAsset('shaders/develop.frag'),
      ui.FragmentProgram.fromAsset('shaders/detail.frag'),
      ui.FragmentProgram.fromAsset('shaders/effects.frag'),
      ui.FragmentProgram.fromAsset('shaders/blur.frag'),
      ui.FragmentProgram.fromAsset('shaders/mask_blend.frag'),
      ui.FragmentProgram.fromAsset('shaders/warp.frag'),
      ui.FragmentProgram.fromAsset('shaders/video_filter.frag'),
    ]);
    return ShaderLibrary._(
      develop: programs[0],
      detail: programs[1],
      effects: programs[2],
      blur: programs[3],
      maskBlend: programs[4],
      warp: programs[5],
      videoFilter: programs[6],
    );
  }
}
