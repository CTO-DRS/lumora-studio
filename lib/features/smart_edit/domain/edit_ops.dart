import 'package:flutter/foundation.dart' show immutable;
import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/photo_editor/domain/geometry.dart';

/// Editor actions a smart-edit command can ask for besides slider changes.
enum SmartAction {
  // Instant, model-free.
  autoEnhance,
  clearLook,
  reset,
  undo,
  rotateLeft,
  rotateRight,
  flipHorizontal,
  flipVertical,
  // Tools that need the user's input next (painting / tapping).
  eraseObject,
  selectObject,
  heal,
  // On-device AI (models downloaded on demand).
  removeBackground,
  cutOutPerson,
  blurBackground,
  depthBlur,
  relight,
  retouch,
  upscale,
  erasePerson;

  /// Whether the action changes the edit without any further input or
  /// model (applied immediately and atomically with slider changes).
  bool get instant => index <= flipVertical.index;
}

/// One operation of a [SmartEditPlan]. Plans are plain data so that any
/// intent engine (the rule engine today, an on-device LLM later) can
/// produce them, and they serialise to the JSON schema in
/// `docs/SMART_EDIT.md`.
sealed class EditOp {
  const EditOp();

  Map<String, Object?> toJson();

  static EditOp fromJson(Map<String, Object?> json) => switch (json['op']) {
    'adjust' => AdjustOp(
      AdjustmentParam.values.byName(json['param']! as String),
      (json['amount']! as num).toDouble(),
      absolute: json['absolute'] == true,
    ),
    'look' => LookOp(json['preset']! as String, intensity: (json['intensity'] as num?)?.toDouble() ?? 1),
    'action' => ActionOp(SmartAction.values.byName(json['action']! as String)),
    _ => throw FormatException('Unknown smart edit op: ${json['op']}'),
  };
}

/// Changes one slider by [amount] (relative) or sets it to [amount]
/// ([absolute]). Values use the slider's own units (EV for exposure).
@immutable
class AdjustOp extends EditOp {
  const AdjustOp(this.param, this.amount, {this.absolute = false});

  final AdjustmentParam param;
  final double amount;
  final bool absolute;

  @override
  Map<String, Object?> toJson() => {'op': 'adjust', 'param': param.name, 'amount': amount, 'absolute': absolute};

  @override
  bool operator ==(Object other) =>
      other is AdjustOp && other.param == param && (other.amount - amount).abs() < 1e-9 && other.absolute == absolute;

  @override
  int get hashCode => Object.hash(param, amount.toStringAsFixed(6), absolute);

  @override
  String toString() =>
      'AdjustOp(${param.name}, ${absolute ? '=' : (amount >= 0 ? '+' : '')}${amount.toStringAsFixed(3)})';
}

/// Applies a built-in look at [intensity] (0..1).
@immutable
class LookOp extends EditOp {
  const LookOp(this.presetId, {this.intensity = 1});

  final String presetId;
  final double intensity;

  @override
  Map<String, Object?> toJson() => {'op': 'look', 'preset': presetId, 'intensity': intensity};

  @override
  bool operator ==(Object other) =>
      other is LookOp && other.presetId == presetId && (other.intensity - intensity).abs() < 1e-9;

  @override
  int get hashCode => Object.hash(presetId, intensity.toStringAsFixed(6));

  @override
  String toString() => 'LookOp($presetId @ ${intensity.toStringAsFixed(2)})';
}

/// Runs an editor action.
@immutable
class ActionOp extends EditOp {
  const ActionOp(this.action);

  final SmartAction action;

  @override
  Map<String, Object?> toJson() => {'op': 'action', 'action': action.name};

  @override
  bool operator ==(Object other) => other is ActionOp && other.action == action;

  @override
  int get hashCode => action.hashCode;

  @override
  String toString() => 'ActionOp(${action.name})';
}

/// The result of interpreting a command: operations in order plus the
/// fragments that were not understood (shown to the user).
class SmartEditPlan {
  const SmartEditPlan({this.ops = const [], this.unrecognized = const []});

  factory SmartEditPlan.fromJson(Map<String, Object?> json) => SmartEditPlan(
    ops: [for (final o in (json['ops']! as List)) EditOp.fromJson((o as Map).cast<String, Object?>())],
    unrecognized: [for (final u in (json['unrecognized'] as List?) ?? const []) u as String],
  );

  final List<EditOp> ops;
  final List<String> unrecognized;

  bool get isEmpty => ops.isEmpty;

  Iterable<AdjustOp> get adjustments => ops.whereType<AdjustOp>();

  Iterable<LookOp> get looks => ops.whereType<LookOp>();

  Iterable<SmartAction> get actions => ops.whereType<ActionOp>().map((o) => o.action);

  Map<String, Object?> toJson() => {
    'ops': [for (final o in ops) o.toJson()],
    'unrecognized': unrecognized,
  };

  @override
  String toString() => 'SmartEditPlan($ops${unrecognized.isEmpty ? '' : ', ?$unrecognized'})';
}

/// Applies the slider operations of a plan to [a] (clamped to each slider's
/// range). Relative amounts are added; absolute amounts replace.
Adjustments applyAdjustOps(Adjustments a, Iterable<AdjustOp> ops) {
  var out = a;
  for (final op in ops) {
    final v = op.absolute ? op.amount : op.param.read(out) + op.amount;
    out = op.param.write(out, v);
  }
  return out;
}

/// Applies an instant geometry action (rotate / flip) to [g]; other actions
/// leave it unchanged.
GeometryState applyGeometryAction(GeometryState g, SmartAction action) => switch (action) {
  SmartAction.rotateRight => g.copyWith(quarterTurns: (g.quarterTurns + 1) % 4).withoutCrop(),
  SmartAction.rotateLeft => g.copyWith(quarterTurns: (g.quarterTurns + 3) % 4).withoutCrop(),
  SmartAction.flipHorizontal => g.copyWith(flipHorizontal: !g.flipHorizontal),
  SmartAction.flipVertical => g.copyWith(flipVertical: !g.flipVertical),
  _ => g,
};

/// Why a smart action could not run (shown in plain words).
enum SmartEditFailure { noPerson, noSelection }

class SmartEditException implements Exception {
  const SmartEditException(this.failure);

  final SmartEditFailure failure;

  @override
  String toString() => 'SmartEditException(${failure.name})';
}
