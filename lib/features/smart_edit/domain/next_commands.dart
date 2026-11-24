import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/smart_edit/domain/edit_ops.dart';

/// Follow-up commands offered in the Smart bar right after a plan is
/// applied ("what would you like next?"). Pure function so the chains can
/// be unit tested and later swapped for photo-aware suggestions (v1.5+).
///
/// Every returned phrase is guaranteed to parse into a non-empty plan by
/// the rule engine (enforced by tests).
List<String> nextCommands({required String lang, required SmartEditPlan plan}) {
  final ar = lang == 'ar';
  final out = <String>[];
  void add(String arPhrase, String enPhrase) {
    final c = ar ? arPhrase : enPhrase;
    if (!out.contains(c)) out.add(c);
  }

  for (final op in plan.ops) {
    switch (op) {
      case AdjustOp(:final param, :final amount):
        if (param == AdjustmentParam.exposure && amount > 0) add('زد التباين', 'more contrast');
        if (param == AdjustmentParam.contrast && amount > 0) {
          add('قلل الإضاءات العالية قليلًا', 'reduce the highlights a bit');
        }
        if (param == AdjustmentParam.temperature && amount > 0) add('أضف تظليل للحواف', 'add vignette');
        if (param == AdjustmentParam.saturation || param == AdjustmentParam.vibrance) {
          add('اجعلها أدفأ', 'make it warmer');
        }
        if ((param == AdjustmentParam.blur && amount > 0) || param == AdjustmentParam.vignette) {
          add('زد الحدة', 'sharpen');
        }
      case LookOp():
        add('أضف حبيبات', 'add film grain');
      case ActionOp(:final action):
        switch (action) {
          case SmartAction.blurBackground || SmartAction.depthBlur:
            add('زد التمويه', 'more blur');
          case SmartAction.removeBackground || SmartAction.cutOutPerson:
            add('حسن الصورة', 'enhance');
          case SmartAction.erasePerson:
            add('كبر الصورة', 'upscale');
          case SmartAction.retouch:
            add('زد السطوع قليلاً', 'brighten a bit');
          case SmartAction.upscale:
            add('زد التباين', 'more contrast');
          default:
            break;
        }
    }
  }
  if (out.isEmpty) add('زد التباين', 'more contrast');
  add('سينمائي', 'cinematic'); // a creative finisher
  return out.take(3).toList();
}
