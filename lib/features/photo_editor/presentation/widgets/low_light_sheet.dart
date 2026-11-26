import 'dart:async';

import 'package:lumora/core/utils/l10n_ext.dart';
import 'package:lumora/core/widgets/labeled_slider.dart';
import 'package:lumora/features/photo_editor/engine/low_light.dart' as low_light;
import 'package:material_ui/material_ui.dart';

/// Manual low-light rescue: strength / preserve-detail / colour-noise sliders
/// over the model-free CPU path, applied as one undo step.
Future<void> showLowLightSheet(BuildContext context, FutureOr<void> Function(low_light.LowLightParams) onApply) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      var params = const low_light.LowLightParams();
      final l = sheetContext.l10n;
      return StatefulBuilder(
        builder: (context, setState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.aiLowLight, style: Theme.of(context).textTheme.titleMedium),
                LabeledSlider(
                  label: l.aiLowLightStrength,
                  value: params.strength,
                  min: 0,
                  max: 1,
                  neutral: 0,
                  onChanged: (v) => setState(
                    () => params = low_light.LowLightParams(
                      strength: v,
                      preserveDetail: params.preserveDetail,
                      colourNoise: params.colourNoise,
                    ),
                  ),
                ),
                LabeledSlider(
                  label: l.aiLowLightDetail,
                  value: params.preserveDetail,
                  min: 0,
                  max: 1,
                  neutral: 0,
                  onChanged: (v) => setState(
                    () => params = low_light.LowLightParams(
                      strength: params.strength,
                      preserveDetail: v,
                      colourNoise: params.colourNoise,
                    ),
                  ),
                ),
                LabeledSlider(
                  label: l.aiLowLightColour,
                  value: params.colourNoise,
                  min: 0,
                  max: 1,
                  neutral: 0,
                  onChanged: (v) => setState(
                    () => params = low_light.LowLightParams(
                      strength: params.strength,
                      preserveDetail: params.preserveDetail,
                      colourNoise: v,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.of(sheetContext).pop(), child: Text(l.cancel)),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        unawaited(Future.sync(() => onApply(params)));
                      },
                      child: Text(l.apply),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
