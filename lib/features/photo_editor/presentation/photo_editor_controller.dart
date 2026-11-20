import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import 'package:lumora/core/providers.dart';
import 'package:lumora/features/ai/pipelines/ai_pipelines.dart';
import 'package:lumora/features/ai/pipelines/tensor_utils.dart';
import 'package:lumora/features/photo_editor/data/preset_store.dart';
import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/photo_editor/domain/auto_enhance.dart' as enhance;
import 'package:lumora/features/photo_editor/domain/color_bands.dart';
import 'package:lumora/features/photo_editor/domain/edit_clipboard.dart';
import 'package:lumora/features/photo_editor/domain/edit_history.dart';
import 'package:lumora/features/photo_editor/domain/edit_state.dart';
import 'package:lumora/features/photo_editor/domain/geometry.dart';
import 'package:lumora/features/photo_editor/domain/histogram.dart';
import 'package:lumora/features/photo_editor/domain/layers.dart';
import 'package:lumora/features/photo_editor/domain/presets.dart';
import 'package:lumora/features/photo_editor/engine/finishing_renderer.dart';
import 'package:lumora/features/photo_editor/engine/healing.dart';
import 'package:lumora/features/photo_editor/engine/image_exporter.dart';
import 'package:lumora/features/photo_editor/engine/overlay_painter.dart';
import 'package:lumora/features/photo_editor/engine/photo_renderer.dart';
import 'package:lumora/features/photo_editor/engine/pixel_ops.dart';
import 'package:lumora/features/photo_editor/engine/preset_thumbnails.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'photo_editor_controller.g.dart';

enum EditorTool { presets, adjust, hsl, curves, lut, crop, masks, heal, ai, text, stickers, draw, frame, watermark }

/// Tools whose on-canvas gestures work in un-framed image coordinates.
const Set<EditorTool> _interactiveTools = {
  EditorTool.crop,
  EditorTool.text,
  EditorTool.stickers,
  EditorTool.draw,
  EditorTool.masks,
  EditorTool.heal,
};

/// HSL component targeted by the on-image colour picker.
enum HslComponent { hue, saturation, luminance }

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
    this.histogram,
    this.showHistogram = false,
    this.showClipping = false,
    this.clippingOverlay,
    this.hslBand = 0,
    this.hslPicking = false,
    this.hslComponent = HslComponent.saturation,
    this.healClone = false,
    this.healSource,
    this.healSettingSource = false,
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

  /// Histogram of the latest render (when [showHistogram]).
  final Histogram? histogram;
  final bool showHistogram;
  final bool showClipping;

  /// Red/blue clipping warning image matching [rendered].
  final ui.Image? clippingOverlay;

  /// HSL band (0..7) selected in the HSL panel or picked on the photo.
  final int hslBand;

  /// Tap/drag on the photo picks a colour band and adjusts it.
  final bool hslPicking;
  final HslComponent hslComponent;

  /// Heal tool: clone stamp mode (otherwise healing).
  final bool healClone;

  /// Clone source point, normalised to the output image.
  final Offset? healSource;

  /// The next tap on the photo sets [healSource].
  final bool healSettingSource;

  EditState get edit => history.present;

  /// Whether the canvas currently shows the un-framed image (so on-canvas
  /// gestures map 1:1 to image coordinates).
  bool get interactive => _interactiveTools.contains(tool) || eraserMode || hslPicking;

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
    Histogram? Function()? histogram,
    bool? showHistogram,
    bool? showClipping,
    ui.Image? Function()? clippingOverlay,
    int? hslBand,
    bool? hslPicking,
    HslComponent? hslComponent,
    bool? healClone,
    Offset? Function()? healSource,
    bool? healSettingSource,
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
    histogram: histogram != null ? histogram() : this.histogram,
    showHistogram: showHistogram ?? this.showHistogram,
    showClipping: showClipping ?? this.showClipping,
    clippingOverlay: clippingOverlay != null ? clippingOverlay() : this.clippingOverlay,
    hslBand: hslBand ?? this.hslBand,
    hslPicking: hslPicking ?? this.hslPicking,
    hslComponent: hslComponent ?? this.hslComponent,
    healClone: healClone ?? this.healClone,
    healSource: healSource != null ? healSource() : this.healSource,
    healSettingSource: healSettingSource ?? this.healSettingSource,
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
  ui.Image? _lastClipping;
  final FinishingRenderer _finishing = FinishingRenderer();
  Timer? _histogramTimer;

  @override
  PhotoEditorState build() {
    // `state` may not be read inside life-cycle callbacks, so GPU images
    // are tracked in fields as well.
    ref.onDispose(() {
      _histogramTimer?.cancel();
      _renderer?.dispose();
      _renderer = null;
      _lastPreview?.dispose();
      _lastRendered?.dispose();
      _lastClipping?.dispose();
      _finishing.dispose();
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
    if (tool == state.tool) return;
    state = state.copyWith(tool: tool, eraserMode: false, hslPicking: false, healSettingSource: false);
    unawaited(_render());
  }

  // --------------------------------------------------- view & analysis

  void toggleHistogram() {
    state = state.copyWith(showHistogram: !state.showHistogram);
    _scheduleHistogram();
  }

  void toggleClipping() {
    state = state.copyWith(showClipping: !state.showClipping);
    unawaited(_render());
  }

  // ------------------------------------------------- selective colour

  void selectHslBand(int band) => state = state.copyWith(hslBand: band.clamp(0, 7));

  void setHslComponent(HslComponent c) => state = state.copyWith(hslComponent: c);

  void setHslPicking({required bool value}) {
    state = state.copyWith(hslPicking: value);
    unawaited(_render());
  }

  /// Picks the colour band under [normalized] (0..1 in the displayed
  /// image) and selects it. Returns the sampled colour.
  Future<Color?> pickHslBandAt(Offset normalized) async {
    final img = state.rendered;
    if (img == null) return null;
    final data = await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    if (data == null) return null;
    final x = (normalized.dx * img.width).floor().clamp(0, img.width - 1);
    final y = (normalized.dy * img.height).floor().clamp(0, img.height - 1);
    // Average a 5x5 neighbourhood to avoid picking noise.
    var r = 0;
    var g = 0;
    var b = 0;
    var n = 0;
    for (var dy = -2; dy <= 2; dy++) {
      for (var dx = -2; dx <= 2; dx++) {
        final xx = (x + dx).clamp(0, img.width - 1);
        final yy = (y + dy).clamp(0, img.height - 1);
        final o = (yy * img.width + xx) * 4;
        r += data.getUint8(o);
        g += data.getUint8(o + 1);
        b += data.getUint8(o + 2);
        n++;
      }
    }
    final color = Color.fromARGB(255, r ~/ n, g ~/ n, b ~/ n);
    selectHslBand(hslBandForRgb(r / n, g / n, b / n));
    return color;
  }

  /// Targeted adjustment: changes the picked band's selected component by
  /// [delta] (from a vertical drag on the photo). Live until [commit].
  void nudgeHsl(double delta) {
    final band = state.hslBand;
    final comp = state.hslComponent;
    updateAdjustments((a) {
      List<double> upd(List<double> list) => [...list]..[band] = (list[band] + delta).clamp(-1.0, 1.0);
      return a.copyWith(
        hsl: switch (comp) {
          HslComponent.hue => a.hsl.copyWith(hue: upd(a.hsl.hue)),
          HslComponent.saturation => a.hsl.copyWith(saturation: upd(a.hsl.saturation)),
          HslComponent.luminance => a.hsl.copyWith(luminance: upd(a.hsl.luminance)),
        },
      );
    }, live: true);
  }

  // ------------------------------------------------------- heal / clone

  void setHealClone({required bool value}) =>
      state = state.copyWith(healClone: value, healSettingSource: value && state.healSource == null);

  void startSettingHealSource() => state = state.copyWith(healSettingSource: true);

  void setHealSource(Offset normalized) =>
      state = state.copyWith(healSource: () => normalized, healSettingSource: false);

  void setComparing({required bool value}) => state = state.copyWith(comparing: value);

  void selectLayer(String? id) => state = state.copyWith(selectedLayerId: () => id);

  void selectMask(String? id) => state = state.copyWith(selectedMaskId: () => id);

  void setEraserMode({required bool value}) => state = state.copyWith(eraserMode: value);

  Preset? _resolvePreset(String? id) => ref.read(presetLibraryControllerProvider).byId(id);

  void applyPreset(String? id, {double intensity = 1, bool live = false}) {
    update((s) {
      final preset = _resolvePreset(id);
      // Presets are applied on top of the user's adjustments recorded
      // before any preset was chosen.
      final base = adjustmentsWithoutPreset(s);
      return s.copyWith(
        presetId: preset == null ? null : id,
        presetIntensity: intensity,
        adjustments: preset == null ? base : preset.apply(base, intensity: intensity),
      );
    }, live: live);
  }

  /// The user's own adjustments with the active preset taken out.
  Adjustments adjustmentsWithoutPreset(EditState s) {
    final preset = _resolvePreset(s.presetId);
    if (preset == null) return s.adjustments;
    return preset.remove(s.adjustments, intensity: s.presetIntensity);
  }

  /// Saves the current look (all global adjustments) as a custom preset.
  Future<Preset> saveCurrentAsPreset(String name) async {
    final preset = await ref.read(presetLibraryControllerProvider.notifier).saveAs(name, state.edit.adjustments);
    // The look is now "this preset at 100 %" on a neutral base.
    update((s) => s.copyWith(presetId: preset.id, presetIntensity: 1));
    return preset;
  }

  // ------------------------------------------------------ copy / paste

  Future<void> copyEdits() => ref.read(editClipboardProvider.notifier).copy(state.edit);

  bool get canPaste => ref.read(editClipboardProvider) != null;

  void pasteEdits({PasteOptions options = const PasteOptions()}) {
    final copied = ref.read(editClipboardProvider);
    if (copied == null) return;
    update((s) => pasteEdit(s, copied, options: options));
  }

  /// Jumps to entry [index] of the edit history (see [EditHistory.timeline]).
  void jumpToHistory(int index) {
    state = state.copyWith(history: state.history.jumpTo(index));
    unawaited(_render());
  }

  /// Resets every edit (one undoable step), keeping AI generated pixels off.
  void resetAll() => update((_) => EditState.initial);

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

  /// Copies mask [id] (same shape and settings) and selects the copy.
  void duplicateMask(String id) {
    final m = state.edit.localAdjustments.where((m) => m.id == id).firstOrNull;
    if (m == null) return;
    final copy = m.copyWith(id: _uuid.v4());
    update((s) => s.copyWith(localAdjustments: [...s.localAdjustments, copy]));
    selectMask(copy.id);
  }

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

  /// Maps a point normalised to the output (cropped/rotated) image back to
  /// source pixels of the current raster (`buildInverseWarp` yields
  /// normalised source coordinates).
  (double, double) _toSource(Offset normalized, int sw, int sh) {
    final g = state.edit.geometry;
    final (ow, oh) = g.outputSize(sw, sh);
    final inv = buildInverseWarp(g, sw, sh, ow, oh);
    final (u, v) = inv.apply(normalized.dx * ow, normalized.dy * oh);
    return (u * sw, v * sh);
  }

  Future<(int, int)> _rasterSize(String path) async {
    final bytes = await File(path).readAsBytes();
    final desc = await ui.ImageDescriptor.encoded(await ui.ImmutableBuffer.fromUint8List(bytes));
    final size = (desc.width, desc.height);
    desc.dispose();
    return size;
  }

  /// Rasterises [strokes] (output-normalised) into a white-on-black RGBA
  /// mask in source pixel space.
  Future<RgbaImage> _strokesToSourceMask(List<Stroke> strokes, int sw, int sh) async {
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
    return RgbaImage(sw, sh, data!.buffer.asUint8List());
  }

  /// Runs the object eraser on [strokes] painted in output-normalized
  /// coordinates (mapped back through the geometry to source pixels).
  Future<void> eraseObjects(List<Stroke> strokes) => _busy(() async {
    final rasterPath = _currentRaster;
    final (sw, sh) = await _rasterSize(rasterPath);
    final mask = await _strokesToSourceMask(strokes, sw, sh);
    final out = await ref.read(inpaintPipelineProvider).run(rasterPath, mask);
    update((s) => s.copyWith(rasterPath: out));
    state = state.copyWith(eraserMode: false);
  });

  /// Healing / clone brush over [strokes] (output-normalised). Clone uses
  /// [PhotoEditorState.healSource] as the source point of the first stroke.
  Future<void> heal(List<Stroke> strokes) => _busy(() async {
    if (strokes.isEmpty) return;
    final rasterPath = _currentRaster;
    final source = await loadRgba(rasterPath);
    final sw = source.width;
    final sh = source.height;
    final mask = await _strokesToSourceMask(strokes, sw, sh);
    (int, int)? offset;
    final clone = state.healClone;
    final src = state.healSource;
    if (clone) {
      if (src == null) return;
      final first = strokes.first.points;
      final (fx, fy) = _toSource(Offset(first[0], first[1]), sw, sh);
      final (sx, sy) = _toSource(src, sw, sh);
      offset = ((sx - fx).round(), (sy - fy).round());
    }
    final alpha = Uint8List(sw * sh);
    for (var i = 0; i < alpha.length; i++) {
      alpha[i] = mask.pixels[i * 4];
    }
    final result = await Isolate.run(
      () => applyHeal(HealRequest(image: Rgba(sw, sh, source.pixels), mask: alpha, offset: offset, clone: clone)),
    );
    final path = await savePng(RgbaImage(result.width, result.height, result.data), clone ? 'clone' : 'heal');
    update((s) => s.copyWith(rasterPath: path));
  });

  // --------------------------------------------------------------- output

  Future<File?> export(ExportOptions options) => _busy(() async {
    final renderer = await _ensureRenderer();
    final exporter = ImageExporter(renderer);
    final rendered = await exporter.renderFullResolution(
      state.sourcePath!,
      state.edit,
      onProgress: (v) => state = state.copyWith(progress: () => v * 0.75),
    );
    final pixels = await exporter.finish(rendered, state.edit, options, _finishing);
    state = state.copyWith(progress: () => 0.85);
    final file = await exporter.encodeAndSave(pixels, options, exifSourcePath: state.sourcePath);
    state = state.copyWith(progress: () => 1);
    if (options.saveToGallery) {
      try {
        if (await Gal.requestPermission()) await Gal.putImage(file.path, album: 'Lumora');
      } on Object catch (e) {
        debugPrint('Gallery save failed: $e');
      }
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
        .savePhoto(id: id, sourcePath: src, state: state.edit, thumbnailPath: thumb);
  }

  // --------------------------------------------------------------- render

  void _scheduleHistogram() {
    if (!state.showHistogram) return;
    _histogramTimer?.cancel();
    _histogramTimer = Timer(const Duration(milliseconds: 120), () async {
      final img = state.rendered;
      if (img == null || !state.showHistogram) return;
      final small = downscaleImage(img, 256);
      final data = await small.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      small.dispose();
      if (data == null) return;
      state = state.copyWith(histogram: () => Histogram.fromRgba(data.buffer.asUint8List()));
    });
  }

  Future<PhotoRenderer> _ensureRenderer() async {
    final existing = _renderer;
    if (existing != null) return existing;
    final r = await createPhotoRenderer(ref.read);
    // Another call may have created one while we were awaiting.
    final raced = _renderer;
    if (raced != null) {
      r.dispose();
      return raced;
    }
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
        final interactive = state.interactive;
        // While cropping, show the whole rotated/straightened frame.
        var out = renderer.render(
          state.preview!,
          cropping ? edit.copyWith(geometry: edit.geometry.withoutCrop()) : edit,
          includeOverlays: !cropping,
        );
        if (!interactive) {
          final logo = await _finishing.logoFor(edit.watermark);
          final finished = _finishing.preview(out, edit, logo: logo);
          if (!identical(finished, out)) {
            out.dispose();
            out = finished;
          }
        }
        ui.Image? clip;
        if (state.showClipping) clip = renderer.clippingOverlay(out);
        final old = state.rendered;
        final oldClip = state.clippingOverlay;
        state = state.copyWith(rendered: out, clippingOverlay: () => clip);
        _lastRendered = out;
        _lastClipping = clip;
        // Let the frame that still shows the old image finish first.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          old?.dispose();
          oldClip?.dispose();
        });
        _scheduleHistogram();
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
