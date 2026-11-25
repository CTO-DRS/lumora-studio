import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import 'package:lumora/core/diagnostics/crash_log.dart';
import 'package:lumora/core/providers.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:lumora/features/ai/pipelines/ai_pipelines.dart';
import 'package:lumora/features/ai/pipelines/face_pipeline.dart';
import 'package:lumora/features/ai/pipelines/sky_pipeline.dart';
import 'package:lumora/features/ai/pipelines/smart_pipelines.dart';
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
import 'package:lumora/features/photo_editor/domain/horizon.dart' as horizon;
import 'package:lumora/features/photo_editor/domain/layers.dart';
import 'package:lumora/features/photo_editor/domain/presets.dart';
import 'package:lumora/features/photo_editor/engine/finishing_renderer.dart';
import 'package:lumora/features/photo_editor/engine/healing.dart';
import 'package:lumora/features/photo_editor/engine/image_exporter.dart';
import 'package:lumora/features/photo_editor/engine/low_light.dart' as low_light;
import 'package:lumora/features/photo_editor/engine/overlay_painter.dart';
import 'package:lumora/features/photo_editor/engine/photo_renderer.dart';
import 'package:lumora/features/photo_editor/engine/pixel_ops.dart';
import 'package:lumora/features/photo_editor/engine/preset_thumbnails.dart';
import 'package:lumora/features/smart_edit/domain/edit_ops.dart';
import 'package:lumora/features/smart_edit/domain/photo_analysis.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'photo_editor_controller.g.dart';

enum EditorTool {
  smart,
  presets,
  adjust,
  hsl,
  curves,
  lut,
  crop,
  masks,
  heal,
  ai,
  text,
  stickers,
  draw,
  frame,
  watermark,
}

/// What to do with a tap-to-select selection.
enum SelectionAction { erase, cutOut, adjust, blurBackground }

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
    this.tool = EditorTool.smart,
    this.busy = false,
    this.progress,
    this.comparing = false,
    this.selectedLayerId,
    this.selectedMaskId,
    this.eraserMode = false,
    this.error,
    this.failure,
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
    this.selecting = false,
    this.selectAdd = true,
    this.selectPoints = const [],
    this.selectOverlay,
    this.hasSelection = false,
    this.suggestions = const [],
    this.lastSmartPlan,
    this.selectMode = SelectPromptMode.tap,
    this.selectCandidates = const [],
    this.selectCandidateIndex = 0,
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

  /// The exception behind [error] (localised by the page).
  final Object? failure;

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

  /// Tap-to-select mode (MobileSAM): taps add ([selectAdd]) or subtract
  /// regions; [selectOverlay] tints the selection on the canvas.
  final bool selecting;
  final bool selectAdd;
  final List<SelectPoint> selectPoints;
  final ui.Image? selectOverlay;
  final bool hasSelection;

  /// One-tap fixes for the current photo (best first).
  final List<Suggestion> suggestions;

  /// The smart plan applied most recently — the Smart bar offers follow-up
  /// commands based on it (see next_commands.dart).
  final SmartEditPlan? lastSmartPlan;

  /// How the next selection prompt is given (tap / box / brush).
  final SelectPromptMode selectMode;

  /// Predicted IoU of each mask candidate of the last decode, best first.
  /// Empty when the (single) decoder has not run yet.
  final List<double> selectCandidates;

  /// Which candidate is currently shown (index into [selectCandidates]).
  final int selectCandidateIndex;

  EditState get edit => history.present;

  /// Whether the canvas currently shows the un-framed image (so on-canvas
  /// gestures map 1:1 to image coordinates).
  bool get interactive => _interactiveTools.contains(tool) || eraserMode || hslPicking || selecting;

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
    Object? Function()? failure,
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
    bool? selecting,
    bool? selectAdd,
    List<SelectPoint>? selectPoints,
    ui.Image? Function()? selectOverlay,
    bool? hasSelection,
    List<Suggestion>? suggestions,
    SmartEditPlan? Function()? lastSmartPlan,
    SelectPromptMode? selectMode,
    List<double>? selectCandidates,
    int? selectCandidateIndex,
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
    failure: failure != null ? failure() : this.failure,
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
    selecting: selecting ?? this.selecting,
    selectAdd: selectAdd ?? this.selectAdd,
    selectPoints: selectPoints ?? this.selectPoints,
    selectOverlay: selectOverlay != null ? selectOverlay() : this.selectOverlay,
    hasSelection: hasSelection ?? this.hasSelection,
    suggestions: suggestions ?? this.suggestions,
    lastSmartPlan: lastSmartPlan != null ? lastSmartPlan() : this.lastSmartPlan,
    selectMode: selectMode ?? this.selectMode,
    selectCandidates: selectCandidates ?? this.selectCandidates,
    selectCandidateIndex: selectCandidateIndex ?? this.selectCandidateIndex,
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
  RgbaImage? _selectionMask;
  ui.Image? _lastSelectOverlay;
  String? _analysedPath;

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
      _lastSelectOverlay?.dispose();
      _finishing.dispose();
    });
    return PhotoEditorState(history: EditHistory(EditState.initial));
  }

  // ------------------------------------------------------------ lifecycle

  Future<void> open(String sourcePath) async {
    _analysedPath = null;
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
    _analysedPath = null;
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
    _dropSelection();
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

  void applyPreset(String? id, {double intensity = 1, bool live = false}) =>
      update((s) => _withPreset(s, id, intensity), live: live);

  /// [s] with preset [id] at [intensity] (`null` removes the active one).
  /// Presets are applied on top of the user's adjustments recorded before
  /// any preset was chosen.
  EditState _withPreset(EditState s, String? id, double intensity) {
    final preset = _resolvePreset(id);
    final base = adjustmentsWithoutPreset(s);
    return s.copyWith(
      presetId: preset == null ? null : id,
      presetIntensity: intensity,
      adjustments: preset == null ? base : preset.apply(base, intensity: intensity),
    );
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

  Future<T?> _busy<T>(Future<T> Function() job, {String? label}) async {
    state = state.copyWith(busy: true, progress: () => null, error: () => null, failure: () => null);
    if (label != null) CrashLog.instance.breadcrumb('Editor: $label started');
    try {
      final r = await job();
      if (label != null) CrashLog.instance.breadcrumb('Editor: $label finished');
      return r;
    } on Object catch (e, st) {
      CrashLog.instance.record(label ?? 'Editor', '$e', st);
      state = state.copyWith(error: () => '$e', failure: () => e);
      return null;
    } finally {
      state = state.copyWith(busy: false, progress: () => null);
    }
  }

  Future<void> autoEnhance() async {
    final preview = state.preview;
    if (preview == null) return;
    CrashLog.instance.breadcrumb('Editor: auto enhance ${preview.width}x${preview.height}');
    try {
      final data = await preview.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      if (data == null) return;
      final stats = enhance.ImageStats.fromRgba(data.buffer.asUint8List(), preview.width, preview.height);
      updateAdjustments((a) => enhance.autoEnhance(stats, base: a));
    } on Object catch (e, st) {
      CrashLog.instance.record('autoEnhance', '$e', st);
      state = state.copyWith(error: () => '$e', failure: () => e);
    }
  }

  /// Detects the horizon on the preview proxy and applies the
  /// corresponding straighten angle as one undoable step. No-op when the
  /// detection is not confident enough or the photo is already level.
  Future<void> autoStraighten() async {
    final preview = state.preview;
    if (preview == null) return;
    CrashLog.instance.breadcrumb('Editor: auto straighten ${preview.width}x${preview.height}');
    try {
      final result = await _detectHorizon();
      if (result == null || !result.isUsable || result.angleDegrees.abs() < 0.1) return;
      update(
        (s) => s.copyWith(geometry: s.geometry.copyWith(straightenDegrees: result.correctionDegrees).withoutCrop()),
      );
    } on Object catch (e, st) {
      CrashLog.instance.record('autoStraighten', '$e', st);
      state = state.copyWith(error: () => '$e', failure: () => e);
    }
  }

  Future<horizon.HorizonResult?> _detectHorizon() async {
    final preview = state.preview;
    if (preview == null) return null;
    final small = downscaleImage(preview, 256);
    final data = await small.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    final (w, h) = (small.width, small.height);
    small.dispose();
    if (data == null) return null;
    return horizon.detectHorizon(data.buffer.asUint8List(), w, h);
  }

  Future<void> removeBackground({bool portrait = false}) => _busy(() async {
    final r = await ref.read(segmentationPipelineProvider).run(_currentRaster, portrait: portrait);
    update((s) => s.copyWith(rasterPath: r.cutoutPath));
  }, label: portrait ? 'cut out person' : 'remove background');

  Future<void> upscale() => _busy(() async {
    final path = await ref
        .read(upscalePipelineProvider)
        .run(_currentRaster, onProgress: (v) => state = state.copyWith(progress: () => v));
    update((s) => s.copyWith(rasterPath: path));
  }, label: 'upscale 4x');

  /// Low-light rescue (W5, model-free): denoise then lift, written as a new
  /// raster so it is one undo step like the other pixel tools.
  Future<void> lowLightRescue({low_light.LowLightParams params = const low_light.LowLightParams()}) => _busy(() async {
    final source = await loadRgba(_currentRaster);
    final (w, h) = (source.width, source.height);
    final out = await Isolate.run(() => low_light.lowLightRescue(source.pixels, w, h, params: params));
    final path = await savePng(RgbaImage(w, h, out), 'low_light');
    update((s) => s.copyWith(rasterPath: path));
  }, label: 'low-light rescue');

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
  }, label: retouch ? 'portrait retouch' : (blurBackground ? 'background blur' : 'subject mask'));

  /// Face-aware retouch (v1.4 "Faces"): YuNet finds the faces, the 478-point
  /// mesh builds the [region] mask (skin-only / eyes / teeth) and the fix is
  /// applied as one editable, undoable local adjustment per face union.
  Future<void> faceAdjustment(FaceRegion region) => _busy(
    () async {
      final pipeline = ref.read(facePipelineProvider);
      final analysis = await pipeline.analyze(_currentRaster);
      if (analysis.faces.isEmpty) throw const SmartEditException(SmartEditFailure.noFace);
      final maskPath = await pipeline.maskPath(analysis, region);
      final adjustments = switch (region) {
        FaceRegion.skin => const Adjustments(clarity: -0.4, structure: -0.25, exposure: 0.06),
        FaceRegion.eyes => const Adjustments(exposure: 0.22, vibrance: 0.1),
        FaceRegion.teeth => const Adjustments(saturation: -0.45, exposure: 0.12),
        FaceRegion.lips => const Adjustments(saturation: 0.45, vibrance: 0.2, contrast: 0.1, exposure: -0.05),
        FaceRegion.brows => const Adjustments(exposure: -0.3, contrast: 0.25, structure: 0.3),
      };
      addMask(MaskKind.subject, maskPath: maskPath, adjustments: adjustments);
    },
    label: switch (region) {
      FaceRegion.skin => 'face skin retouch',
      FaceRegion.eyes => 'eye brighten',
      FaceRegion.teeth => 'teeth whiten',
      FaceRegion.lips => 'lip colour',
      FaceRegion.brows => 'brows enhance',
    },
  );

  /// Sky tools (v1.4 "Sky & scene"): the skyseg matte (44.2 MB int8 U²-Net
  /// model, min-max decoded on the 320² proxy) either restricts a deepen
  /// look to the sky ([skyDeepen] — one editable, undoable local adjustment)
  /// or drives a procedural gradient replacement ([skyReplace] — raster
  /// step, undoable in history).
  Future<SkyResult> _skyAnalysis(RgbaImage raster) async {
    final sky = await ref.read(skyPipelineProvider).analyze(raster);
    if (sky.fraction < 0.02 || sky.fraction > 0.95) {
      throw const SmartEditException(SmartEditFailure.noSky);
    }
    return sky;
  }

  Future<void> skyDeepen() => _busy(() async {
    final raster = await loadRgba(_currentRaster);
    await _skyAnalysis(raster);
    final maskPath = await ref.read(skyPipelineProvider).maskPath(raster);
    addMask(
      MaskKind.subject,
      maskPath: maskPath,
      adjustments: const Adjustments(
        dehaze: 0.18,
        highlights: -0.2,
        vibrance: 0.22,
        contrast: 0.14,
        hsl: HslAdjustments(saturation: [0, 0, 0, 0, 0.15, 0.25, 0, 0], luminance: [0, 0, 0, 0, -0.1, -0.15, 0, 0]),
      ),
    );
  }, label: 'sky deepen');

  Future<void> skyReplace(SkyPreset preset) => _busy(() async {
    final raster = await loadRgba(_currentRaster);
    final sky = await _skyAnalysis(raster);
    final out = await Isolate.run(() => compositeSky(raster, sky, preset));
    final path = await savePng(out, 'sky_replace');
    update((s) => s.copyWith(rasterPath: path));
  }, label: 'sky replace ${preset.name}');

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
  Future<RgbaImage> _strokesToSourceMask(List<Stroke> strokes, int sw, int sh, {int? maxSide}) async {
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
    // Optionally rasterised smaller (the eraser works on a capped copy):
    // a full-size mask of a 50+ MP photo can exceed the GPU texture limit.
    final k = maxSide == null ? 1.0 : math.min(1, maxSide / math.max(sw, sh)).toDouble();
    final mw = math.max(1, (sw * k).round());
    final mh = math.max(1, (sh * k).round());
    final rec = ui.PictureRecorder();
    final size = Size(sw.toDouble(), sh.toDouble());
    final canvas = Canvas(rec)..scale(mw / sw, mh / sh);
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);
    OverlayPainter.paintStrokes(canvas, size, mapped, asMask: true);
    final maskImg = await rec.endRecording().toImage(mw, mh);
    final data = await maskImg.toByteData();
    maskImg.dispose();
    return RgbaImage(mw, mh, data!.buffer.asUint8List());
  }

  /// Runs the object eraser on [strokes] painted in output-normalized
  /// coordinates (mapped back through the geometry to source pixels).
  Future<void> eraseObjects(List<Stroke> strokes) => _busy(() async {
    final rasterPath = _currentRaster;
    final (sw, sh) = await _rasterSize(rasterPath);
    final mask = await _strokesToSourceMask(strokes, sw, sh, maxSide: InpaintPipeline.maxSide);
    final out = await ref.read(inpaintPipelineProvider).run(rasterPath, mask);
    update((s) => s.copyWith(rasterPath: out));
    state = state.copyWith(eraserMode: false);
  }, label: 'object eraser');

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

  // ----------------------------------------------------------- smart edit

  /// Applies the instant part of [plan] (sliders, looks, rotate/flip,
  /// auto-enhance, reset, remove look) as **one** undo step and returns the
  /// actions that need a model or further input, in order, for the page to
  /// run (it asks before downloading models).
  Future<List<SmartAction>> applySmartPlan(SmartEditPlan plan) async {
    final actions = plan.actions.toList();
    if (actions.contains(SmartAction.undo)) undo();
    enhance.ImageStats? stats;
    if (actions.contains(SmartAction.autoEnhance)) stats = await _previewStats();
    horizon.HorizonResult? horizonResult;
    if (actions.contains(SmartAction.autoStraighten)) horizonResult = await _detectHorizon();
    final instant = plan.ops.where((o) => o is! ActionOp || (o.action.instant && o.action != SmartAction.undo));
    if (instant.isNotEmpty) {
      update((s0) {
        var s = s0;
        for (final op in instant) {
          switch (op) {
            case AdjustOp():
              s = s.copyWith(adjustments: applyAdjustOps(s.adjustments, [op]));
            case LookOp():
              s = _withPreset(s, op.presetId, op.intensity.clamp(0.0, 1.0));
            case ActionOp(:final action):
              s = switch (action) {
                SmartAction.reset => EditState.initial,
                SmartAction.clearLook => _withPreset(s, null, 1),
                SmartAction.autoEnhance when stats != null => s.copyWith(
                  adjustments: enhance.autoEnhance(stats, base: s.adjustments),
                ),
                SmartAction.autoStraighten when horizonResult != null => s.copyWith(
                  geometry: s.geometry.copyWith(straightenDegrees: horizonResult.correctionDegrees).withoutCrop(),
                ),
                _ => s.copyWith(geometry: applyGeometryAction(s.geometry, action)),
              };
          }
        }
        return s;
      });
    }
    CrashLog.instance.breadcrumb('Editor: smart edit ${plan.toJson()}');
    state = state.copyWith(lastSmartPlan: () => plan);
    return [
      for (final a in actions)
        if (!a.instant) a,
    ];
  }

  Future<enhance.ImageStats?> _previewStats() async {
    final preview = state.preview;
    if (preview == null) return null;
    final small = downscaleImage(preview, 256);
    final data = await small.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    final (w, h) = (small.width, small.height);
    small.dispose();
    if (data == null) return null;
    return enhance.ImageStats.fromRgba(data.buffer.asUint8List(), w, h);
  }

  /// Recomputes [PhotoEditorState.suggestions] for the current raster.
  Future<void> _analyse() async {
    final preview = state.preview;
    final path = _previewPath;
    if (preview == null || path == null || path == _analysedPath) return;
    _analysedPath = path;
    try {
      final small = downscaleImage(preview, 256);
      final data = await small.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      final (w, h) = (small.width, small.height);
      small.dispose();
      if (data == null) return;
      final analysis = PhotoAnalysis.fromRgba(data.buffer.asUint8List(), w, h);
      var suggestions = suggestFixes(analysis);
      // Scene-aware refinement (v1.4): classify the same proxy with the
      // small MobileNetV2 model **only when it is already installed** —
      // suggestions never trigger a download, and any failure here keeps
      // the statistics-based ranking.
      try {
        if (await ref.read(modelManagerProvider).isInstalled(ModelRegistry.mobilenetScene)) {
          final scene = await ref.read(sceneClassifierPipelineProvider).run(RgbaImage(w, h, data.buffer.asUint8List()));
          suggestions = suggestFixes(analysis, scene: scene);
        }
      } on Object catch (e, st) {
        CrashLog.instance.record('scene', '$e', st);
      }
      state = state.copyWith(suggestions: suggestions);
    } on Object catch (e, st) {
      CrashLog.instance.record('analyse', '$e', st);
    }
  }

  /// One-tap suggestion: added on top of the current edit (one undo step).
  void applySuggestion(Suggestion s) {
    final id = s.libraryPresetId;
    if (id != null) {
      applyPreset(id);
    } else {
      updateAdjustments((a) => s.preset.apply(a));
    }
  }

  // ------------------------------------------------------ tap to select

  /// Enters tap-to-select: encodes the photo once (MobileSAM encoder).
  Future<void> startSelection() => _busy(() async {
    await ref.read(objectSelectPipelineProvider).prepare(_currentRaster);
    _dropSelection();
    state = state.copyWith(selecting: true, selectAdd: true);
    unawaited(_render());
  }, label: 'select: encode');

  void setSelectAdd({required bool value}) => state = state.copyWith(selectAdd: value);

  /// Switches how the next selection prompt is given (tap / box / brush).
  void setSelectMode(SelectPromptMode mode) => state = state.copyWith(selectMode: mode);

  /// Adds a prompt point at [normalized] (0..1 on the displayed, un-framed
  /// output image) and refreshes the selection.
  Future<void> selectAt(Offset normalized) async {
    final preview = state.preview;
    if (!state.selecting || preview == null) return;
    final (u, v) = _toSource(normalized, preview.width, preview.height);
    final point = SelectPoint(u / preview.width, v / preview.height, positive: state.selectAdd);
    await _updateSelection([...state.selectPoints, point]);
  }

  /// Removes the last prompt point.
  Future<void> undoSelectPoint() async {
    final pts = state.selectPoints;
    if (pts.isEmpty) return;
    await _updateSelection(pts.sublist(0, pts.length - 1));
  }

  void clearSelection() {
    _selectionMask = null;
    _candidateMasks = const [];
    _setOverlay(null);
    state = state.copyWith(
      selectPoints: const [],
      hasSelection: false,
      selectCandidates: const [],
      selectCandidateIndex: 0,
    );
  }

  /// Leaves tap-to-select without applying anything.
  void cancelSelection() {
    _dropSelection();
    unawaited(_render());
  }

  void _dropSelection() {
    if (!state.selecting && _selectionMask == null) return;
    _selectionMask = null;
    _candidateMasks = const [];
    _setOverlay(null);
    state = state.copyWith(
      selecting: false,
      selectPoints: const [],
      hasSelection: false,
      selectCandidates: const [],
      selectCandidateIndex: 0,
      selectMode: SelectPromptMode.tap,
    );
  }

  void _setOverlay(ui.Image? img) {
    final old = _lastSelectOverlay;
    _lastSelectOverlay = img;
    state = state.copyWith(selectOverlay: () => img);
    if (old != null) WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  Future<void> _updateSelection(List<SelectPoint> points, {SelectBox? box, Float32List? maskInput}) async {
    state = state.copyWith(selectPoints: points);
    if (points.isEmpty && box == null) {
      clearSelection();
      return;
    }
    await _busy(() async {
      final pipeline = ref.read(objectSelectPipelineProvider);
      await pipeline.prepare(_currentRaster);
      final candidates = await pipeline.candidatesFor(points, box: box, maskInput: maskInput);
      _candidateMasks = [for (final c in candidates) c.mask];
      await _applyCandidate(0, [for (final c in candidates) c.iou]);
    }, label: 'select: decode');
  }

  List<RgbaImage> _candidateMasks = const [];

  /// Shows candidate [index] of the last decode (the multi-mask decoder
  /// returns part/whole-object guesses ranked by IoU).
  Future<void> selectCandidate(int index) async {
    if (_candidateMasks.isEmpty || state.busy) return;
    await _applyCandidate(index, state.selectCandidates);
  }

  Future<void> _applyCandidate(int index, List<double> ious) async {
    if (_candidateMasks.isEmpty) return;
    final i = index.clamp(0, _candidateMasks.length - 1);
    final mask = _candidateMasks[i];
    _selectionMask = featherSelection(mask);
    final overlay = await _selectionOverlay(_selectionMask!);
    _setOverlay(overlay);
    state = state.copyWith(hasSelection: maskCoverage(mask) > 0, selectCandidates: ious, selectCandidateIndex: i);
  }

  /// Box prompt: the drag rectangle selects the object it encloses (and
  /// replaces the accumulated tap points).
  Future<void> setSelectionBox(SelectBox box) async {
    if (!state.selecting) return;
    await _updateSelection(const [], box: box);
  }

  /// Brush refinement: the painted strokes become SAM's `mask_input` and
  /// the decoder re-runs with `has_mask_input = 1`, pulling the selection
  /// towards (or away from, for eraser strokes) the painted area.
  Future<void> refineSelection(List<Stroke> strokes) => _busy(() async {
    if (!state.selecting) return;
    final pipeline = ref.read(objectSelectPipelineProvider);
    await pipeline.prepare(_currentRaster);
    final raster = _currentRaster;
    final (sw, sh) = await _rasterSize(raster);
    final painted = await _strokesToSourceMask(strokes, sw, sh, maxSide: 256);
    final input = strokeMaskInput(painted);
    final candidates = await pipeline.candidatesFor(state.selectPoints, maskInput: input);
    _candidateMasks = [for (final c in candidates) c.mask];
    await _applyCandidate(0, [for (final c in candidates) c.iou]);
  }, label: 'select: refine');

  /// Tinted overlay of a source-space [mask] warped into the output frame
  /// (crop/rotation applied) so it lines up with the canvas.
  Future<ui.Image> _selectionOverlay(RgbaImage mask) async {
    final g = state.edit.geometry;
    final mw = mask.width;
    final mh = mask.height;
    final (ow, oh) = g.outputSize(mw, mh);
    final w = math.max(1, ow);
    final h = math.max(1, oh);
    final inv = buildInverseWarp(g, mw, mh, w, h);
    final out = Uint8List(w * h * 4);
    bool on(int x, int y) => x >= 0 && y >= 0 && x < mw && y < mh && mask.pixels[(y * mw + x) * 4] > 127;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final (u, v) = inv.apply(x + 0.5, y + 0.5);
        final sx = (u * mw).floor();
        final sy = (v * mh).floor();
        if (!on(sx, sy)) continue;
        final edge = !on(sx - 2, sy) || !on(sx + 2, sy) || !on(sx, sy - 2) || !on(sx, sy + 2);
        final o = (y * w + x) * 4;
        // Soft violet (#6E5FE0) tint, brighter outline.
        out[o] = edge ? 0xB8 : 0x6E;
        out[o + 1] = edge ? 0xB0 : 0x5F;
        out[o + 2] = edge ? 0xFF : 0xE0;
        out[o + 3] = edge ? 230 : 110;
      }
    }
    return imageFromRgba(out, w, h);
  }

  /// Uses the current selection: erase it, cut it out, turn it into a
  /// masked adjustment, or blur everything else.
  Future<void> applySelection(SelectionAction action) => _busy(() async {
    final mask = _selectionMask;
    if (mask == null) return;
    final raster = _currentRaster;
    switch (action) {
      case SelectionAction.erase:
        final out = await ref.read(inpaintPipelineProvider).run(raster, mask);
        update((s) => s.copyWith(rasterPath: out));
      case SelectionAction.cutOut:
        final src = await loadRgba(raster, maxSide: InpaintPipeline.maxSide);
        final cut = await Isolate.run(() => applyMaskAsAlpha(src, boxBlurMask(mask, 1).resize(src.width, src.height)));
        final path = await savePng(cut, 'cutout');
        update((s) => s.copyWith(rasterPath: path));
      case SelectionAction.adjust:
      case SelectionAction.blurBackground:
        final path = await savePng(await Isolate.run(() => boxBlurMask(mask, 2)), 'selection');
        _dropSelection();
        final blur = action == SelectionAction.blurBackground;
        addMask(
          MaskKind.subject,
          maskPath: path,
          adjustments: blur ? const Adjustments(blur: 0.5) : const Adjustments(exposure: 0.3),
          invert: blur,
        );
        if (!blur) state = state.copyWith(tool: EditorTool.masks);
        unawaited(_render());
        return;
    }
    _dropSelection();
    unawaited(_render());
  }, label: 'select: ${action.name}');

  // ------------------------------------------------------ depth & people

  /// Depth-graded background blur ([relight] = false) or relighting: the
  /// subject is lifted and the background dimmed, both following depth.
  Future<void> depthEffect({bool relight = false}) => _busy(() async {
    final depth = await ref.read(depthPipelineProvider).estimate(_currentRaster);
    if (!relight) {
      final path = await savePng(await Isolate.run(() => depthBlurMask(depth)), 'depth_blur');
      addMask(MaskKind.subject, maskPath: path, adjustments: const Adjustments(blur: 0.6));
      return;
    }
    final near = await savePng(await Isolate.run(() => depthNearMask(depth)), 'depth_near');
    final idNear = _uuid.v4();
    final idFar = _uuid.v4();
    update(
      (s) => s.copyWith(
        localAdjustments: [
          ...s.localAdjustments,
          LocalAdjustment(
            id: idNear,
            kind: MaskKind.subject,
            geometry: const [0.5, 0.5, 0.3, 0.3],
            maskPath: near,
            adjustments: const Adjustments(exposure: 0.3, shadows: 0.15, temperature: 0.04),
          ),
          LocalAdjustment(
            id: idFar,
            kind: MaskKind.subject,
            geometry: const [0.5, 0.5, 0.3, 0.3],
            maskPath: near,
            invert: true,
            adjustments: const Adjustments(exposure: -0.45, saturation: -0.1),
          ),
        ],
      ),
    );
    selectMask(idNear);
  }, label: relight ? 'depth relight' : 'depth blur');

  /// Removes the main person: portrait matte → object eraser.
  Future<void> erasePerson() => _busy(() async {
    final raster = _currentRaster;
    final seg = await ref.read(segmentationPipelineProvider).run(raster, portrait: true);
    final mask = await loadRgba(seg.maskPath, maxSide: InpaintPipeline.maxSide);
    if (maskCoverage(mask) < 0.005) throw const SmartEditException(SmartEditFailure.noPerson);
    final out = await ref.read(inpaintPipelineProvider).run(raster, mask);
    update((s) => s.copyWith(rasterPath: out));
  }, label: 'erase person');

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
    unawaited(_analyse());
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
