import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import 'package:lumora/core/providers.dart';
import 'package:lumora/features/ai/pipelines/tensor_utils.dart';
import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/photo_editor/domain/auto_enhance.dart' as enhance;
import 'package:lumora/features/photo_editor/domain/edit_history.dart';
import 'package:lumora/features/photo_editor/domain/edit_state.dart';
import 'package:lumora/features/photo_editor/domain/geometry.dart';
import 'package:lumora/features/photo_editor/domain/layers.dart';
import 'package:lumora/features/photo_editor/domain/presets.dart';
import 'package:lumora/features/photo_editor/engine/image_exporter.dart';
import 'package:lumora/features/photo_editor/engine/overlay_painter.dart';
import 'package:lumora/features/photo_editor/engine/photo_renderer.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'photo_editor_controller.g.dart';

enum EditorTool { presets, adjust, hsl, curves, lut, crop, text, stickers, draw, masks, ai }

/// Brush settings shared by the draw, mask brush and eraser tools.
class BrushSettings {
  const BrushSettings({this.size = 0.03, this.color = 0xFFFFFFFF, this.softness = 0, this.eraser = false});

  final double size;
  final int color;
  final double softness;
  final bool eraser;

  BrushSettings copyWith({double? size, int? color, double? softness, bool? eraser}) => BrushSettings(
    size: size ?? this.size,
    color: color ?? this.color,
    softness: softness ?? this.softness,
    eraser: eraser ?? this.eraser,
  );
}

@riverpod
class BrushController extends _$BrushController {
  @override
  BrushSettings build() => const BrushSettings();

  void set(BrushSettings Function(BrushSettings) f) => state = f(state);
}

/// UI state of the photo editor.
class PhotoEditorState {
  const PhotoEditorState({
    required this.history,
    this.projectId,
    this.sourcePath,
    this.preview,
    this.rendered,
    this.tool = EditorTool.presets,
    this.busy = false,
    this.progress,
    this.comparing = false,
    this.selectedLayerId,
    this.selectedMaskId,
    this.eraserMode = false,
    this.error,
  });

  final EditHistory<EditState> history;
  final String? projectId;
  final String? sourcePath;

  /// Proxy of the current raster (max 2048 px), geometry not applied.
  final ui.Image? preview;

  /// Latest GPU render of [edit] on [preview].
  final ui.Image? rendered;
  final EditorTool tool;
  final bool busy;
  final double? progress;
  final bool comparing;
  final String? selectedLayerId;
  final String? selectedMaskId;

  /// AI object eraser painting mode.
  final bool eraserMode;
  final String? error;

  EditState get edit => history.present;

  PhotoEditorState copyWith({
    EditHistory<EditState>? history,
    String? projectId,
    String? sourcePath,
    ui.Image? preview,
    ui.Image? rendered,
    EditorTool? tool,
    bool? busy,
    double? Function()? progress,
    bool? comparing,
    String? Function()? selectedLayerId,
    String? Function()? selectedMaskId,
    bool? eraserMode,
    String? Function()? error,
  }) => PhotoEditorState(
    history: history ?? this.history,
    projectId: projectId ?? this.projectId,
    sourcePath: sourcePath ?? this.sourcePath,
    preview: preview ?? this.preview,
    rendered: rendered ?? this.rendered,
    tool: tool ?? this.tool,
    busy: busy ?? this.busy,
    progress: progress != null ? progress() : this.progress,
    comparing: comparing ?? this.comparing,
    selectedLayerId: selectedLayerId != null ? selectedLayerId() : this.selectedLayerId,
    selectedMaskId: selectedMaskId != null ? selectedMaskId() : this.selectedMaskId,
    eraserMode: eraserMode ?? this.eraserMode,
    error: error != null ? error() : this.error,
  );
}

const _uuid = Uuid();
const kPreviewMaxSide = 2048;

@riverpod
class PhotoEditorController extends _$PhotoEditorController {
  PhotoRenderer? _renderer;
  String? _previewPath;
  bool _rendering = false;
  bool _dirty = false;
  ui.Image? _lastPreview;
  ui.Image? _lastRendered;

  @override
  PhotoEditorState build() {
    // `state` may not be read inside life-cycle callbacks, so GPU images
    // are tracked in fields as well.
    ref.onDispose(() {
      _lastPreview?.dispose();
      _lastRendered?.dispose();
    });
    return PhotoEditorState(history: EditHistory(EditState.initial));
  }

  // ------------------------------------------------------------ lifecycle

  Future<void> open(String sourcePath) async {
    state = PhotoEditorState(
      history: EditHistory(EditState.initial),
      projectId: ref.read(projectRepositoryProvider).newId(),
      sourcePath: sourcePath,
    );
    await _render();
  }

  Future<void> openProject(String id) async {
    final loaded = await ref.read(projectRepositoryProvider).loadPhoto(id);
    if (loaded == null) return;
    state = PhotoEditorState(history: EditHistory(loaded.$2), projectId: id, sourcePath: loaded.$1);
    await _render();
  }

  // ------------------------------------------------------------- editing

  /// Applies [f] to the edit. With [live] the change is part of an ongoing
  /// gesture (no undo step until [commit]).
  void update(EditState Function(EditState) f, {bool live = false}) {
    final next = f(state.edit);
    final h = live ? state.history.replace(next) : state.history.push(next);
    state = state.copyWith(history: h);
    unawaited(_render());
  }

  void updateAdjustments(Adjustments Function(Adjustments) f, {bool live = false}) =>
      update((s) => s.copyWith(adjustments: f(s.adjustments)), live: live);

  void commit() => state = state.copyWith(history: state.history.commit());

  void undo() {
    state = state.copyWith(history: state.history.undo());
    unawaited(_render());
  }

  void redo() {
    state = state.copyWith(history: state.history.redo());
    unawaited(_render());
  }

  void setTool(EditorTool tool) {
    state = state.copyWith(tool: tool, eraserMode: false);
    unawaited(_render());
  }

  void setComparing({required bool value}) => state = state.copyWith(comparing: value);

  void selectLayer(String? id) => state = state.copyWith(selectedLayerId: () => id);

  void selectMask(String? id) => state = state.copyWith(selectedMaskId: () => id);

  void setEraserMode({required bool value}) => state = state.copyWith(eraserMode: value);

  void applyPreset(String? id, {double intensity = 1}) {
    update((s) {
      final preset = presetById(id);
      // Presets are applied on top of the user's adjustments recorded
      // before any preset was chosen.
      final base = _withoutPreset(s);
      return s.copyWith(
        presetId: id,
        presetIntensity: intensity,
        adjustments: preset == null ? base : preset.apply(base, intensity: intensity),
      );
    });
  }

  Adjustments _withoutPreset(EditState s) {
    final preset = presetById(s.presetId);
    if (preset == null) return s.adjustments;
    // Reverse the scalar deltas of the previous preset.
    var a = s.adjustments;
    for (final param in AdjustmentParam.values) {
      if (param == AdjustmentParam.lutIntensity) continue;
      final target = param.read(preset.adjustments);
      if (target == param.neutral) continue;
      a = param.write(a, param.read(a) - (target - param.neutral) * s.presetIntensity);
    }
    return a.copyWith(
      lutId: preset.adjustments.lutId != null ? null : a.lutId,
      curves: preset.adjustments.curves.isIdentity ? a.curves : const CurveSet(),
      splitTone: preset.adjustments.splitTone == const SplitTone() ? a.splitTone : const SplitTone(),
      duotone: preset.adjustments.duotone.strength > 0 ? const Duotone() : a.duotone,
      hsl: preset.adjustments.hsl.isNeutral ? a.hsl : const HslAdjustments(),
    );
  }

  // --------------------------------------------------------------- layers

  String addText(String text) {
    final id = _uuid.v4();
    update(
      (s) => s.copyWith(
        layers: [
          ...s.layers,
          OverlayLayer.text(id: id, text: text),
        ],
      ),
    );
    selectLayer(id);
    return id;
  }

  String addSticker({String glyph = '✨', String? imagePath}) {
    final id = _uuid.v4();
    update(
      (s) => s.copyWith(
        layers: [
          ...s.layers,
          OverlayLayer.sticker(id: id, glyph: glyph, imagePath: imagePath),
        ],
      ),
    );
    selectLayer(id);
    return id;
  }

  void updateLayer(String id, OverlayLayer Function(OverlayLayer) f, {bool live = false}) =>
      update((s) => s.copyWith(layers: [for (final l in s.layers) l.id == id ? f(l) : l]), live: live);

  void removeLayer(String id) {
    update((s) => s.copyWith(layers: s.layers.where((l) => l.id != id).toList()));
    selectLayer(null);
  }

  /// Adds a stroke to the (single) drawing layer, creating it if needed.
  void addDrawingStroke(Stroke stroke) {
    update((s) {
      final idx = s.layers.indexWhere((l) => l is DrawingLayer);
      if (idx < 0) {
        return s.copyWith(
          layers: [
            ...s.layers,
            OverlayLayer.drawing(id: _uuid.v4(), strokes: [stroke]),
          ],
        );
      }
      final d = s.layers[idx] as DrawingLayer;
      final layers = [...s.layers]..[idx] = d.copyWith(strokes: [...d.strokes, stroke]);
      return s.copyWith(layers: layers);
    });
  }

  // ---------------------------------------------------------------- masks

  String addMask(MaskKind kind, {String? maskPath, Adjustments? adjustments, bool invert = false}) {
    final id = _uuid.v4();
    final geometry = switch (kind) {
      MaskKind.linear => [0.5, 0.25, 0.5, 0.75],
      MaskKind.radial => [0.5, 0.5, 0.3, 0.3],
      _ => [0.5, 0.5, 0.3, 0.3],
    };
    update(
      (s) => s.copyWith(
        localAdjustments: [
          ...s.localAdjustments,
          LocalAdjustment(
            id: id,
            kind: kind,
            geometry: geometry,
            maskPath: maskPath,
            invert: invert,
            adjustments: adjustments ?? const Adjustments(exposure: 0.5),
          ),
        ],
      ),
    );
    selectMask(id);
    return id;
  }

  void updateMask(String id, LocalAdjustment Function(LocalAdjustment) f, {bool live = false}) => update(
    (s) => s.copyWith(localAdjustments: [for (final m in s.localAdjustments) m.id == id ? f(m) : m]),
    live: live,
  );

  void removeMask(String id) {
    update((s) => s.copyWith(localAdjustments: s.localAdjustments.where((m) => m.id != id).toList()));
    selectMask(null);
  }

  // ------------------------------------------------------------------- AI

  String get _currentRaster => state.edit.rasterPath ?? state.sourcePath!;

  Future<T?> _busy<T>(Future<T> Function() job) async {
    state = state.copyWith(busy: true, progress: () => null, error: () => null);
    try {
      return await job();
    } on Object catch (e) {
      state = state.copyWith(error: () => '$e');
      return null;
    } finally {
      state = state.copyWith(busy: false, progress: () => null);
    }
  }

  Future<void> autoEnhance() async {
    final preview = state.preview;
    if (preview == null) return;
    final data = await preview.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    if (data == null) return;
    final stats = enhance.ImageStats.fromRgba(data.buffer.asUint8List(), preview.width, preview.height);
    updateAdjustments((a) => enhance.autoEnhance(stats, base: a));
  }

  Future<void> removeBackground({bool portrait = false}) => _busy(() async {
    final r = await ref.read(segmentationPipelineProvider).run(_currentRaster, portrait: portrait);
    update((s) => s.copyWith(rasterPath: r.cutoutPath));
  });

  Future<void> upscale() => _busy(() async {
    final path = await ref
        .read(upscalePipelineProvider)
        .run(_currentRaster, onProgress: (v) => state = state.copyWith(progress: () => v));
    update((s) => s.copyWith(rasterPath: path));
  });

  /// Subject mask → masked local adjustment ([retouch] = skin smoothing,
  /// [blurBackground] = background blur).
  Future<void> subjectAdjustment({bool retouch = false, bool blurBackground = false}) => _busy(() async {
    final r = await ref.read(segmentationPipelineProvider).run(_currentRaster, portrait: true);
    final adjustments = retouch
        ? const Adjustments(clarity: -0.35, structure: -0.3, exposure: 0.08, temperature: 0.04)
        : blurBackground
        ? const Adjustments(blur: 0.5)
        : const Adjustments(exposure: 0.3);
    addMask(MaskKind.subject, maskPath: r.maskPath, adjustments: adjustments, invert: blurBackground);
  });

  /// Runs the object eraser on [strokes] painted in output-normalized
  /// coordinates (mapped back through the geometry to source pixels).
  Future<void> eraseObjects(List<Stroke> strokes) => _busy(() async {
    final rasterPath = _currentRaster;
    final bytes = await File(rasterPath).readAsBytes();
    final desc = await ui.ImageDescriptor.encoded(await ui.ImmutableBuffer.fromUint8List(bytes));
    final sw = desc.width;
    final sh = desc.height;
    desc.dispose();
    final g = state.edit.geometry;
    final (ow, oh) = g.outputSize(sw, sh);
    final inv = buildInverseWarp(g, sw, sh, ow, oh);
    final mapped = [
      for (final s in strokes)
        s.copyWith(
          points: [
            for (var i = 0; i + 1 < s.points.length; i += 2)
              ...() {
                final (u, v) = inv.apply(s.points[i] * ow, s.points[i + 1] * oh);
                return [u, v];
              }(),
          ],
          width: s.width * math.min(ow, oh) / math.min(sw, sh),
          color: 0xFFFFFFFF,
        ),
    ];
    final rec = ui.PictureRecorder();
    final size = Size(sw.toDouble(), sh.toDouble());
    final canvas = Canvas(rec)..drawRect(Offset.zero & size, Paint()..color = Colors.black);
    OverlayPainter.paintStrokes(canvas, size, mapped, asMask: true);
    final maskImg = await rec.endRecording().toImage(sw, sh);
    final data = await maskImg.toByteData();
    maskImg.dispose();
    final mask = RgbaImage(sw, sh, data!.buffer.asUint8List());
    final out = await ref.read(inpaintPipelineProvider).run(rasterPath, mask);
    update((s) => s.copyWith(rasterPath: out));
    state = state.copyWith(eraserMode: false);
  });

  // --------------------------------------------------------------- output

  Future<File?> export(ExportOptions options) => _busy(() async {
    final renderer = await _ensureRenderer();
    final exporter = ImageExporter(renderer);
    final pixels = await exporter.renderFullResolution(
      state.sourcePath!,
      state.edit,
      onProgress: (v) => state = state.copyWith(progress: () => v * 0.8),
    );
    final file = await exporter.encodeAndSave(pixels, options, exifSourcePath: state.sourcePath);
    state = state.copyWith(progress: () => 1);
    try {
      if (await Gal.requestPermission()) await Gal.putImage(file.path, album: 'Lumora');
    } on Object catch (e) {
      debugPrint('Gallery save failed: $e');
    }
    await save();
    return file;
  });

  Future<void> save() async {
    final id = state.projectId;
    final src = state.sourcePath;
    if (id == null || src == null) return;
    String? thumb;
    final r = state.rendered;
    if (r != null) {
      final data = await r.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      if (data != null) {
        final dir = Directory(p.join((await getApplicationSupportDirectory()).path, 'thumbs'));
        if (!dir.existsSync()) await dir.create(recursive: true);
        thumb = p.join(dir.path, '$id.jpg');
        final w = r.width;
        final h = r.height;
        final bytes = data.buffer.asUint8List();
        final jpg = await compute(_thumbJpg, (bytes, w, h));
        await File(thumb).writeAsBytes(jpg);
      }
    }
    await ref
        .read(projectRepositoryProvider)
        .savePhoto(
          id: id,
          name: p.basenameWithoutExtension(src),
          sourcePath: src,
          state: state.edit,
          thumbnailPath: thumb,
        );
  }

  // --------------------------------------------------------------- render

  Future<PhotoRenderer> _ensureRenderer() async {
    final existing = _renderer;
    if (existing != null) return existing;
    final r = await ref.read(photoRendererProvider.future);
    _renderer = r;
    return r;
  }

  Future<void> _loadPreview(String path) async {
    final bytes = await File(path).readAsBytes();
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final desc = await ui.ImageDescriptor.encoded(buffer);
    final k = math.min(1, kPreviewMaxSide / math.max(desc.width, desc.height));
    final codec = await desc.instantiateCodec(
      targetWidth: (desc.width * k).round(),
      targetHeight: (desc.height * k).round(),
    );
    final frame = await codec.getNextFrame();
    final old = state.preview;
    state = state.copyWith(preview: frame.image);
    _lastPreview = frame.image;
    old?.dispose();
    _previewPath = path;
  }

  Future<void> _render() async {
    if (_rendering) {
      _dirty = true;
      return;
    }
    _rendering = true;
    try {
      do {
        _dirty = false;
        final src = state.sourcePath;
        if (src == null) return;
        final rasterPath = state.edit.rasterPath ?? src;
        if (_previewPath != rasterPath) await _loadPreview(rasterPath);
        final renderer = await _ensureRenderer();
        final edit = state.edit;
        await renderer.prepare(edit);
        final cropping = state.tool == EditorTool.crop;
        // While cropping, show the whole rotated/straightened frame.
        final out = renderer.render(
          state.preview!,
          cropping ? edit.copyWith(geometry: edit.geometry.withoutCrop()) : edit,
          includeOverlays: !cropping,
        );
        final old = state.rendered;
        state = state.copyWith(rendered: out);
        _lastRendered = out;
        // Let the frame that still shows the old image finish first.
        WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
      } while (_dirty);
    } on Object catch (e) {
      state = state.copyWith(error: () => '$e');
    } finally {
      _rendering = false;
    }
  }
}

Uint8List _thumbJpg((Uint8List, int, int) a) {
  final (bytes, w, h) = a;
  final image = img.Image.fromBytes(
    width: w,
    height: h,
    bytes: bytes.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  final small = w >= h ? img.copyResize(image, width: 480) : img.copyResize(image, height: 480);
  return img.encodeJpg(small, quality: 80);
}
