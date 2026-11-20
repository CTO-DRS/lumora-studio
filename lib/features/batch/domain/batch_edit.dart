import 'package:lumora/features/photo_editor/domain/auto_enhance.dart';
import 'package:lumora/features/photo_editor/domain/edit_clipboard.dart';
import 'package:lumora/features/photo_editor/domain/edit_state.dart';
import 'package:lumora/features/photo_editor/domain/presets.dart';

/// What a batch run applies to every photo.
class BatchRecipe {
  const BatchRecipe({this.copied, this.preset, this.intensity = 1, this.autoEnhance = false});

  /// Edits copied from another photo (look, gradient masks, frame,
  /// watermark; never crop or AI pixels).
  final EditState? copied;

  /// A look applied on top.
  final Preset? preset;
  final double intensity;

  /// Per-photo auto enhance (computed from each photo's own statistics).
  final bool autoEnhance;

  bool get isEmpty => copied == null && preset == null && !autoEnhance;
}

/// Builds the edit for one photo. [stats] are that photo's statistics,
/// needed only when [BatchRecipe.autoEnhance] is on.
EditState buildBatchEdit(BatchRecipe recipe, {ImageStats? stats}) {
  var edit = EditState.initial;
  final copied = recipe.copied;
  if (copied != null) {
    edit = pasteEdit(edit, copied);
  }
  if (recipe.autoEnhance && stats != null) {
    edit = edit.copyWith(adjustments: autoEnhance(stats, base: edit.adjustments));
  }
  final preset = recipe.preset;
  if (preset != null) {
    edit = edit.copyWith(
      presetId: preset.id,
      presetIntensity: recipe.intensity,
      adjustments: preset.apply(edit.adjustments, intensity: recipe.intensity),
    );
  }
  return edit;
}

enum BatchItemStatus { pending, running, done, failed }
