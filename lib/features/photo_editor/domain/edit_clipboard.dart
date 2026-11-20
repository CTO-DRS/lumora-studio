import 'dart:convert';

import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/photo_editor/domain/edit_state.dart';
import 'package:lumora/features/photo_editor/domain/layers.dart';

/// Which parts of a copied edit are pasted.
class PasteOptions {
  const PasteOptions({
    this.adjustments = true,
    this.geometry = false,
    this.masks = true,
    this.overlays = false,
    this.finishing = true,
  });

  /// Global light/colour/detail/effects, curves, LUT and preset.
  final bool adjustments;

  /// Crop, rotation, straighten, flips and perspective.
  final bool geometry;

  /// Brush/gradient masks. AI subject masks are image specific and are
  /// never pasted.
  final bool masks;

  /// Text, stickers and drawings.
  final bool overlays;

  /// Frame and watermark.
  final bool finishing;

  PasteOptions copyWith({bool? adjustments, bool? geometry, bool? masks, bool? overlays, bool? finishing}) =>
      PasteOptions(
        adjustments: adjustments ?? this.adjustments,
        geometry: geometry ?? this.geometry,
        masks: masks ?? this.masks,
        overlays: overlays ?? this.overlays,
        finishing: finishing ?? this.finishing,
      );
}

/// Applies the parts of [copied] selected by [options] to [target]. The
/// target's own pixels (`rasterPath`) are always kept.
EditState pasteEdit(EditState target, EditState copied, {PasteOptions options = const PasteOptions()}) {
  var out = target;
  if (options.adjustments) {
    out = out.copyWith(
      adjustments: copied.adjustments,
      presetId: copied.presetId,
      presetIntensity: copied.presetIntensity,
    );
  }
  if (options.geometry) out = out.copyWith(geometry: copied.geometry);
  if (options.masks) {
    out = out.copyWith(
      localAdjustments: [
        ...target.localAdjustments,
        for (final m in copied.localAdjustments)
          if (m.kind != MaskKind.subject) m.copyWith(id: '${m.id}-p${target.localAdjustments.length}'),
      ],
    );
  }
  if (options.overlays) {
    out = out.copyWith(
      layers: [
        ...target.layers,
        for (final l in copied.layers) l.copyWith(id: '${l.id}-p${target.layers.length}'),
      ],
    );
  }
  if (options.finishing) out = out.copyWith(frame: copied.frame, watermark: copied.watermark);
  return out;
}

/// Strips the parts of [s] that only make sense for its own image before it
/// is put on the clipboard.
EditState clipboardCopy(EditState s) => s.copyWith(
  rasterPath: null,
  localAdjustments: s.localAdjustments.where((m) => m.kind != MaskKind.subject).toList(),
);

String encodeClipboard(EditState s) => jsonEncode(s.toJson());

EditState? decodeClipboard(String? source) {
  if (source == null || source.isEmpty) return null;
  try {
    return EditState.fromJson(jsonDecode(source) as Map<String, dynamic>);
  } on Object {
    return null;
  }
}

/// Short, human readable summary of the differences between two states,
/// used by the history panel. Returns a stable key the UI localises.
enum EditChange {
  initial,
  preset,
  light,
  color,
  hsl,
  curves,
  lut,
  detail,
  effects,
  crop,
  layers,
  masks,
  ai,
  frame,
  watermark,
  other,
}

EditChange describeChange(EditState? before, EditState after) {
  if (before == null) return EditChange.initial;
  if (before.rasterPath != after.rasterPath) return EditChange.ai;
  if (before.presetId != after.presetId || before.presetIntensity != after.presetIntensity) return EditChange.preset;
  if (before.geometry != after.geometry) return EditChange.crop;
  if (!_listEq(before.localAdjustments, after.localAdjustments)) return EditChange.masks;
  if (!_listEq(before.layers, after.layers)) return EditChange.layers;
  if (before.frame != after.frame) return EditChange.frame;
  if (before.watermark != after.watermark) return EditChange.watermark;
  final a = before.adjustments;
  final b = after.adjustments;
  if (a == b) return EditChange.other;
  if (a.curves != b.curves) return EditChange.curves;
  if (a.hsl != b.hsl) return EditChange.hsl;
  if (a.lutId != b.lutId || a.lutIntensity != b.lutIntensity) return EditChange.lut;
  bool changed(List<AdjustmentParam> ps) => ps.any((p) => p.read(a) != p.read(b));
  if (changed(const [
    AdjustmentParam.exposure,
    AdjustmentParam.contrast,
    AdjustmentParam.highlights,
    AdjustmentParam.shadows,
    AdjustmentParam.whites,
    AdjustmentParam.blacks,
  ])) {
    return EditChange.light;
  }
  if (changed(const [
        AdjustmentParam.temperature,
        AdjustmentParam.tint,
        AdjustmentParam.vibrance,
        AdjustmentParam.saturation,
        AdjustmentParam.fade,
      ]) ||
      a.splitTone != b.splitTone) {
    return EditChange.color;
  }
  if (changed(const [
    AdjustmentParam.sharpen,
    AdjustmentParam.clarity,
    AdjustmentParam.structure,
    AdjustmentParam.dehaze,
    AdjustmentParam.blur,
  ])) {
    return EditChange.detail;
  }
  return EditChange.effects;
}

bool _listEq<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
