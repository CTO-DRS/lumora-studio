import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumora/core/router/app_router.dart';
import 'package:lumora/core/utils/l10n_ext.dart';
import 'package:lumora/features/photo_editor/engine/image_exporter.dart';
import 'package:lumora/features/photo_editor/presentation/photo_editor_controller.dart';
import 'package:lumora/features/photo_editor/presentation/widgets/editor_canvas.dart';
import 'package:lumora/features/photo_editor/presentation/widgets/tool_panels.dart';
import 'package:lumora/features/settings/data/settings_controller.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

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
    Future.microtask(() {
      if (id != null) return ctrl.openProject(id);
      if (path != null) return ctrl.open(path);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(photoEditorControllerProvider);
    final ctrl = ref.read(photoEditorControllerProvider.notifier);
    final l = context.l10n;

    ref.listen(photoEditorControllerProvider.select((s) => s.error), (_, error) {
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.aiFailed(error))));
      }
    });

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) unawaited(ctrl.save());
      },
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(tooltip: l.undo, onPressed: s.history.canUndo ? ctrl.undo : null, icon: const Icon(Icons.undo)),
            IconButton(tooltip: l.redo, onPressed: s.history.canRedo ? ctrl.redo : null, icon: const Icon(Icons.redo)),
            Tooltip(
              message: l.compare,
              child: GestureDetector(
                onTapDown: (_) => ctrl.setComparing(value: true),
                onTapUp: (_) => ctrl.setComparing(value: false),
                onTapCancel: () => ctrl.setComparing(value: false),
                child: const Padding(padding: EdgeInsets.all(12), child: Icon(Icons.compare)),
              ),
            ),
            IconButton(
              tooltip: l.save,
              icon: const Icon(Icons.save_outlined),
              onPressed: () async {
                await ctrl.save();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.saved)));
                }
              },
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: FilledButton(
                onPressed: s.busy || s.rendered == null ? null : () => _showExport(context),
                child: Text(l.export),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  const Positioned.fill(child: EditorCanvas()),
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
              ),
            ),
            SizedBox(height: 230, child: _panel(s.tool)),
            _ToolBar(selected: s.tool, onSelect: ctrl.setTool),
          ],
        ),
      ),
    );
  }

  Widget _panel(EditorTool tool) => switch (tool) {
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
    EditorTool.ai => const AiPanel(),
  };

  Future<void> _showExport(BuildContext context) async {
    final settings = ref.read(settingsControllerProvider);
    var format = settings.exportFormat;
    var quality = settings.exportQuality.toDouble();
    var keepExif = settings.keepExif;
    final l = context.l10n;
    final go = await showModalBottomSheet<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.exportFormat, style: Theme.of(c).textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<ExportFormat>(
                segments: [
                  for (final f in ExportFormat.values) ButtonSegment(value: f, label: Text(f.extension.toUpperCase())),
                ],
                selected: {format},
                onSelectionChanged: (v) => setSheet(() => format = v.first),
              ),
              if (format != ExportFormat.png) ...[
                const SizedBox(height: 12),
                Text('${l.quality}: ${quality.round()}'),
                Slider(value: quality, min: 50, max: 100, divisions: 50, onChanged: (v) => setSheet(() => quality = v)),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.keepExif),
                value: keepExif,
                onChanged: format == ExportFormat.jpeg ? (v) => setSheet(() => keepExif = v) : null,
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => Navigator.pop(c, true),
                icon: const Icon(Icons.ios_share),
                label: Text('${l.export} · ${l.fullResolution}'),
              ),
            ],
          ),
        ),
      ),
    );
    if (go != true) return;
    await ref
        .read(settingsControllerProvider.notifier)
        .setExport(format: format, quality: quality.round(), keepExif: keepExif);
    final file = await ref
        .read(photoEditorControllerProvider.notifier)
        .export(ExportOptions(format: format, quality: quality.round(), keepExif: keepExif));
    if (file == null || !context.mounted) return;
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

class _ToolBar extends StatelessWidget {
  const _ToolBar({required this.selected, required this.onSelect});

  final EditorTool selected;
  final ValueChanged<EditorTool> onSelect;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = <(EditorTool, IconData, String)>[
      (EditorTool.presets, Icons.auto_awesome, l.toolPresets),
      (EditorTool.adjust, Icons.tune, l.toolAdjust),
      (EditorTool.hsl, Icons.palette_outlined, l.toolHsl),
      (EditorTool.curves, Icons.show_chart, l.toolCurves),
      (EditorTool.lut, Icons.filter_vintage_outlined, l.toolLut),
      (EditorTool.crop, Icons.crop_rotate, l.toolCrop),
      (EditorTool.masks, Icons.blur_circular, l.toolMasks),
      (EditorTool.ai, Icons.psychology_alt_outlined, l.toolAi),
      (EditorTool.text, Icons.text_fields, l.toolText),
      (EditorTool.stickers, Icons.emoji_emotions_outlined, l.toolStickers),
      (EditorTool.draw, Icons.draw_outlined, l.toolDraw),
    ];
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 64,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            for (final (tool, icon, label) in items)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onSelect(tool),
                child: SizedBox(
                  width: 68,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: tool == selected ? scheme.primary : scheme.onSurfaceVariant),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: tool == selected ? scheme.primary : scheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
