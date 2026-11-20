import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumora/core/utils/haptics.dart';
import 'package:lumora/core/utils/l10n_ext.dart';
import 'package:lumora/core/widgets/labeled_slider.dart';
import 'package:lumora/features/photo_editor/domain/edit_clipboard.dart';
import 'package:lumora/features/photo_editor/domain/finishing.dart';
import 'package:lumora/features/photo_editor/domain/histogram.dart';
import 'package:lumora/features/photo_editor/presentation/photo_editor_controller.dart';
import 'package:lumora/features/photo_editor/presentation/widgets/editor_canvas.dart';
import 'package:lumora/features/photo_editor/presentation/widgets/tool_panels.dart';
import 'package:lumora/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

const kSwatches = <int>[
  0xFFFFFFFF,
  0xFF000000,
  0xFFF5EFE6,
  0xFF1F1F24,
  0xFFFFB547,
  0xFFFF6B6B,
  0xFF8B7CFF,
  0xFF3FC5F0,
  0xFF43A047,
];

class _Swatches extends StatelessWidget {
  const _Swatches({required this.selected, required this.onSelect});
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        for (final c in kSwatches)
          Semantics(
            button: true,
            selected: c == selected,
            label: '#${c.toRadixString(16).substring(2).toUpperCase()}',
            child: GestureDetector(
              onTap: () => onSelect(c),
              child: Container(
                width: 30,
                height: 30,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: c == selected ? Theme.of(context).colorScheme.primary : Colors.white24,
                    width: c == selected ? 3 : 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

// -------------------------------------------------------------------- frame

class FramePanel extends ConsumerWidget {
  const FramePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frame = ref.watch(photoEditorControllerProvider.select((s) => s.edit.frame));
    final ctrl = ref.read(photoEditorControllerProvider.notifier);
    final l = context.l10n;
    void set(FrameSettings f, {bool live = false}) => ctrl.update((s) => s.copyWith(frame: f), live: live);

    final styles = <(FrameStyle, double?, IconData, String)>[
      (FrameStyle.none, null, Icons.block, l.none),
      (FrameStyle.border, null, Icons.crop_din, l.frameBorder),
      (FrameStyle.polaroid, null, Icons.photo_size_select_actual_outlined, l.framePolaroid),
      (FrameStyle.fitAspect, 1, Icons.crop_square, '1:1'),
      (FrameStyle.fitAspect, 4 / 5, Icons.crop_portrait, '4:5'),
      (FrameStyle.fitAspect, 9 / 16, Icons.stay_current_portrait, '9:16'),
      (FrameStyle.fitAspect, 16 / 9, Icons.crop_16_9, '16:9'),
    ];
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final (style, aspect, icon, label) in styles)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: ChoiceChip(
                      avatar: Icon(icon, size: 16),
                      label: Text(label),
                      selected: frame.style == style && (aspect == null || (frame.aspect - aspect).abs() < 1e-3),
                      onSelected: (_) {
                        Haptics.selection();
                        set(
                          frame.copyWith(
                            style: style,
                            aspect: aspect ?? frame.aspect,
                            width: style == FrameStyle.fitAspect ? 0 : (frame.width == 0 ? 0.04 : frame.width),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (!frame.isNone) ...[
            Row(
              children: [
                const SizedBox(width: 16),
                SegmentedButton<FrameFill>(
                  segments: [
                    ButtonSegment(value: FrameFill.color, label: Text(l.frameColor)),
                    ButtonSegment(value: FrameFill.blur, label: Text(l.frameBlur)),
                  ],
                  selected: {frame.fill},
                  onSelectionChanged: (v) => set(frame.copyWith(fill: v.first)),
                ),
              ],
            ),
            if (frame.fill == FrameFill.color)
              _Swatches(
                selected: frame.color,
                onSelect: (c) => set(frame.copyWith(color: c)),
              ),
            LabeledSlider(
              label: l.frameWidth,
              value: frame.width,
              min: 0,
              max: 0.2,
              displayScale: 500,
              onChanged: (v) => set(frame.copyWith(width: v), live: true),
              onChangeEnd: (_) => ctrl.commit(),
            ),
          ],
          LabeledSlider(
            label: l.cornerRadius,
            value: frame.cornerRadius,
            min: 0,
            max: 0.25,
            displayScale: 400,
            onChanged: (v) => set(frame.copyWith(cornerRadius: v), live: true),
            onChangeEnd: (_) => ctrl.commit(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- watermark

class WatermarkPanel extends ConsumerWidget {
  const WatermarkPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wm = ref.watch(photoEditorControllerProvider.select((s) => s.edit.watermark)) ?? const WatermarkSettings();
    final ctrl = ref.read(photoEditorControllerProvider.notifier);
    final l = context.l10n;
    void set(WatermarkSettings w, {bool live = false}) =>
        ctrl.update((s) => s.copyWith(watermark: w.isEmpty ? null : w), live: live);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.text_fields),
                    label: Text(wm.text.isEmpty ? l.watermarkText : wm.text, overflow: TextOverflow.ellipsis),
                    onPressed: () async {
                      final t = await promptText(context, title: l.watermarkText, initial: wm.text);
                      if (t != null) set(wm.copyWith(text: t));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.image_outlined),
                  label: Text(wm.logoPath == null ? l.watermarkLogo : l.remove),
                  onPressed: () async {
                    if (wm.logoPath != null) {
                      set(wm.copyWith(logoPath: null));
                      return;
                    }
                    final path = (await FilePicker.pickFile(type: FileType.image))?.path;
                    if (path != null) set(wm.copyWith(logoPath: path));
                  },
                ),
              ],
            ),
          ),
          _AnchorPicker(
            selected: wm.anchor,
            onSelect: (a) => set(wm.copyWith(anchor: a)),
          ),
          _Swatches(
            selected: wm.color,
            onSelect: (c) => set(wm.copyWith(color: c)),
          ),
          LabeledSlider(
            label: l.size,
            value: wm.size,
            min: 0.015,
            max: 0.15,
            neutral: 0.015,
            displayScale: 700,
            onChanged: (v) => set(wm.copyWith(size: v), live: true),
            onChangeEnd: (_) => ctrl.commit(),
          ),
          LabeledSlider(
            label: l.opacity,
            value: wm.opacity,
            min: 0.1,
            max: 1,
            neutral: 0.1,
            onChanged: (v) => set(wm.copyWith(opacity: v), live: true),
            onChangeEnd: (_) => ctrl.commit(),
          ),
          LabeledSlider(
            label: l.margin,
            value: wm.margin,
            min: 0,
            max: 0.15,
            displayScale: 700,
            onChanged: (v) => set(wm.copyWith(margin: v), live: true),
            onChangeEnd: (_) => ctrl.commit(),
          ),
        ],
      ),
    );
  }
}

class _AnchorPicker extends StatelessWidget {
  const _AnchorPicker({required this.selected, required this.onSelect});
  final WatermarkAnchor selected;
  final ValueChanged<WatermarkAnchor> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Directionality(
        // Positions are physical (top-left is top-left in every language).
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 108,
          height: 72,
          child: GridView.count(
            crossAxisCount: 3,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.5,
            children: [
              for (final a in WatermarkAnchor.values)
                Semantics(
                  button: true,
                  selected: a == selected,
                  label: a.name,
                  child: InkWell(
                    onTap: () => onSelect(a),
                    child: Center(
                      child: Container(
                        width: a == selected ? 14 : 8,
                        height: a == selected ? 14 : 8,
                        decoration: BoxDecoration(
                          color: a == selected ? scheme.primary : scheme.outline,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------- heal

class HealPanel extends ConsumerWidget {
  const HealPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(photoEditorControllerProvider);
    final ctrl = ref.read(photoEditorControllerProvider.notifier);
    final l = context.l10n;
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 4),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, icon: const Icon(Icons.healing), label: Text(l.healMode)),
              ButtonSegment(value: true, icon: const Icon(Icons.copy_all), label: Text(l.cloneMode)),
            ],
            selected: {s.healClone},
            onSelectionChanged: (v) => ctrl.setHealClone(value: v.first),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              s.healClone ? (s.healSettingSource ? l.cloneSetSourceHint : l.clonePaintHint) : l.healHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const DrawPanel(showColors: false),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (s.healClone)
                TextButton.icon(
                  onPressed: ctrl.startSettingHealSource,
                  icon: const Icon(Icons.my_location),
                  label: Text(l.setSource),
                ),
              TextButton(onPressed: clearPendingEraserStrokes, child: Text(l.clear)),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: s.busy || (s.healClone && s.healSource == null)
                    ? null
                    : () {
                        Haptics.medium();
                        ctrl.heal(takePendingEraserStrokes());
                      },
                icon: const Icon(Icons.auto_fix_normal),
                label: Text(l.apply),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- histogram

class HistogramView extends StatelessWidget {
  const HistogramView({required this.histogram, super.key});
  final Histogram histogram;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Semantics(
      label: l.histogram,
      child: Container(
        width: 168,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: const Color(0xB3000000), borderRadius: BorderRadius.circular(10)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 64,
              child: CustomPaint(size: Size.infinite, painter: _HistogramPainter(histogram)),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _ClipDot(active: histogram.clipsShadows, color: const Color(0xFF3F7BFF), tooltip: l.shadowClipping),
                const Spacer(),
                Text(
                  '${(histogram.meanLuma / 2.55).round()}%',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
                const Spacer(),
                _ClipDot(
                  active: histogram.clipsHighlights,
                  color: const Color(0xFFFF3B5C),
                  tooltip: l.highlightClipping,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ClipDot extends StatelessWidget {
  const _ClipDot({required this.active, required this.color, required this.tooltip});
  final bool active;
  final Color color;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? color : Colors.transparent,
        border: Border.all(color: color),
      ),
    ),
  );
}

class _HistogramPainter extends CustomPainter {
  _HistogramPainter(this.h);
  final Histogram h;

  @override
  void paint(Canvas canvas, Size size) {
    final peak = h.peak.toDouble();
    void channel(List<int> bins, Color color) {
      final path = Path()..moveTo(0, size.height);
      for (var i = 0; i < 256; i++) {
        final v = (bins[i] / peak).clamp(0.0, 1.0);
        path.lineTo(i / 255 * size.width, size.height - v * size.height);
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..blendMode = BlendMode.plus,
      );
    }

    channel(h.red, const Color(0x99FF4040));
    channel(h.green, const Color(0x9940FF40));
    channel(h.blue, const Color(0x994080FF));
    channel(h.luma, const Color(0x40FFFFFF));
  }

  @override
  bool shouldRepaint(_HistogramPainter old) => !identical(old.h, h);
}

// ------------------------------------------------------------------ history

String editChangeLabel(AppLocalizations l, EditChange c) => switch (c) {
  EditChange.initial => l.histOriginal,
  EditChange.preset => l.toolPresets,
  EditChange.light => l.groupLight,
  EditChange.color => l.groupColor,
  EditChange.hsl => l.toolHsl,
  EditChange.curves => l.toolCurves,
  EditChange.lut => l.toolLut,
  EditChange.detail => l.groupDetail,
  EditChange.effects => l.groupEffects,
  EditChange.crop => l.toolCrop,
  EditChange.layers => l.histLayers,
  EditChange.masks => l.toolMasks,
  EditChange.ai => l.histPixels,
  EditChange.frame => l.toolFrame,
  EditChange.watermark => l.toolWatermark,
  EditChange.other => l.histOther,
};

IconData editChangeIcon(EditChange c) => switch (c) {
  EditChange.initial => Icons.image_outlined,
  EditChange.preset => Icons.auto_awesome,
  EditChange.light => Icons.wb_sunny_outlined,
  EditChange.color => Icons.palette_outlined,
  EditChange.hsl => Icons.color_lens_outlined,
  EditChange.curves => Icons.show_chart,
  EditChange.lut => Icons.filter_vintage_outlined,
  EditChange.detail => Icons.details,
  EditChange.effects => Icons.blur_on,
  EditChange.crop => Icons.crop_rotate,
  EditChange.layers => Icons.layers_outlined,
  EditChange.masks => Icons.blur_circular,
  EditChange.ai => Icons.auto_fix_high,
  EditChange.frame => Icons.crop_din,
  EditChange.watermark => Icons.branding_watermark_outlined,
  EditChange.other => Icons.edit_outlined,
};

/// Bottom sheet listing every edit step; tapping one jumps there.
Future<void> showHistorySheet(BuildContext context, WidgetRef ref) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (c) => Consumer(
    builder: (c, ref, _) {
      final history = ref.watch(photoEditorControllerProvider.select((s) => s.history));
      final ctrl = ref.read(photoEditorControllerProvider.notifier);
      final l = c.l10n;
      final steps = history.timeline;
      final current = history.currentIndex;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * 0.6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(l.history, style: Theme.of(c).textTheme.titleMedium),
                  const Spacer(),
                  Text('${current + 1} / ${steps.length}', style: Theme.of(c).textTheme.labelMedium),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: steps.length,
                itemBuilder: (c, i) {
                  final change = describeChange(i == 0 ? null : steps[i - 1], steps[i]);
                  final future = i > current;
                  return ListTile(
                    dense: true,
                    selected: i == current,
                    leading: Icon(editChangeIcon(change), color: future ? Theme.of(c).disabledColor : null),
                    title: Text(
                      i == 0 ? l.histOriginal : '$i · ${editChangeLabel(l, change)}',
                      style: future ? TextStyle(color: Theme.of(c).disabledColor) : null,
                    ),
                    trailing: i == current ? const Icon(Icons.check) : null,
                    onTap: () {
                      Haptics.selection();
                      ctrl.jumpToHistory(i);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  ),
);
