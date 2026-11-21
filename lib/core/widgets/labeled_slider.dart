import 'package:lumora/core/ui/lumora_tokens.dart';
import 'package:lumora/core/ui/slider_shapes.dart';
import 'package:material_ui/material_ui.dart';

/// Compact slider row used across the editors. Shows a centred track for
/// bipolar ranges, the value as a signed number, and resets on double tap.
class LabeledSlider extends StatelessWidget {
  const LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    super.key,
    this.onChangeEnd,
    this.neutral = 0,
    this.displayScale = 100,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final double neutral;
  final double displayScale;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = ((value - neutral) * displayScale).round();
    final changed = (value - neutral).abs() > 1e-4;
    return GestureDetector(
      onDoubleTap: () {
        onChanged(neutral);
        onChangeEnd?.call(neutral);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            SizedBox(
              width: 104,
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: changed ? theme.colorScheme.primary : null,
                  fontWeight: changed ? FontWeight.w600 : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  // Bipolar ranges fill from the neutral value to the thumb.
                  trackShape: GlowSliderTrackShape(
                    colors: context.lumora.primaryGradient,
                    inactive: context.lumora.trackInactive,
                    origin: min < neutral && max > min ? (neutral - min) / (max - min) : null,
                  ),
                ),
                child: Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  onChanged: onChanged,
                  onChangeEnd: onChangeEnd,
                ),
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(
                shown > 0 && min < neutral ? '+$shown' : '$shown',
                textAlign: TextAlign.end,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: changed ? theme.colorScheme.onSurface : context.lumora.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
