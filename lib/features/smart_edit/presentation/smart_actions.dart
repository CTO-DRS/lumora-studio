import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumora/core/utils/l10n_ext.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:lumora/features/ai/pipelines/face_pipeline.dart';
import 'package:lumora/features/ai/pipelines/sky_pipeline.dart';
import 'package:lumora/features/ai/presentation/model_download_dialog.dart';
import 'package:lumora/features/photo_editor/data/preset_store.dart';
import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/photo_editor/domain/presets.dart';
import 'package:lumora/features/photo_editor/presentation/photo_editor_controller.dart';
import 'package:lumora/features/photo_editor/presentation/widgets/tool_panels.dart' show paramLabel;
import 'package:lumora/features/smart_edit/domain/edit_ops.dart';
import 'package:lumora/features/smart_edit/domain/intent_engine.dart';
import 'package:lumora/features/smart_edit/domain/photo_analysis.dart';
import 'package:lumora/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The intent engine used by the editor (rule based today; an on-device
/// LLM engine can be swapped in here without touching the UI).
final Provider<EditIntentEngine> editIntentEngineProvider = Provider<EditIntentEngine>(
  (ref) => const RuleIntentEngine(),
);

/// Interprets [text], applies it and reports what happened.
Future<SmartEditPlan> runSmartCommand(BuildContext context, WidgetRef ref, String text) async {
  final l = context.l10n;
  final lang = Localizations.localeOf(context).languageCode;
  final messenger = ScaffoldMessenger.of(context);
  final plan = ref.read(editIntentEngineProvider).parse(text);
  if (plan.isEmpty) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            text.trim().isEmpty ? l.smartNothing : '${l.smartNotUnderstood(text.trim())}\n${l.smartNothing}',
          ),
        ),
      );
    return plan;
  }
  final ctrl = ref.read(photoEditorControllerProvider.notifier);
  final pending = await ctrl.applySmartPlan(plan);
  final summary = describePlan(l, lang, plan, ref.read(presetLibraryControllerProvider).byId);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          [
            l.smartApplied(summary),
            if (plan.unrecognized.isNotEmpty) l.smartNotUnderstood(plan.unrecognized.join(', ')),
          ].join('\n'),
        ),
      ),
    );
  for (final action in pending) {
    if (!context.mounted) break;
    await runSmartAction(context, ref, action);
  }
  return plan;
}

/// Runs one model-backed or interactive action, asking before any model
/// download. Returns false when the user declined or it could not start.
Future<bool> runSmartAction(BuildContext context, WidgetRef ref, SmartAction action) async {
  final ctrl = ref.read(photoEditorControllerProvider.notifier);
  Future<bool> models(AiTool tool) async =>
      context.mounted && await ensureModelsDownloaded(context, ref, aiToolModels(tool));
  switch (action) {
    case SmartAction.removeBackground:
      if (!await models(AiTool.removeBackground)) return false;
      await ctrl.removeBackground();
    case SmartAction.cutOutPerson:
      if (!await models(AiTool.cutOutPerson)) return false;
      await ctrl.removeBackground(portrait: true);
    case SmartAction.blurBackground:
      if (!await models(AiTool.backgroundBlur)) return false;
      await ctrl.subjectAdjustment(blurBackground: true);
    case SmartAction.retouch:
      if (!await models(AiTool.portraitRetouch)) return false;
      await ctrl.subjectAdjustment(retouch: true);
    case SmartAction.upscale:
      if (!await models(AiTool.upscale)) return false;
      await ctrl.upscale();
    case SmartAction.depthBlur:
      if (!await models(AiTool.depthBlur)) return false;
      await ctrl.depthEffect();
    case SmartAction.relight:
      if (!await models(AiTool.relight)) return false;
      await ctrl.depthEffect(relight: true);
    case SmartAction.erasePerson:
      if (!await models(AiTool.erasePerson)) return false;
      await ctrl.erasePerson();
    case SmartAction.faceRetouch:
      if (!await models(AiTool.faceRetouch)) return false;
      await ctrl.faceAdjustment(FaceRegion.skin);
    case SmartAction.eyeBrighten:
      if (!await models(AiTool.eyeBrighten)) return false;
      await ctrl.faceAdjustment(FaceRegion.eyes);
    case SmartAction.teethWhiten:
      if (!await models(AiTool.teethWhiten)) return false;
      await ctrl.faceAdjustment(FaceRegion.teeth);
    case SmartAction.skyDeepen:
      if (!await models(AiTool.skyDeepen)) return false;
      await ctrl.skyDeepen();
    case SmartAction.skyReplaceSunset:
      if (!await models(AiTool.skyReplace)) return false;
      await ctrl.skyReplace(SkyPreset.sunset);
    case SmartAction.skyReplaceClear:
      if (!await models(AiTool.skyReplace)) return false;
      await ctrl.skyReplace(SkyPreset.clear);
    case SmartAction.skyReplaceStorm:
      if (!await models(AiTool.skyReplace)) return false;
      await ctrl.skyReplace(SkyPreset.storm);
    case SmartAction.skyReplaceGolden:
      if (!await models(AiTool.skyReplace)) return false;
      await ctrl.skyReplace(SkyPreset.golden);
    case SmartAction.eraseObject:
      if (!await models(AiTool.eraser)) return false;
      ctrl
        ..setTool(EditorTool.ai)
        ..setEraserMode(value: true);
    case SmartAction.selectObject:
      if (!await models(AiTool.selectObject)) return false;
      ctrl.setTool(EditorTool.ai);
      await ctrl.startSelection();
    case SmartAction.heal:
      ctrl.setTool(EditorTool.heal);
    case SmartAction.autoEnhance ||
        SmartAction.autoStraighten ||
        SmartAction.clearLook ||
        SmartAction.reset ||
        SmartAction.undo ||
        SmartAction.rotateLeft ||
        SmartAction.rotateRight ||
        SmartAction.flipHorizontal ||
        SmartAction.flipVertical:
      // Applied atomically by applySmartPlan.
      break;
  }
  return true;
}

/// A short, human summary of [plan] ("Temperature +20 · Mono").
String describePlan(AppLocalizations l, String lang, SmartEditPlan plan, Preset? Function(String? id) presetById) {
  final parts = <String>[];
  for (final op in plan.ops) {
    switch (op) {
      case AdjustOp(:final param, :final amount, :final absolute):
        parts.add('${paramLabel(l, param)} ${formatParamValue(param, amount, absolute: absolute)}');
      case LookOp(:final presetId, :final intensity):
        final name = presetById(presetId)?.name(lang) ?? presetId;
        parts.add(intensity < 0.99 ? '$name ${(intensity * 100).round()}%' : name);
      case ActionOp(:final action):
        parts.add(smartActionLabel(l, action));
    }
  }
  return parts.join(' · ');
}

/// "+20", "−0.35 EV", "= 30".
String formatParamValue(AdjustmentParam param, double v, {bool absolute = false}) {
  final ev = param == AdjustmentParam.exposure;
  final shown = ev ? v.toStringAsFixed(2) : (v * 100).round().toString();
  final signed = absolute ? '= ${shown.replaceFirst('-', '−')}' : (v >= 0 ? '+$shown' : shown.replaceFirst('-', '−'));
  return ev ? '$signed EV' : signed;
}

String smartActionLabel(AppLocalizations l, SmartAction a) => switch (a) {
  SmartAction.autoEnhance => l.aiAutoEnhance,
  SmartAction.autoStraighten => l.autoStraighten,
  SmartAction.clearLook => l.removeLook,
  SmartAction.reset => l.resetAll,
  SmartAction.undo => l.undo,
  SmartAction.rotateLeft || SmartAction.rotateRight => l.rotate,
  SmartAction.flipHorizontal => l.flipH,
  SmartAction.flipVertical => l.flipV,
  SmartAction.eraseObject => l.aiEraser,
  SmartAction.selectObject => l.aiSelectObject,
  SmartAction.heal => l.toolHeal,
  SmartAction.removeBackground => l.aiRemoveBg,
  SmartAction.cutOutPerson => l.aiPortraitBg,
  SmartAction.blurBackground => l.aiBlurBg,
  SmartAction.depthBlur => l.aiDepthBlur,
  SmartAction.relight => l.aiRelight,
  SmartAction.retouch => l.aiRetouch,
  SmartAction.upscale => l.aiUpscale,
  SmartAction.erasePerson => l.aiErasePerson,
  SmartAction.faceRetouch => l.aiFaceRetouch,
  SmartAction.eyeBrighten => l.aiEyeBrighten,
  SmartAction.teethWhiten => l.aiTeethWhiten,
  SmartAction.skyDeepen => l.aiSkyDeepen,
  SmartAction.skyReplaceSunset => l.aiSkyReplaceSunset,
  SmartAction.skyReplaceClear => l.aiSkyReplaceClear,
  SmartAction.skyReplaceStorm => l.aiSkyReplaceStorm,
  SmartAction.skyReplaceGolden => l.aiSkyReplaceGolden,
};

String suggestionLabel(AppLocalizations l, SuggestionKind k) => switch (k) {
  SuggestionKind.autoFix => l.sugAutoFix,
  SuggestionKind.brighten => l.sugBrighten,
  SuggestionKind.recoverHighlights => l.sugRecover,
  SuggestionKind.fixColor => l.sugFixColor,
  SuggestionKind.portrait => l.sugPortrait,
  SuggestionKind.sky => l.sugSky,
  SuggestionKind.landscape => l.sugLandscape,
  SuggestionKind.document => l.sugDocument,
  SuggestionKind.clearHaze => l.sugClearHaze,
  SuggestionKind.vivid => l.sugVivid,
  SuggestionKind.cinematic => l.sugCinematic,
  SuggestionKind.mono => l.sugMono,
};
