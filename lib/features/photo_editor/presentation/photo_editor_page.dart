import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumora/core/router/app_router.dart';
import 'package:lumora/core/ui/ui.dart';
import 'package:lumora/core/utils/haptics.dart';
import 'package:lumora/core/utils/l10n_ext.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:lumora/features/ai/presentation/ai_error_text.dart';
import 'package:lumora/features/ai/presentation/model_download_dialog.dart';
import 'package:lumora/features/photo_editor/data/preset_store.dart';
import 'package:lumora/features/photo_editor/domain/edit_clipboard.dart';
import 'package:lumora/features/photo_editor/engine/image_exporter.dart';
import 'package:lumora/features/photo_editor/engine/pixel_ops.dart';
import 'package:lumora/features/photo_editor/presentation/photo_editor_controller.dart';
import 'package:lumora/features/photo_editor/presentation/widgets/editor_canvas.dart';
import 'package:lumora/features/photo_editor/presentation/widgets/finish_panels.dart';
import 'package:lumora/features/photo_editor/presentation/widgets/tool_panels.dart';
import 'package:lumora/features/settings/data/settings_controller.dart';
import 'package:lumora/features/smart_edit/presentation/smart_panel.dart';
import 'package:lumora/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

/// Screens at least this wide use the side-panel (tablet) layout.
const kTabletBreakpoint = 840.0;

class PhotoEditorPage extends ConsumerStatefulWidget {
  const PhotoEditorPage({required this.args, super.key});

  final PhotoEditorArgs args;

  @override
  ConsumerState<PhotoEditorPage> createState() => _PhotoEditorPageState();
}

class _PhotoEditorPageState extends ConsumerState<PhotoEditorPage> {
  @override
  void initState() {
    super.initState();
    final ctrl = ref.read(photoEditorControllerProvider.notifier);
    final id = widget.args.projectId;
    final path = widget.args.sourcePath;
    Future.microtask(() async {
      if (id != null) {
        await ctrl.openProject(id);
      } else if (path != null) {
        await ctrl.open(path);
      }
      await _runInitialAction(ctrl);
    });
  }

  Future<void> _runInitialAction(PhotoEditorController ctrl) async {
    final presetId = widget.args.initialPresetId;
    if (presetId != null) {
      ctrl
        ..setTool(EditorTool.presets)
        ..applyPreset(presetId);
    }
    Future<bool> models(AiTool tool) async => mounted && await ensureModelsDownloaded(context, ref, aiToolModels(tool));
    switch (widget.args.initialAction) {
      case null:
        return;
      case QuickAction.removeBackground:
        ctrl.setTool(EditorTool.ai);
        if (!mounted || !await ensureModelsDownloaded(context, ref, aiToolModels(AiTool.removeBackground))) return;
        await ctrl.removeBackground();
      case QuickAction.autoEnhance:
        ctrl.setTool(EditorTool.adjust);
        await ctrl.autoEnhance();
      case QuickAction.upscale:
        ctrl.setTool(EditorTool.ai);
        if (!mounted || !await ensureModelsDownloaded(context, ref, aiToolModels(AiTool.upscale))) return;
        await ctrl.upscale();
      case QuickAction.eraser:
        ctrl.setTool(EditorTool.ai);
        if (!mounted || !await ensureModelsDownloaded(context, ref, aiToolModels(AiTool.eraser))) return;
        ctrl.setEraserMode(value: true);
      case QuickAction.heal:
        ctrl.setTool(EditorTool.heal);
      case QuickAction.cutOutPerson:
        ctrl.setTool(EditorTool.ai);
        if (!await models(AiTool.cutOutPerson)) return;
        await ctrl.removeBackground(portrait: true);
      case QuickAction.blurBackground:
        ctrl.setTool(EditorTool.ai);
        if (!await models(AiTool.backgroundBlur)) return;
        await ctrl.subjectAdjustment(blurBackground: true);
      case QuickAction.retouch:
        ctrl.setTool(EditorTool.ai);
        if (!await models(AiTool.portraitRetouch)) return;
        await ctrl.subjectAdjustment(retouch: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(photoEditorControllerProvider);
    final ctrl = ref.read(photoEditorControllerProvider.notifier);
    // Keeps the live preset thumbnails cached while the editor is open.
    ref.watch(presetThumbnailCacheProvider);
    final l = context.l10n;

    ref.listen(photoEditorControllerProvider.select((s) => s.error), (_, error) {
      if (error != null) {
        final failure = ref.read(photoEditorControllerProvider).failure;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.aiFailed(failure == null ? error : aiErrorText(l, failure)))));
      }
    });

    final canvas = Stack(
      children: [
        const Positioned.fill(child: EditorCanvas()),
        if (s.showHistogram && s.histogram != null)
          PositionedDirectional(
            top: 8,
            start: 8,
            child: IgnorePointer(child: HistogramView(histogram: s.histogram!)),
          ),
        if (s.busy)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black45,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(value: s.progress),
                        const SizedBox(height: 12),
                        Text(l.aiWorking),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    final panel = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(anim),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(s.tool), child: _panel(s.tool)),
    );

    final topBar = _EditorTopBar(state: s, onExport: () => _showExport(context));

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) unawaited(ctrl.save());
      },
      child: LumoraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, c) {
                if (c.maxWidth >= kTabletBreakpoint) {
                  return Column(
                    children: [
                      Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 4), child: topBar),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(child: canvas),
                            Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(0, 8, 12, 12),
                              child: SizedBox(
                                width: 380,
                                child: GlassContainer(
                                  radius: 26,
                                  fill: context.lumora.glassFillStrong,
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: Padding(padding: const EdgeInsets.only(top: 8), child: panel),
                                      ),
                                      const Divider(height: 1),
                                      _ToolBar(selected: s.tool, onSelect: _select, wrap: true),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                final panelHeight = (c.maxHeight * 0.3).clamp(196.0, 270.0);
                return Column(
                  children: [
                    Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 0), child: topBar),
                    Expanded(child: canvas),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: GlassContainer(
                        radius: 26,
                        height: panelHeight,
                        fill: context.lumora.glassFillStrong,
                        padding: const EdgeInsets.only(top: 10),
                        child: panel,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                      child: _ToolBar(selected: s.tool, onSelect: _select),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _select(EditorTool tool) {
    Haptics.selection();
    // Unapplied eraser/heal strokes belong to the tool being left.
    clearPendingEraserStrokes();
    ref.read(photoEditorControllerProvider.notifier).setTool(tool);
  }

  Widget _panel(EditorTool tool) => switch (tool) {
    EditorTool.smart => const SmartPanel(),
    EditorTool.presets => const PresetsPanel(),
    EditorTool.adjust => const AdjustPanel(),
    EditorTool.hsl => const HslPanel(),
    EditorTool.curves => const CurvesPanel(),
    EditorTool.lut => const LutPanel(),
    EditorTool.crop => const CropPanel(),
    EditorTool.text => const TextPanel(),
    EditorTool.stickers => const StickersPanel(),
    EditorTool.draw => const DrawPanel(),
    EditorTool.masks => const MasksPanel(),
    EditorTool.heal => const HealPanel(),
    EditorTool.ai => const AiPanel(),
    EditorTool.frame => const FramePanel(),
    EditorTool.watermark => const WatermarkPanel(),
  };

  Future<void> _showExport(BuildContext context) async {
    final settings = ref.read(settingsControllerProvider);
    final l = context.l10n;
    final options = await showModalBottomSheet<(ExportOptions, bool)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => ExportSheet(
        initial: ExportOptions(
          format: settings.exportFormat,
          quality: settings.exportQuality,
          keepExif: settings.keepExif,
          maxDimension: settings.exportMaxDimension,
        ),
      ),
    );
    if (options == null) return;
    final (opts, shareAfter) = options;
    await ref
        .read(settingsControllerProvider.notifier)
        .setExport(format: opts.format, quality: opts.quality, keepExif: opts.keepExif);
    final file = await ref.read(photoEditorControllerProvider.notifier).export(opts);
    if (file == null || !context.mounted) return;
    Haptics.medium();
    if (shareAfter) {
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.exported),
        action: SnackBarAction(
          label: l.share,
          onPressed: () => SharePlus.instance.share(ShareParams(files: [XFile(file.path)])),
        ),
      ),
    );
  }
}

String socialLabel(AppLocalizations l, SocialSize s) => switch (s) {
  SocialSize.original => l.sizeOriginal,
  SocialSize.instagramPortrait => 'Instagram 4:5',
  SocialSize.instagramSquare => 'Instagram 1:1',
  SocialSize.story => '${l.sizeStory} 9:16',
  SocialSize.x => 'X 16:9',
  SocialSize.whatsapp => 'WhatsApp',
  SocialSize.facebook => 'Facebook',
};

/// Export options sheet. Pops `(options, shareInsteadOfSaving)`.
class ExportSheet extends StatefulWidget {
  const ExportSheet({required this.initial, super.key});
  final ExportOptions initial;

  @override
  State<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<ExportSheet> {
  late ExportFormat _format = widget.initial.format;
  late double _quality = widget.initial.quality.toDouble();
  late bool _keepExif = widget.initial.keepExif;
  SocialSize _social = SocialSize.original;
  SocialFit _fit = SocialFit.pad;
  bool _padBlur = true;

  ExportOptions _options({required bool gallery}) => ExportOptions(
    format: _format,
    quality: _quality.round(),
    keepExif: _keepExif,
    maxDimension: _social == SocialSize.original ? widget.initial.maxDimension : null,
    social: _social,
    socialFit: _fit,
    padBlur: _padBlur,
    saveToGallery: gallery,
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.exportSize, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final size in SocialSize.values)
                  ChoiceChip(
                    label: Text(socialLabel(l, size)),
                    selected: _social == size,
                    onSelected: (_) => setState(() {
                      _social = size;
                      if (size != SocialSize.original) {
                        _quality = size.quality.toDouble();
                        if (_format == ExportFormat.png) _format = ExportFormat.jpeg;
                      }
                    }),
                  ),
              ],
            ),
            if (_social.fixedAspect) ...[
              const SizedBox(height: 8),
              SegmentedButton<SocialFit>(
                segments: [
                  ButtonSegment(value: SocialFit.pad, icon: const Icon(Icons.fit_screen), label: Text(l.fitPad)),
                  ButtonSegment(value: SocialFit.crop, icon: const Icon(Icons.crop), label: Text(l.fitCrop)),
                ],
                selected: {_fit},
                onSelectionChanged: (v) => setState(() => _fit = v.first),
              ),
              if (_fit == SocialFit.pad)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.frameBlur),
                  value: _padBlur,
                  onChanged: (v) => setState(() => _padBlur = v),
                ),
            ],
            const SizedBox(height: 12),
            Text(l.exportFormat, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<ExportFormat>(
              segments: [
                for (final f in ExportFormat.values) ButtonSegment(value: f, label: Text(f.extension.toUpperCase())),
              ],
              selected: {_format},
              onSelectionChanged: (v) => setState(() => _format = v.first),
            ),
            if (_format != ExportFormat.png) ...[
              const SizedBox(height: 12),
              Text('${l.quality}: ${_quality.round()}'),
              Slider(
                value: _quality,
                min: 50,
                max: 100,
                divisions: 50,
                label: '${_quality.round()}',
                onChanged: (v) => setState(() => _quality = v),
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.keepExif),
              value: _keepExif,
              onChanged: _format == ExportFormat.jpeg ? (v) => setState(() => _keepExif = v) : null,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context, (_options(gallery: false), true)),
                    icon: const Icon(Icons.share_outlined),
                    label: Text(l.share),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, (_options(gallery: true), false)),
                    icon: const Icon(Icons.download_outlined),
                    label: Text(l.saveToGallery),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void _noop() {}

class _MoreMenu extends ConsumerWidget {
  const _MoreMenu({required this.state});
  final PhotoEditorState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final ctrl = ref.read(photoEditorControllerProvider.notifier);
    final canPaste = ref.watch(editClipboardProvider) != null;
    return PopupMenuButton<String>(
      tooltip: l.more,
      padding: EdgeInsets.zero,
      child: const IgnorePointer(
        child: GlassIconButton(icon: Icons.more_horiz, size: 38, onPressed: _noop),
      ),
      onSelected: (v) async {
        switch (v) {
          case 'copy':
            await ctrl.copyEdits();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.editsCopied)));
            }
          case 'paste':
            final opts = await showPasteOptions(context);
            if (opts != null) {
              ctrl.pasteEdits(options: opts);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.editsPasted)));
              }
            }
          case 'preset':
            if (context.mounted) await savePresetDialog(context, ref);
          case 'histogram':
            ctrl.toggleHistogram();
          case 'clipping':
            ctrl.toggleClipping();
          case 'save':
            await ctrl.save();
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.saved)));
          case 'reset':
            ctrl.resetAll();
        }
      },
      itemBuilder: (c) => [
        PopupMenuItem(
          value: 'copy',
          child: ListTile(leading: const Icon(Icons.copy), title: Text(l.copyEdits)),
        ),
        PopupMenuItem(
          value: 'paste',
          enabled: canPaste,
          child: ListTile(leading: const Icon(Icons.paste), title: Text(l.pasteEdits)),
        ),
        PopupMenuItem(
          value: 'preset',
          child: ListTile(leading: const Icon(Icons.bookmark_add_outlined), title: Text(l.savePreset)),
        ),
        const PopupMenuDivider(),
        CheckedPopupMenuItem(value: 'histogram', checked: state.showHistogram, child: Text(l.histogram)),
        CheckedPopupMenuItem(value: 'clipping', checked: state.showClipping, child: Text(l.clippingWarnings)),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'save',
          child: ListTile(leading: const Icon(Icons.save_outlined), title: Text(l.save)),
        ),
        PopupMenuItem(
          value: 'reset',
          child: ListTile(leading: const Icon(Icons.restart_alt), title: Text(l.resetAll)),
        ),
      ],
    );
  }
}

/// Lets the user choose which parts of the copied edit to paste.
Future<PasteOptions?> showPasteOptions(BuildContext context) {
  var opts = const PasteOptions();
  final l = context.l10n;
  return showDialog<PasteOptions>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => AlertDialog(
        title: Text(l.pasteWhat),
        contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              title: Text(l.pasteAdjustments),
              value: opts.adjustments,
              onChanged: (v) => setState(() => opts = opts.copyWith(adjustments: v)),
            ),
            CheckboxListTile(
              title: Text(l.pasteGeometry),
              value: opts.geometry,
              onChanged: (v) => setState(() => opts = opts.copyWith(geometry: v)),
            ),
            CheckboxListTile(
              title: Text(l.pasteMasks),
              value: opts.masks,
              onChanged: (v) => setState(() => opts = opts.copyWith(masks: v)),
            ),
            CheckboxListTile(
              title: Text(l.pasteOverlays),
              value: opts.overlays,
              onChanged: (v) => setState(() => opts = opts.copyWith(overlays: v)),
            ),
            CheckboxListTile(
              title: Text(l.pasteFinishing),
              value: opts.finishing,
              onChanged: (v) => setState(() => opts = opts.copyWith(finishing: v)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, opts), child: Text(l.pasteEdits)),
        ],
      ),
    ),
  );
}

class _EditorTopBar extends ConsumerWidget {
  const _EditorTopBar({required this.state, required this.onExport});

  final PhotoEditorState state;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = state;
    final ctrl = ref.read(photoEditorControllerProvider.notifier);
    const gap = SizedBox(width: 6);
    return GlassTopBar(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      children: [
        GlassIconButton(
          icon: Icons.arrow_back,
          size: 38,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.maybePop(context),
        ),
        gap,
        _MoreMenu(state: s),
        gap,
        GlassIconButton(
          icon: Icons.history,
          size: 38,
          tooltip: l.history,
          onPressed: () => showHistorySheet(context, ref),
        ),
        gap,
        Tooltip(
          message: l.compare,
          child: Semantics(
            button: true,
            label: l.compare,
            child: GestureDetector(
              onTapDown: (_) {
                Haptics.light();
                ctrl.setComparing(value: true);
              },
              onTapUp: (_) => ctrl.setComparing(value: false),
              onTapCancel: () => ctrl.setComparing(value: false),
              child: IgnorePointer(
                child: GlassIconButton(icon: Icons.compare, size: 38, selected: s.comparing, onPressed: () {}),
              ),
            ),
          ),
        ),
        const Spacer(),
        GlassIconButton(icon: Icons.undo, size: 38, tooltip: l.undo, onPressed: s.history.canUndo ? ctrl.undo : null),
        gap,
        GlassIconButton(icon: Icons.redo, size: 38, tooltip: l.redo, onPressed: s.history.canRedo ? ctrl.redo : null),
        const SizedBox(width: 8),
        GlowButton.small(label: l.export, onPressed: s.busy || s.rendered == null ? null : onExport),
      ],
    );
  }
}

class _ToolBar extends StatelessWidget {
  const _ToolBar({required this.selected, required this.onSelect, this.wrap = false});

  final EditorTool selected;
  final ValueChanged<EditorTool> onSelect;

  /// Grid layout for the tablet side panel.
  final bool wrap;

  static List<(EditorTool, IconData, String)> items(AppLocalizations l) => [
    (EditorTool.smart, Icons.tips_and_updates_outlined, l.toolSmart),
    (EditorTool.presets, Icons.auto_awesome, l.toolPresets),
    (EditorTool.adjust, Icons.tune, l.toolAdjust),
    (EditorTool.hsl, Icons.palette_outlined, l.toolHsl),
    (EditorTool.ai, Icons.psychology_alt_outlined, l.toolAi),
    (EditorTool.crop, Icons.crop_rotate, l.toolCrop),
    (EditorTool.text, Icons.text_fields, l.toolText),
    (EditorTool.draw, Icons.draw_outlined, l.toolDraw),
    (EditorTool.curves, Icons.show_chart, l.toolCurves),
    (EditorTool.lut, Icons.filter_vintage_outlined, l.toolLut),
    (EditorTool.masks, Icons.blur_circular, l.toolMasks),
    (EditorTool.heal, Icons.healing, l.toolHeal),
    (EditorTool.stickers, Icons.emoji_emotions_outlined, l.toolStickers),
    (EditorTool.frame, Icons.crop_din, l.toolFrame),
    (EditorTool.watermark, Icons.branding_watermark_outlined, l.toolWatermark),
  ];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.lumora;
    Widget item(EditorTool tool, IconData icon, String label) =>
        GlassToolTile(icon: icon, label: label, active: tool == selected, onTap: () => onSelect(tool));

    final list = items(l);
    if (wrap) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(alignment: WrapAlignment.center, children: [for (final (t, i, label) in list) item(t, i, label)]),
      );
    }
    return GlassContainer(
      blur: true,
      radius: 26,
      height: 84,
      fill: t.glassFillStrong,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        children: [for (final (t, i, label) in list) item(t, i, label)],
      ),
    );
  }
}
