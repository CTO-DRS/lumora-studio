import 'package:flutter/foundation.dart' show immutable;
import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/smart_edit/domain/edit_ops.dart';

/// Follow-up commands the Smart bar offers right after an edit (v1.3.x
/// "suggestions of next commands"). Every entry maps to a command phrase
/// the rule engine already understands in Arabic and English, so tapping a
/// chip just submits that text — same path as typing it.
@immutable
enum NextCommand {
  warmer('smartNextWarmer'),
  cooler('smartNextCooler'),
  removeLook('smartNextRemoveLook'),
  contrast('smartNextContrast'),
  sharpen('smartNextSharpen'),
  portrait('smartNextPortrait'),
  mono('smartNextMono'),
  vignette('smartNextVignette'),
  upscale('smartNextUpscale');

  const NextCommand(this.labelKey);

  /// Key of the localised command phrase in the `.arb` files.
  final String labelKey;
}

/// The starter set for "nothing applied yet" (and the tail after short
/// plans): cheap, broadly useful commands.
const List<NextCommand> kDefaultNextCommands = [
  NextCommand.contrast,
  NextCommand.mono,
  NextCommand.portrait,
];

/// Ranks follow-ups for [last] (best first, at most [max]).
///
/// Deterministic and model-free: it reads the plan the user just applied
/// and offers the natural next step — remove a look before piling another
/// on, reverse a temperature change, sharpen after AI work, and so on.
List<NextCommand> nextCommands(SmartEditPlan? last, {int max = 3}) {
  final out = <NextCommand>[];
  void add(NextCommand c) {
    if (!out.contains(c)) out.add(c);
  }

  if (last == null || last.isEmpty) {
    return kDefaultNextCommands.take(max).toList();
  }
  for (final op in last.ops) {
    switch (op) {
      case LookOp():
        add(NextCommand.removeLook);
        add(NextCommand.contrast);
        add(NextCommand.sharpen);
      case AdjustOp(:final param, :final amount, :final absolute):
        if (param == AdjustmentParam.temperature && !absolute && amount > 0) {
          add(NextCommand.cooler);
        } else if (param == AdjustmentParam.temperature && !absolute && amount < 0) {
          add(NextCommand.warmer);
        }
        add(NextCommand.sharpen);
        add(NextCommand.mono);
      case ActionOp(:final action):
        add(NextCommand.contrast);
        add(NextCommand.mono);
        // After model-backed work the result can still be small on screen.
        if (!action.instant) add(NextCommand.upscale);
    }
    if (out.length >= max) break;
  }
  for (final c in kDefaultNextCommands) {
    if (out.length >= max) break;
    add(c);
  }
  return out.take(max).toList();
}
