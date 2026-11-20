import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/photo_editor/domain/edit_state.dart';
import 'package:lumora/features/photo_editor/domain/geometry.dart';
import 'package:lumora/features/photo_editor/domain/layers.dart';
import 'package:lumora/features/photo_editor/engine/curves/tone_curve.dart';
import 'package:lumora/features/photo_editor/engine/lut/lut_repository.dart';
import 'package:lumora/features/photo_editor/engine/overlay_painter.dart';
import 'package:lumora/features/photo_editor/engine/shader_library.dart';

/// Describes which part of the final image a render produces.
class RenderTarget {
  const RenderTarget.full() : tileOffset = Offset.zero, fullSize = null;

  /// A tile of an image whose final size is [fullSize]; [tileOffset] is the
  /// tile's top-left corner (including padding) in output pixels.
  const RenderTarget.tile({required this.tileOffset, required Size this.fullSize});

  final Offset tileOffset;
  final Size? fullSize;
}

/// Decodes RGBA pixels into a GPU image.
Future<ui.Image> imageFromRgba(Uint8List rgba, int width, int height) {
  final c = Completer<ui.Image>();
  ui.decodeImageFromPixels(rgba, width, height, ui.PixelFormat.rgba8888, c.complete);
  return c.future;
}

/// GPU photo pipeline built on Flutter fragment shaders (Impeller).
///
/// Pass order: geometry (warp) → develop (tone/colour/curves/LUT) → local
/// adjustments (develop + mask blend) → detail (sharpen/clarity/dehaze) →
/// blur → effects (CA/glitch/duotone/vignette/grain) → overlays.
class PhotoRenderer {
  PhotoRenderer(this.shaders, this.luts);

  final ShaderLibrary shaders;
  final LutRepository luts;

  ui.Image? _dummy;
  ui.Image? _curves;
  String? _curvesKey;
  final Map<String, (ui.Image, int)> _lutAtlases = {};
  final Map<String, ui.Image> _brushMasks = {};
  final Map<String, ui.Image> _subjectMasks = {};
  final Map<String, ui.Image> _stickers = {};

  /// Loads every texture [state] needs. Must complete before [render].
  Future<void> prepare(EditState state) async {
    _dummy ??= await imageFromRgba(Uint8List.fromList([0, 0, 0, 255]), 1, 1);
    final all = [state.adjustments, for (final l in state.localAdjustments) l.adjustments];
    final key = state.adjustments.curves.hashCode.toString();
    if (_curvesKey != key) {
      _curves?.dispose();
      _curves = await imageFromRgba(curveSetToRgba(state.adjustments.curves), 256, 1);
      _curvesKey = key;
    }
    for (final a in all) {
      final id = a.lutId;
      if (id != null && !_lutAtlases.containsKey(id)) {
        final lut = await luts.load(id);
        final img = await imageFromRgba(lut.toAtlasRgba(), lut.atlasWidth, lut.atlasHeight);
        _lutAtlases[id] = (img, lut.size);
      }
    }
    for (final l in state.localAdjustments) {
      final path = l.maskPath;
      if (l.kind == MaskKind.subject && path != null && !_subjectMasks.containsKey(path)) {
        final bytes = await File(path).readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        _subjectMasks[path] = frame.image;
      }
    }
    for (final layer in state.layers) {
      if (layer is StickerLayer) {
        final path = layer.imagePath;
        if (path != null && !_stickers.containsKey(path)) {
          final bytes = await File(path).readAsBytes();
          final codec = await ui.instantiateImageCodec(bytes);
          _stickers[path] = (await codec.getNextFrame()).image;
        }
      }
    }
  }

  /// Frees every GPU texture. The renderer stays usable: the next
  /// [prepare] recreates what it needs.
  void dispose() {
    _dummy?.dispose();
    _curves?.dispose();
    _dummy = null;
    _curves = null;
    _curvesKey = null;
    for (final v in _lutAtlases.values) {
      v.$1.dispose();
    }
    for (final v in [..._brushMasks.values, ..._subjectMasks.values, ..._stickers.values]) {
      v.dispose();
    }
    _lutAtlases.clear();
    _brushMasks.clear();
    _subjectMasks.clear();
    _stickers.clear();
  }

  // ---------------------------------------------------------------- render

  /// Renders [state] on top of [source]. Call [prepare] first.
  ///
  /// When [target] is a tile, [source] is the already geometry-corrected
  /// tile (geometry is resolved by the exporter on the CPU).
  ui.Image render(
    ui.Image source,
    EditState state, {
    RenderTarget target = const RenderTarget.full(),
    bool applyGeometry = true,
    bool includeOverlays = true,
    bool includeLocal = true,
  }) {
    final isTile = target.fullSize != null;
    final geo = (applyGeometry && !isTile) ? state.geometry : const GeometryState();
    var current = _warp(source, geo);
    final w = current.width;
    final h = current.height;
    final full = target.fullSize ?? Size(w.toDouble(), h.toDouble());
    final tile = Rect.fromLTWH(target.tileOffset.dx, target.tileOffset.dy, full.width, full.height);
    final scale = math.min(full.width, full.height) / 1500;

    current = _replace(current, _develop(current, state.adjustments));

    if (includeLocal) {
      for (final local in state.localAdjustments) {
        if (!local.enabled) continue;
        final edited = _develop(current, local.adjustments);
        var editedDetail = edited;
        if (local.adjustments.hasDetail) {
          editedDetail = _detail(edited, local.adjustments, scale);
          edited.dispose();
        }
        if (local.adjustments.blur > 0) {
          // Masked blur (e.g. portrait "blur background").
          final r = math.min<double>(48, local.adjustments.blur * 0.03 * math.min(full.width, full.height));
          editedDetail = _replace(editedDetail, _blur(editedDetail, 1, 0, r));
          editedDetail = _replace(editedDetail, _blur(editedDetail, 0, 1, r));
        }
        final blended = _maskBlend(
          current,
          editedDetail,
          local,
          tile,
          full,
          applyGeometry ? state.geometry : const GeometryState(),
        );
        editedDetail.dispose();
        current = _replace(current, blended);
      }
    }

    final a = state.adjustments;
    if (a.hasDetail) current = _replace(current, _detail(current, a, scale));
    if (a.blur > 0) {
      final radius = a.blur * 0.03 * math.min(full.width, full.height);
      var r = radius;
      // Large radii are split over several iterations to stay smooth.
      while (r > 0.5) {
        final step = math.min<double>(r, 48);
        current = _replace(current, _blur(current, 1, 0, step));
        current = _replace(current, _blur(current, 0, 1, step));
        r = math.sqrt(math.max(0, r * r - step * step));
      }
    }
    if (a.hasEffects) current = _replace(current, _effects(current, a, tile));

    if (includeOverlays && state.layers.isNotEmpty) {
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      canvas.drawImage(current, Offset.zero, Paint());
      OverlayPainter(stickerImages: _stickers).paint(canvas, full, state.layers, tileOffset: target.tileOffset);
      final pic = rec.endRecording();
      current = _replace(current, pic.toImageSync(w, h));
      pic.dispose();
    }
    return current;
  }

  /// Clipping warning overlay for [image]: red where any channel reaches
  /// [highlight], blue where every channel is at or below [shadow].
  ui.Image clippingOverlay(
    ui.Image image, {
    double highlight = 254 / 255,
    double shadow = 1 / 255,
    bool highlights = true,
    bool shadows = true,
  }) {
    final s = shaders.clipping.fragmentShader();
    s.getUniformVec2('uSize').set(image.width.toDouble(), image.height.toDouble());
    s.getUniformVec4('uThreshold').set(highlight, shadow, highlights ? 1 : 0, shadows ? 1 : 0);
    s.setImageSampler(0, image, filterQuality: FilterQuality.low);
    return _run(image.width, image.height, s);
  }

  ui.Image _replace(ui.Image old, ui.Image next) {
    if (!identical(old, next)) old.dispose();
    return next;
  }

  ui.Image _run(int w, int h, ui.FragmentShader shader) {
    final rec = ui.PictureRecorder();
    Canvas(rec).drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..shader = shader);
    final pic = rec.endRecording();
    final img = pic.toImageSync(w, h);
    pic.dispose();
    shader.dispose();
    return img;
  }

  ui.Image _warp(ui.Image src, GeometryState g) {
    final (ow, oh) = g.outputSize(src.width, src.height);
    final m = buildInverseWarp(g, src.width, src.height, ow, oh).m;
    final s = shaders.warp.fragmentShader();
    s.getUniformVec2('uSize').set(ow.toDouble(), oh.toDouble());
    s.getUniformVec4('uRow0').set(m[0], m[1], m[2], 0);
    s.getUniformVec4('uRow1').set(m[3], m[4], m[5], 0);
    s.getUniformVec4('uRow2').set(m[6], m[7], m[8], 0);
    s.setImageSampler(0, src, filterQuality: FilterQuality.low);
    return _run(ow, oh, s);
  }

  ui.Image _develop(ui.Image src, Adjustments a) {
    final s = shaders.develop.fragmentShader();
    final hsl = a.hsl;
    final st = a.splitTone;
    final lut = a.lutId == null ? null : _lutAtlases[a.lutId];
    final useCurves = !a.curves.isIdentity && _curves != null;
    s.getUniformVec2('uSize').set(src.width.toDouble(), src.height.toDouble());
    s.getUniformVec4('uTone').set(a.exposure, a.contrast, a.highlights, a.shadows);
    s.getUniformVec4('uTone2').set(a.whites, a.blacks, a.temperature, a.tint);
    s.getUniformVec4('uColor').set(a.vibrance, a.saturation, a.fade, a.lutIntensity);
    s.getUniformVec4('uHslHue0').set(hsl.hue[0], hsl.hue[1], hsl.hue[2], hsl.hue[3]);
    s.getUniformVec4('uHslHue1').set(hsl.hue[4], hsl.hue[5], hsl.hue[6], hsl.hue[7]);
    s.getUniformVec4('uHslSat0').set(hsl.saturation[0], hsl.saturation[1], hsl.saturation[2], hsl.saturation[3]);
    s.getUniformVec4('uHslSat1').set(hsl.saturation[4], hsl.saturation[5], hsl.saturation[6], hsl.saturation[7]);
    s.getUniformVec4('uHslLum0').set(hsl.luminance[0], hsl.luminance[1], hsl.luminance[2], hsl.luminance[3]);
    s.getUniformVec4('uHslLum1').set(hsl.luminance[4], hsl.luminance[5], hsl.luminance[6], hsl.luminance[7]);
    s.getUniformVec4('uSplit').set(st.shadowHue, st.shadowSaturation, st.highlightHue, st.highlightSaturation);
    s.getUniformVec4('uFlags').set(useCurves ? 1 : 0, lut != null ? 1 : 0, (lut?.$2 ?? 2).toDouble(), st.balance);
    s.setImageSampler(0, src, filterQuality: FilterQuality.low);
    // Local adjustments never carry their own curves: only the global curve
    // texture exists, so it is only enabled for the global pass.
    s.setImageSampler(1, _curves ?? _dummy!);
    s.setImageSampler(2, lut?.$1 ?? _dummy!, filterQuality: FilterQuality.low);
    return _run(src.width, src.height, s);
  }

  ui.Image _detail(ui.Image src, Adjustments a, double scale) {
    final s = shaders.detail.fragmentShader();
    s.getUniformVec2('uSize').set(src.width.toDouble(), src.height.toDouble());
    s.getUniformVec4('uDetail').set(a.sharpen, a.clarity, a.structure, a.dehaze);
    s.getUniformVec4('uRadius').set(math.max(1, 1.2 * scale), math.max(4, 30 * scale), math.max(2, 4 * scale), 0);
    s.setImageSampler(0, src, filterQuality: FilterQuality.low);
    return _run(src.width, src.height, s);
  }

  ui.Image _blur(ui.Image src, double dx, double dy, double radius) {
    final s = shaders.blur.fragmentShader();
    s.getUniformVec2('uSize').set(src.width.toDouble(), src.height.toDouble());
    s.getUniformVec4('uBlur').set(dx, dy, radius, 0);
    s.setImageSampler(0, src, filterQuality: FilterQuality.low);
    return _run(src.width, src.height, s);
  }

  ui.Image _effects(ui.Image src, Adjustments a, Rect tile) {
    final s = shaders.effects.fragmentShader();
    final d = a.duotone;
    final sc = Color(d.shadowColor);
    final hc = Color(d.highlightColor);
    s.getUniformVec2('uSize').set(src.width.toDouble(), src.height.toDouble());
    s.getUniformVec4('uTile').set(tile.left, tile.top, tile.width, tile.height);
    s.getUniformVec4('uVignette').set(a.vignette, a.vignetteMidpoint, a.vignetteRoundness, a.vignetteFeather);
    s.getUniformVec4('uGrain').set(a.grain, a.grainSize, 0.37, a.chromaticAberration);
    s.getUniformVec4('uGlitch').set(a.glitch, 0.61, d.strength, 0);
    s.getUniformVec4('uDuoShadow').set(sc.r, sc.g, sc.b, 1);
    s.getUniformVec4('uDuoLight').set(hc.r, hc.g, hc.b, 1);
    s.setImageSampler(0, src, filterQuality: FilterQuality.low);
    return _run(src.width, src.height, s);
  }

  ui.Image _maskBlend(ui.Image base, ui.Image edited, LocalAdjustment l, Rect tile, Size full, GeometryState geo) {
    final mode = switch (l.kind) {
      MaskKind.brush || MaskKind.subject => 0.0,
      MaskKind.linear => 1.0,
      MaskKind.radial => 2.0,
    };
    final mask = switch (l.kind) {
      MaskKind.brush => _brushMask(l, full),
      MaskKind.subject => _subjectMask(l, geo),
      _ => _dummy!,
    };
    final s = shaders.maskBlend.fragmentShader();
    final g = l.geometry;
    s.getUniformVec2('uSize').set(base.width.toDouble(), base.height.toDouble());
    s.getUniformVec4('uTile').set(tile.left, tile.top, tile.width, tile.height);
    s.getUniformVec4('uMode').set(mode, l.invert ? 1 : 0, l.feather, l.amount);
    s.getUniformVec4('uGeom').set(g[0], g[1], g[2], g[3]);
    s.getUniformVec4('uGeom2').set(l.rotation, 0, 0, 0);
    s.setImageSampler(0, base, filterQuality: FilterQuality.low);
    s.setImageSampler(1, edited, filterQuality: FilterQuality.low);
    s.setImageSampler(2, mask, filterQuality: FilterQuality.low);
    return _run(base.width, base.height, s);
  }

  /// Rasterises brush strokes into a mask covering the whole output
  /// (max 2048 px), cached per stroke list.
  ui.Image _brushMask(LocalAdjustment l, Size full) {
    final key = '${l.id}:${l.strokes.hashCode}';
    final cached = _brushMasks[key];
    if (cached != null) return cached;
    _brushMasks.removeWhere((k, v) {
      final stale = k.startsWith('${l.id}:');
      if (stale) v.dispose();
      return stale;
    });
    final k = math.min(1, 2048 / math.max(full.width, full.height));
    final size = Size((full.width * k).roundToDouble(), (full.height * k).roundToDouble());
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec)..drawRect(Offset.zero & size, Paint()..color = const Color(0xFF000000));
    OverlayPainter.paintStrokes(canvas, size, l.strokes, asMask: true);
    final pic = rec.endRecording();
    final img = pic.toImageSync(size.width.toInt(), size.height.toInt());
    pic.dispose();
    return _brushMasks[key] = img;
  }

  /// Subject masks are produced in source space; run them through the same
  /// geometry so they line up with the cropped/rotated output.
  ui.Image _subjectMask(LocalAdjustment l, GeometryState geo) {
    final path = l.maskPath;
    final src = path == null ? null : _subjectMasks[path];
    if (src == null) return _dummy!;
    final key = '${l.id}:${geo.hashCode}';
    final cached = _brushMasks[key];
    if (cached != null) return cached;
    final img = _warp(src, geo);
    _brushMasks[key] = img;
    return img;
  }
}
