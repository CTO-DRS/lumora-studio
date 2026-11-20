import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumora/core/providers.dart';
import 'package:lumora/core/utils/l10n_ext.dart';
import 'package:lumora/core/widgets/labeled_slider.dart';
import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/photo_editor/domain/geometry.dart';
import 'package:lumora/features/photo_editor/domain/layers.dart';
import 'package:lumora/features/photo_editor/domain/presets.dart';
import 'package:lumora/features/photo_editor/engine/lut/lut_repository.dart';
import 'package:lumora/features/photo_editor/presentation/photo_editor_controller.dart';
import 'package:lumora/features/photo_editor/presentation/widgets/curves_editor.dart';
import 'package:lumora/features/photo_editor/presentation/widgets/editor_canvas.dart';
import 'package:lumora/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

String paramLabel(AppLocalizations l, AdjustmentParam p) => switch (p) {
  AdjustmentParam.exposure => l.exposure,
  AdjustmentParam.contrast => l.contrast,
  AdjustmentParam.highlights => l.highlights,
  AdjustmentParam.shadows => l.shadows,
  AdjustmentParam.whites => l.whites,
  AdjustmentParam.blacks => l.blacks,
  AdjustmentParam.temperature => l.temperature,
  AdjustmentParam.tint => l.tint,
  AdjustmentParam.vibrance => l.vibrance,
  AdjustmentParam.saturation => l.saturation,
  AdjustmentParam.fade => l.fade,
  AdjustmentParam.sharpen => l.sharpen,
  AdjustmentParam.clarity => l.clarity,
  AdjustmentParam.structure => l.structure,
  AdjustmentParam.dehaze => l.dehaze,
  AdjustmentParam.blur => l.blur,
  AdjustmentParam.vignette => l.vignette,
  AdjustmentParam.vignetteMidpoint => l.vignetteMidpoint,
  AdjustmentParam.vignetteFeather => l.vignetteFeather,
  AdjustmentParam.grain => l.grain,
  AdjustmentParam.grainSize => l.grainSize,
  AdjustmentParam.chromaticAberration => l.chromaticAberration,
  AdjustmentParam.glitch => l.glitch,
  AdjustmentParam.lutIntensity => l.lutIntensity,
};

/// Slider list bound to a set of [AdjustmentParam]s of either the global
/// adjustments or a local mask.
class ParamSliders extends ConsumerWidget {
  const ParamSliders({required this.params, super.key, this.maskId});

  final List<AdjustmentParam> params;
  final String? maskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(photoEditorControllerProvider.notifier);
    final s = ref.watch(photoEditorControllerProvider);
    final adjustments = maskId == null
        ? s.edit.adjustments
        : s.edit.localAdjustments.firstWhere((m) => m.id == maskId).adjustments;
    void set(AdjustmentParam p, double v, {required bool live}) {
      if (maskId == null) {
        ctrl.updateAdjustments((a) => p.write(a, v), live: live);
      } else {
        ctrl.updateMask(maskId!, (m) => m.copyWith(adjustments: p.write(m.adjustments, v)), live: live);
      }
    }

    return Column(
      children: [
        for (final p in params)
          LabeledSlider(
            label: paramLabel(context.l10n, p),
            value: p.read(adjustments),
            min: p.min,
            max: p.max,
            neutral: p.neutral,
            displayScale: p == AdjustmentParam.exposure ? 20 : 100,
            onChanged: (v) => set(p, v, live: true),
            onChangeEnd: (_) => ctrl.commit(),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------ presets

class PresetsPanel extends ConsumerWidget {
  const PresetsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(photoEditorControllerProvider);
    final ctrl = ref.read(photoEditorControllerProvider.notifier);
    final lang = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (s.edit.presetId != null)
          LabeledSlider(
            label: context.l10n.intensity,
            value: s.edit.presetIntensity,
            min: 0,
            max: 1,
            onChanged: (v) => ctrl.applyPreset(s.edit.presetId, intensity: v),
          ),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: kBuiltInPresets.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final preset = i == 0 ? null : kBuiltInPresets[i - 1];
              final selected = s.edit.presetId == preset?.id;
              return GestureDetector(
                onTap: () => ctrl.applyPreset(preset?.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 76,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: selected ? theme.colorScheme.primary : Colors.transparent, width: 2),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _swatch(preset),
                    ),
                  ),
                  alignment: Alignment.bottomCenter,
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    preset?.name(lang) ?? context.l10n.none,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      shadows: const [Shadow(blurRadius: 4)],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// A cheap visual signature of the look (avoids rendering 30 thumbnails).
  static List<Color> _swatch(Preset? p) {
    if (p == null) return const [Color(0xFF2A2A33), Color(0xFF3A3A45)];
    final a = p.adjustments;
    if (a.duotone.strength > 0) return [Color(a.duotone.shadowColor), Color(a.duotone.highlightColor)];
    if (a.saturation <= -0.9) return const [Color(0xFF111111), Color(0xFFBBBBBB)];
    final warm = a.temperature;
    final base = HSLColor.fromAHSL(
      1,
      warm >= 0 ? 32 : 205,
      (0.4 + a.vibrance).clamp(0.1, 0.9),
      0.35 + a.exposure * 0.1,
    );
    final tint = HSLColor.fromAHSL(
      1,
      (a.splitTone.shadowHue * 360) % 360,
      (0.3 + a.splitTone.shadowSaturation).clamp(0, 1),
      0.25,
    );
    return [tint.toColor(), base.toColor()];
  }
}

// ------------------------------------------------------------------- adjust

class AdjustPanel extends StatelessWidget {
  const AdjustPanel({super.key});

  static const groups = <(String Function(AppLocalizations), List<AdjustmentParam>)>[
    (
      _light,
      [
        AdjustmentParam.exposure,
        AdjustmentParam.contrast,
        AdjustmentParam.highlights,
        AdjustmentParam.shadows,
        AdjustmentParam.whites,
        AdjustmentParam.blacks,
      ],
    ),
    (
      _color,
      [
        AdjustmentParam.temperature,
        AdjustmentParam.tint,
        AdjustmentParam.vibrance,
        AdjustmentParam.saturation,
        AdjustmentParam.fade,
      ],
    ),
    (
      _detail,
      [
        AdjustmentParam.sharpen,
        AdjustmentParam.clarity,
        AdjustmentParam.structure,
        AdjustmentParam.dehaze,
        AdjustmentParam.blur,
      ],
    ),
    (
      _effects,
      [
        AdjustmentParam.vignette,
        AdjustmentParam.vignetteMidpoint,
        AdjustmentParam.vignetteFeather,
        AdjustmentParam.grain,
        AdjustmentParam.grainSize,
        AdjustmentParam.chromaticAberration,
        AdjustmentParam.glitch,
      ],
    ),
  ];

  static String _light(AppLocalizations l) => l.groupLight;
  static String _color(AppLocalizations l) => l.groupColor;
  static String _detail(AppLocalizations l) => l.groupDetail;
  static String _effects(AppLocalizations l) => l.groupEffects;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: groups.length + 1,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final g in groups) Tab(text: g.$1(context.l10n), height: 36),
              Tab(text: '${context.l10n.duotone} · ${context.l10n.splitToning}', height: 36),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final g in groups) SingleChildScrollView(child: ParamSliders(params: g.$2)),
                const SingleChildScrollView(child: _ToningPanel()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToningPanel extends ConsumerWidget {
  const _ToningPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(photoEditorControllerProvider.select((s) => s.edit.adjustments));
    final ctrl = ref.read(photoEditorControllerProvider.notifier);
    final l = context.l10n;
    final st = a.splitTone;
    return Column(
      children: [
        LabeledSlider(
          label: l.shadowsHue,
          value: st.shadowHue,
          min: 0,
          max: 1,
          displayScale: 360,
          onChanged: (v) =>
              ctrl.updateAdjustments((x) => x.copyWith(splitTone: x.splitTone.copyWith(shadowHue: v)), live: true),
          onChangeEnd: (_) => ctrl.commit(),
        ),
        LabeledSlider(
          label: l.saturation,
          value: st.shadowSaturation,
          min: 0,
          max: 1,
          onChanged: (v) => ctrl.updateAdjustments(
            (x) => x.copyWith(splitTone: x.splitTone.copyWith(shadowSaturation: v)),
            live: true,
          ),
          onChangeEnd: (_) => ctrl.commit(),
        ),
        LabeledSlider(
          label: l.highlightsHue,
          value: st.highlightHue,
          min: 0,
          max: 1,
          displayScale: 360,
          onChanged: (v) =>
              ctrl.updateAdjustments((x) => x.copyWith(splitTone: x.splitTone.copyWith(highlightHue: v)), live: true),
          onChangeEnd: (_) => ctrl.commit(),
        ),
        LabeledSlider(
          label: l.saturation,
          value: st.highlightSaturation,
          min: 0,
          max: 1,
          onChanged: (v) => ctrl.updateAdjustments(
            (x) => x.copyWith(splitTone: x.splitTone.copyWith(highlightSaturation: v)),
            live: true,
          ),
          onChangeEnd: (_) => ctrl.commit(),
        ),
        LabeledSlider(
          label: l.duotone,
          value: a.duotone.strength,
          min: 0,
          max: 1,
          onChanged: (v) =>
              ctrl.updateAdjustments((x) => x.copyWith(duotone: x.duotone.copyWith(strength: v)), live: true),
          onChangeEnd: (_) => ctrl.commit(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Wrap(
            spacing: 8,
            children: [
              for (final pair in const [
                (0xFF1B1035, 0xFFFFC46B),
                (0xFF06283D, 0xFF47B5FF),
                (0xFF3A0CA3, 0xFFF72585),
                (0xFF0B3D20, 0xFFC7F464),
                (0xFF2B1A0E, 0xFFF2DDB7),
              ])
                GestureDetector(
                  onTap: () => ctrl.updateAdjustments(
                    (x) => x.copyWith(
                      duotone: x.duotone.copyWith(
                        shadowColor: pair.$1,
                        highlightColor: pair.$2,
                        strength: x.duotone.strength == 0 ? 1 : x.duotone.strength,
                      ),
                    ),
                  ),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [Color(pair.$1), Color(pair.$2)]),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------- HSL

class HslPanel extends ConsumerStatefulWidget {
  const HslPanel({super.key});

  @override
  ConsumerState<HslPanel> createState() => _HslPanelState();
}

class _HslPanelState extends ConsumerState<HslPanel> {
  int _band = 0;

  static const bandColors = [
    Color(0xFFE53935),
    Color(0xFFFB8C00),
    Color(0xFFFDD835),
    Color(0xFF43A047),
    Color(0xFF00ACC1),
    Color(0xFF1E88E5),
    Color(0xFF8E24AA),
    Color(0xFFD81B60),
  ];

  @override
  Widget build(BuildContext context) {
    final hsl = ref.watch(photoEditorControllerProvider.select((s) => s.edit.adjustments.hsl));
    final ctrl = ref.read(photoEditorControllerProvider.notifier);
    final l = context.l10n;
    final names = [
      l.bandRed,
      l.bandOrange,
      l.bandYellow,
      l.bandGreen,
      l.bandAqua,
      l.bandBlue,
      l.bandPurple,
      l.bandMagenta,
    ];

    void set(int kind, double v) {
      ctrl.updateAdjustments((a) {
        List<double> upd(List<double> list) => [...list]..[_band] = v;
        return a.copyWith(
          hsl: switch (kind) {
            0 => a.hsl.copyWith(hue: upd(a.hsl.hue)),
            1 => a.hsl.copyWith(saturation: upd(a.hsl.saturation)),
            _ => a.hsl.copyWith(luminance: upd(a.hsl.luminance)),
          },
        );
      }, live: true);
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 8; i++)
                  Tooltip(
                    message: names[i],
                    child: GestureDetector(
                      onTap: () => setState(() => _band = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        width: _band == i ? 32 : 24,
                        height: _band == i ? 32 : 24,
                        decoration: BoxDecoration(
                          color: bandColors[i],
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: _band == i ? 2 : 0),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (final (kind, label, values) in [
            (0, l.hue, hsl.hue),
            (1, l.saturation, hsl.saturation),
            (2, l.luminance, hsl.luminance),
          ])
            LabeledSlider(
              label: '${names[_band]} · $label',
              value: values[_band],
              min: -1,
              max: 1,
              onChanged: (v) => set(kind, v),
              onChangeEnd: (_) => ctrl.commit(),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------- curves

class CurvesPanel extends ConsumerStatefulWidget {
  const CurvesPanel({super.key});

  @override
  ConsumerState<CurvesPanel> createState() => _CurvesPanelState();
}

class _CurvesPanelState extends ConsumerState<CurvesPanel> {
  int _channel = 0;

  @override
  Widget build(BuildContext context) {
    final curves = ref.watch(photoEditorControllerProvider.select((s) => s.edit.adjustments.curves));
    final ctrl = ref.read(photoEditorControllerProvider.notifier);
    final l = context.l10n;
    final pts = [curves.master, curves.red, curves.green, curves.blue][_channel];
    const colors = [Colors.white, Color(0xFFFF5252), Color(0xFF69F0AE), Color(0xFF448AFF)];
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 0, label: Text(l.curveMaster)),
              ButtonSegment(value: 1, label: Text(l.curveRed)),
              ButtonSegment(value: 2, label: Text(l.curveGreen)),
              ButtonSegment(value: 3, label: Text(l.curveBlue)),
            ],
            selected: {_channel},
            onSelectionChanged: (v) => setState(() => _channel = v.first),
          ),
          const SizedBox(height: 8),
          CurvesEditor(
            points: pts,
            color: colors[_channel],
            onChanged: (p) => ctrl.updateAdjustments(
              (a) => a.copyWith(
                curves: switch (_channel) {
                  0 => a.curves.copyWith(master: p),
                  1 => a.curves.copyWith(red: p),
                  2 => a.curves.copyWith(green: p),
                  _ => a.curves.copyWith(blue: p),
                },
              ),
              live: true,
            ),
            onChangeEnd: ctrl.commit,
          ),
          TextButton.icon(
            onPressed: () => ctrl.updateAdjustments((a) => a.copyWith(curves: const CurveSet())),
            icon: const Icon(Icons.restart_alt),
            label: Text(l.reset),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------- LUTs

final FutureProvider<List<LutInfo>> _lutListProvider = FutureProvider.autoDispose<List<LutInfo>>(
  (ref) => ref.watch(lutRepositoryProvider).list(),
);

class LutPanel extends ConsumerWidget {
  const LutPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(photoEditorControllerProvider.select((s) => s.edit.adjustments));
    final ctrl = ref.read(photoEditorControllerProvider.notifier);
    final luts = ref.watch(_lutListProvider);
    final l = context.l10n;
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: Text(l.none),
                  selected: a.lutId == null,
                  onSelected: (_) => ctrl.updateAdjustments((x) => x.copyWith(lutId: null)),
                ),
                for (final lut in luts.value ?? const <LutInfo>[])
                  ChoiceChip(
                    avatar: Icon(lut.builtIn ? Icons.auto_awesome : Icons.file_present, size: 16),
                    label: Text(lut.name),
                    selected: a.lutId == lut.id,
                    onSelected: (_) => ctrl.updateAdjustments((x) => x.copyWith(lutId: lut.id, lutIntensity: 1)),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: Text(l.importLut),
                  onPressed: () async {
                    final path = (await FilePicker.pickFile())?.path;
                    if (path == null) return;
                    try {
                      final id = await ref.read(lutRepositoryProvider).import(path);
                      ref.invalidate(_lutListProvider);
                      ctrl.updateAdjustments((x) => x.copyWith(lutId: id, lutIntensity: 1));
                    } on Object {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.invalidLut)));
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          if (a.lutId != null) const ParamSliders(params: [AdjustmentParam.lutIntensity]),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------- crop

class CropPanel extends ConsumerWidget {
  const CropPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(photoEditorControllerProvider.select((s) => s.edit.geometry));
    final ctrl = ref.read(photoEditorControllerProvider.notifier);
    final l = context.l10n;
    final aspects = <(String, double?)>[
      (l.aspectFree, null),
      ('1:1', 1),
      ('4:5', 4 / 5),
      ('3:2', 3 / 2),
      ('16:9', 16 / 9),
      ('9:16', 9 / 16),
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
                IconButton(
                  tooltip: l.rotate,
                  icon: const Icon(Icons.rotate_90_degrees_cw_outlined),
                  onPressed: () => ctrl.update(
                    (s) => s.copyWith(
                      geometry: s.geometry.copyWith(quarterTurns: (s.geometry.quarterTurns + 1) % 4).withoutCrop(),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l.flipH,
                  icon: const Icon(Icons.flip),
                  onPressed: () => ctrl.update(
                    (s) => s.copyWith(geometry: s.geometry.copyWith(flipHorizontal: !s.geometry.flipHorizontal)),
                  ),
                ),
                for (final (label, ratio) in aspects)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: g.aspectRatio == ratio,
                      onSelected: (_) => ctrl.update((s) => s.copyWith(geometry: _applyAspect(s.geometry, ratio, ref))),
                    ),
                  ),
                IconButton(
                  tooltip: l.reset,
                  icon: const Icon(Icons.restart_alt),
                  onPressed: () => ctrl.update((s) => s.copyWith(geometry: const GeometryState())),
                ),
              ],
            ),
          ),
          LabeledSlider(
            label: l.straighten,
            value: g.straightenDegrees,
            min: -45,
            max: 45,
            displayScale: 1,
            onChanged: (v) =>
                ctrl.update((s) => s.copyWith(geometry: s.geometry.copyWith(straightenDegrees: v)), live: true),
            onChangeEnd: (_) => ctrl.commit(),
          ),
          LabeledSlider(
            label: l.perspectiveV,
            value: g.perspectiveVertical,
            min: -1,
            max: 1,
            onChanged: (v) =>
                ctrl.update((s) => s.copyWith(geometry: s.geometry.copyWith(perspectiveVertical: v)), live: true),
            onChangeEnd: (_) => ctrl.commit(),
          ),
          LabeledSlider(
            label: l.perspectiveH,
            value: g.perspectiveHorizontal,
            min: -1,
            max: 1,
            onChanged: (v) =>
                ctrl.update((s) => s.copyWith(geometry: s.geometry.copyWith(perspectiveHorizontal: v)), live: true),
            onChangeEnd: (_) => ctrl.commit(),
          ),
        ],
      ),
    );
  }

  static GeometryState _applyAspect(GeometryState g, double? ratio, WidgetRef ref) {
    final s = ref.read(photoEditorControllerProvider);
    final img = s.preview;
    if (ratio == null || img == null) return g.copyWith(aspectRatio: ratio);
    final (fw, fh) = g.rotatedSize(img.width.toDouble(), img.height.toDouble());
    // Largest centred rect with the requested pixel aspect.
    var w = fw;
    var h = fw / ratio;
    if (h > fh) {
      h = fh;
      w = fh * ratio;
    }
    final l = (1 - w / fw) / 2;
    final t = (1 - h / fh) / 2;
    return g.copyWith(aspectRatio: ratio, cropLeft: l, cropTop: t, cropRight: 1 - l, cropBottom: 1 - t);
  }
}

// --------------------------------------------------------------------- text

class TextPanel extends ConsumerWidget {
  const TextPanel({super.key});

  static const palette = [
    0xFFFFFFFF,
    0xFF000000,
    0xFFFFB547,
    0xFFFF5C8A,
    0xFF8B7CFF,
    0xFF4FC3F7,
    0xFF69F0AE,
    0xFFFFEB3B,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(photoEditorControllerProvider);
    final ctrl = ref.read(photoEditorControllerProvider.notifier);
    final l = context.l10n;
    final layer = s.edit.layers.whereType<TextLayer>().where((t) => t.id == s.selectedLayerId).firstOrNull;
    return SingleChildScrollView(
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () async {
                  final text = await promptText(context, title: l.addText);
                  if (text != null && text.trim().isNotEmpty) ctrl.addText(text);
                },
                icon: const Icon(Icons.title),
                label: Text(l.addText),
              ),
              if (layer != null) ...[
                IconButton.filledTonal(
                  tooltip: l.editText,
                  icon: const Icon(Icons.edit),
                  onPressed: () async {
                    final text = await promptText(context, title: l.editText, initial: layer.text);
                    if (text != null) ctrl.updateLayer(layer.id, (x) => (x as TextLayer).copyWith(text: text));
                  },
                ),
                IconButton.filledTonal(
                  tooltip: l.bold,
                  isSelected: layer.bold,
                  icon: const Icon(Icons.format_bold),
                  onPressed: () => ctrl.updateLayer(layer.id, (x) => (x as TextLayer).copyWith(bold: !layer.bold)),
                ),
                IconButton.filledTonal(
                  tooltip: l.background,
                  isSelected: layer.backgroundColor != null,
                  icon: const Icon(Icons.format_color_fill),
                  onPressed: () => ctrl.updateLayer(
                    layer.id,
                    (x) =>
                        (x as TextLayer).copyWith(backgroundColor: layer.backgroundColor == null ? 0xAA000000 : null),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: l.removeLayer,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => ctrl.removeLayer(layer.id),
                ),
              ],
            ],
          ),
          if (layer != null) ...[
            const SizedBox(height: 8),
            _ColorRow(
              colors: palette,
              selected: layer.color,
              onPick: (c) => ctrl.updateLayer(layer.id, (x) => (x as TextLayer).copyWith(color: c)),
            ),
            LabeledSlider(
              label: l.size,
              value: layer.fontSize,
              min: 0.02,
              max: 0.25,
              neutral: 0.02,
              onChanged: (v) => ctrl.updateLayer(layer.id, (x) => (x as TextLayer).copyWith(fontSize: v), live: true),
              onChangeEnd: (_) => ctrl.commit(),
            ),
            LabeledSlider(
              label: l.opacity,
              value: layer.opacity,
              min: 0,
              max: 1,
              onChanged: (v) => ctrl.updateLayer(layer.id, (x) => (x as TextLayer).copyWith(opacity: v), live: true),
              onChangeEnd: (_) => ctrl.commit(),
            ),
          ],
        ],
      ),
    );
  }
}

Future<String?> promptText(BuildContext context, {required String title, String initial = ''}) {
  final controller = TextEditingController(text: initial);
  final l = context.l10n;
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 4,
        minLines: 1,
        decoration: InputDecoration(hintText: l.textHint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.pop(c, controller.text), child: Text(l.done)),
      ],
    ),
  );
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({required this.colors, required this.selected, required this.onPick});
  final List<int> colors;
  final int selected;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final c in colors)
            GestureDetector(
              onTap: () => onPick(c),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 30,
                height: 30,
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
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- stickers

class StickersPanel extends ConsumerWidget {
  const StickersPanel({super.key});

  static const glyphs = [
    '✨',
    '❤️',
    '🔥',
    '⭐',
    '🌙',
    '☀️',
    '🌸',
    '🎉',
    '😍',
    '😎',
    '👑',
    '💫',
    '🕌',
    '🌴',
    '🐪',
    '☕',
    '📍',
    '🎵',
    '💎',
    '🦋',
    '🌈',
    '⚡',
    '🍀',
    '🎂',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(photoEditorControllerProvider);
    final ctrl = ref.read(photoEditorControllerProvider.notifier);
    final l = context.l10n;
    final selected = s.edit.layers.whereType<StickerLayer>().where((t) => t.id == s.selectedLayerId).firstOrNull;
    return SingleChildScrollView(
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              for (final g in glyphs)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => ctrl.addSticker(glyph: g),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(g, style: const TextStyle(fontSize: 28)),
                  ),
                ),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final path = (await FilePicker.pickFile(type: FileType.image))?.path;
                  if (path != null) ctrl.addSticker(imagePath: path);
                },
                child: const Padding(padding: EdgeInsets.all(10), child: Icon(Icons.add_photo_alternate_outlined)),
              ),
            ],
          ),
          if (selected != null) ...[
            LabeledSlider(
              label: l.opacity,
              value: selected.opacity,
              min: 0,
              max: 1,
              onChanged: (v) =>
                  ctrl.updateLayer(selected.id, (x) => (x as StickerLayer).copyWith(opacity: v), live: true),
              onChangeEnd: (_) => ctrl.commit(),
            ),
            TextButton.icon(
              onPressed: () => ctrl.removeLayer(selected.id),
              icon: const Icon(Icons.delete_outline),
              label: Text(l.removeLayer),
            ),
          ],
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------- draw

class DrawPanel extends ConsumerWidget {
  const DrawPanel({super.key, this.showColors = true});

  final bool showColors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brush = ref.watch(brushControllerProvider);
    final b = ref.read(brushControllerProvider.notifier);
    final l = context.l10n;
    return SingleChildScrollView(
      child: Column(
        children: [
          if (showColors)
            _ColorRow(
              colors: TextPanel.palette,
              selected: brush.color,
              onPick: (c) => b.set((x) => x.copyWith(color: c, eraser: false)),
            ),
          LabeledSlider(
            label: l.brushSize,
            value: brush.size,
            min: 0.005,
            max: 0.15,
            neutral: 0.005,
            onChanged: (v) => b.set((x) => x.copyWith(size: v)),
          ),
          LabeledSlider(
            label: l.softness,
            value: brush.softness,
            min: 0,
            max: 1,
            onChanged: (v) => b.set((x) => x.copyWith(softness: v)),
          ),
          SwitchListTile(
            dense: true,
            title: Text(l.eraser),
            value: brush.eraser,
            onChanged: (v) => b.set((x) => x.copyWith(eraser: v)),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------- masks

class MasksPanel extends ConsumerWidget {
  const MasksPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(photoEditorControllerProvider);
    final ctrl = ref.read(photoEditorControllerProvider.notifier);
    final l = context.l10n;
    final masks = s.edit.localAdjustments;
    final selected = masks.where((m) => m.id == s.selectedMaskId).firstOrNull;
    IconData icon(MaskKind k) => switch (k) {
      MaskKind.brush => Icons.brush,
      MaskKind.linear => Icons.gradient,
      MaskKind.radial => Icons.radio_button_unchecked,
      MaskKind.subject => Icons.person_outline,
    };
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final (k, label) in [
                  (MaskKind.brush, l.maskBrush),
                  (MaskKind.linear, l.maskLinear),
                  (MaskKind.radial, l.maskRadial),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      avatar: Icon(icon(k), size: 16),
                      label: Text('+ $label'),
                      onPressed: () => ctrl.addMask(k),
                    ),
                  ),
                ActionChip(
                  avatar: Icon(icon(MaskKind.subject), size: 16),
                  label: Text('+ ${l.maskSubject}'),
                  onPressed: ctrl.subjectAdjustment,
                ),
                const SizedBox(width: 12),
                for (final m in masks)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      avatar: Icon(icon(m.kind), size: 16),
                      label: Text('${masks.indexOf(m) + 1}'),
                      selected: m.id == s.selectedMaskId,
                      onSelected: (_) => ctrl.selectMask(m.id),
                    ),
                  ),
              ],
            ),
          ),
          if (selected != null) ...[
            Row(
              children: [
                const SizedBox(width: 12),
                FilterChip(
                  label: Text(l.invertMask),
                  selected: selected.invert,
                  onSelected: (v) => ctrl.updateMask(selected.id, (m) => m.copyWith(invert: v)),
                ),
                const Spacer(),
                IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => ctrl.removeMask(selected.id)),
              ],
            ),
            if (selected.kind == MaskKind.brush) const DrawPanel(showColors: false),
            if (selected.kind == MaskKind.radial || selected.kind == MaskKind.linear)
              LabeledSlider(
                label: l.feather,
                value: selected.feather,
                min: 0.01,
                max: 1,
                neutral: 0.01,
                onChanged: (v) => ctrl.updateMask(selected.id, (m) => m.copyWith(feather: v), live: true),
                onChangeEnd: (_) => ctrl.commit(),
              ),
            LabeledSlider(
              label: l.intensity,
              value: selected.amount,
              min: 0,
              max: 1,
              onChanged: (v) => ctrl.updateMask(selected.id, (m) => m.copyWith(amount: v), live: true),
              onChangeEnd: (_) => ctrl.commit(),
            ),
            ParamSliders(
              maskId: selected.id,
              params: const [
                AdjustmentParam.exposure,
                AdjustmentParam.contrast,
                AdjustmentParam.highlights,
                AdjustmentParam.shadows,
                AdjustmentParam.temperature,
                AdjustmentParam.tint,
                AdjustmentParam.saturation,
                AdjustmentParam.clarity,
                AdjustmentParam.dehaze,
                AdjustmentParam.blur,
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------- AI

class AiPanel extends ConsumerWidget {
  const AiPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(photoEditorControllerProvider);
    final ctrl = ref.read(photoEditorControllerProvider.notifier);
    final l = context.l10n;
    if (s.eraserMode) {
      return SingleChildScrollView(
        child: Column(
          children: [
            Padding(padding: const EdgeInsets.all(12), child: Text(l.aiEraserHint)),
            const DrawPanel(showColors: false),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () {
                    clearPendingEraserStrokes();
                    ctrl.setEraserMode(value: false);
                  },
                  child: Text(l.cancel),
                ),
                const SizedBox(width: 12),
                FilledButton(onPressed: () => ctrl.eraseObjects(takePendingEraserStrokes()), child: Text(l.apply)),
              ],
            ),
          ],
        ),
      );
    }
    final actions = <(IconData, String, VoidCallback)>[
      (Icons.auto_fix_high, l.aiAutoEnhance, ctrl.autoEnhance),
      (Icons.content_cut, l.aiRemoveBg, ctrl.removeBackground),
      (Icons.person, l.aiPortraitBg, () => ctrl.removeBackground(portrait: true)),
      (Icons.blur_on, l.aiBlurBg, () => ctrl.subjectAdjustment(blurBackground: true)),
      (Icons.face_retouching_natural, l.aiRetouch, () => ctrl.subjectAdjustment(retouch: true)),
      (Icons.cleaning_services_outlined, l.aiEraser, () => ctrl.setEraserMode(value: true)),
      (Icons.high_quality, l.aiUpscale, ctrl.upscale),
    ];
    return GridView.count(
      crossAxisCount: 4,
      padding: const EdgeInsets.all(12),
      childAspectRatio: 0.95,
      children: [
        for (final (icon, label, action) in actions)
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: s.busy ? null : action,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(radius: 22, child: Icon(icon)),
                const SizedBox(height: 6),
                Text(label, textAlign: TextAlign.center, maxLines: 2, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
      ],
    );
  }
}
