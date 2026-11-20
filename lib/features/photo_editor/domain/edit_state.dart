import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/photo_editor/domain/geometry.dart';
import 'package:lumora/features/photo_editor/domain/layers.dart';

part 'edit_state.freezed.dart';
part 'edit_state.g.dart';

/// The complete, serializable description of a photo edit. The original
/// file is never modified; rendering always starts from [rasterPath] (or the
/// original when null) and replays this recipe.
@freezed
abstract class EditState with _$EditState {
  const factory EditState({
    @Default(Adjustments()) Adjustments adjustments,
    @Default(GeometryState()) GeometryState geometry,
    @Default(<OverlayLayer>[]) List<OverlayLayer> layers,
    @Default(<LocalAdjustment>[]) List<LocalAdjustment> localAdjustments,
    String? presetId,
    @Default(1) double presetIntensity,

    /// Result of a destructive AI step (background removal, inpainting,
    /// upscaling) stored as a new file. Undo simply restores the previous
    /// path, so the AI step itself stays non-destructive.
    String? rasterPath,
  }) = _EditState;

  const EditState._();

  factory EditState.fromJson(Map<String, dynamic> json) => _$EditStateFromJson(json);

  static const initial = EditState();
}
