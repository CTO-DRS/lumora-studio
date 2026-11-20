import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lumora/core/router/app_router.dart';
import 'package:lumora/core/utils/l10n_ext.dart';
import 'package:lumora/core/widgets/labeled_slider.dart';
import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/photo_editor/domain/presets.dart';
import 'package:lumora/features/photo_editor/presentation/widgets/tool_panels.dart' show paramLabel, promptText;
import 'package:lumora/features/video_editor/domain/timeline_ops.dart';
import 'package:lumora/features/video_editor/domain/video_project.dart';
import 'package:lumora/features/video_editor/engine/video_engine.dart';
import 'package:lumora/features/video_editor/presentation/video_editor_controller.dart';
import 'package:lumora/features/video_editor/presentation/widgets/timeline_view.dart';
import 'package:lumora/features/video_editor/presentation/widgets/video_preview.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

enum _VideoTool { clip, look, text, audio, format }

class VideoEditorPage extends ConsumerStatefulWidget {
  const VideoEditorPage({required this.args, super.key});

  final VideoEditorArgs args;

  @override
  ConsumerState<VideoEditorPage> createState() => _VideoEditorPageState();
}

class _VideoEditorPageState extends ConsumerState<VideoEditorPage> {
  final _preview = GlobalKey<VideoPreviewState>();
  _VideoTool _tool = _VideoTool.clip;

  @override
  void initState() {
    super.initState();
    final ctrl = ref.read(videoEditorControllerProvider.notifier);
    Future.microtask(() {
      final id = widget.args.projectId;
      if (id != null) return ctrl.openProject(id);
      return ctrl.openFiles(widget.args.paths);
    });
  }

  String _fmt(int ms) {
    final s = ms ~/ 1000;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}.${ms % 1000 ~/ 100}';
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(videoEditorControllerProvider);
    final ctrl = ref.read(videoEditorControllerProvider.notifier);
    final l = context.l10n;
    ref.listen(videoEditorControllerProvider.select((s) => s.error), (_, e) {
      if (e != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.errorGeneric(e))));
    });
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) unawaited(ctrl.save());
      },
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(onPressed: s.history.canUndo ? ctrl.undo : null, icon: const Icon(Icons.undo), tooltip: l.undo),
            IconButton(onPressed: s.history.canRedo ? ctrl.redo : null, icon: const Icon(Icons.redo), tooltip: l.redo),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: FilledButton(
                onPressed: s.busy || s.project.clips.isEmpty ? null : () => _export(context),
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
                  Positioned.fill(child: VideoPreview(key: _preview)),
                  if (s.busy && s.progress != null)
                    Positioned.fill(
                      child: ColoredBox(
                        color: Colors.black54,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(value: s.progress),
                              const SizedBox(height: 12),
                              Text('${l.exporting} ${((s.progress ?? 0) * 100).round()}%'),
                              TextButton(onPressed: ctrl.cancelExport, child: Text(l.cancel)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: Icon(_preview.currentState?.playing ?? false ? Icons.pause : Icons.play_arrow),
                  onPressed: () async {
                    await _preview.currentState?.togglePlay();
                    setState(() {});
                  },
                ),
                Text('${_fmt(s.playheadMs)} / ${_fmt(s.project.totalDurationMs)}'),
                const Spacer(),
                IconButton(tooltip: l.split, icon: const Icon(Icons.content_cut), onPressed: ctrl.splitAtPlayhead),
                IconButton(
                  tooltip: l.addClip,
                  icon: const Icon(Icons.add_box_outlined),
                  onPressed: () async {
                    final files = await ImagePicker().pickMultiVideo();
                    if (files.isNotEmpty) await ctrl.addClips([for (final f in files) f.path]);
                  },
                ),
              ],
            ),
            SizedBox(height: 130, child: TimelineView(onScrub: (ms) => _preview.currentState?.scrubTo(ms))),
            SizedBox(height: 190, child: _panel(context, s)),
            _toolBar(context),
          ],
        ),
      ),
    );
  }

  Widget _toolBar(BuildContext context) {
    final l = context.l10n;
    final items = <(_VideoTool, IconData, String)>[
      (_VideoTool.clip, Icons.movie_edit, l.trim),
      (_VideoTool.look, Icons.auto_awesome, l.filter),
      (_VideoTool.text, Icons.text_fields, l.toolText),
      (_VideoTool.audio, Icons.music_note_outlined, l.music),
      (_VideoTool.format, Icons.aspect_ratio, l.aspectRatio),
    ];
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final (tool, icon, label) in items)
            InkWell(
              onTap: () => setState(() => _tool = tool),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Icon(icon, color: tool == _tool ? scheme.primary : null),
                    Text(label, style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _panel(BuildContext context, VideoEditorState s) {
    final ctrl = ref.read(videoEditorControllerProvider.notifier);
    final l = context.l10n;
    switch (_tool) {
      case _VideoTool.clip:
        final clip = s.selectedClip;
        if (clip == null) return Center(child: Text(l.timeline));
        return ListView(
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              children: [
                for (final v in const [0.25, 0.5, 1.0, 1.5, 2.0, 4.0])
                  ChoiceChip(
                    label: Text('$v×'),
                    selected: clip.speed == v,
                    onSelected: (_) => ctrl.update((p) => p.setSpeed(clip.id, v)),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: RangeSlider(
                values: RangeValues(clip.inMs.toDouble(), clip.outMs.toDouble()),
                max: clip.sourceDurationMs.toDouble(),
                labels: RangeLabels(_fmt(clip.inMs), _fmt(clip.outMs)),
                onChanged: (r) =>
                    ctrl.update((p) => p.trimClip(clip.id, inMs: r.start.round(), outMs: r.end.round()), live: true),
                onChangeEnd: (_) => ctrl.commit(),
              ),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                _act(
                  Icons.swap_horiz,
                  l.reverse,
                  () => ctrl.update((p) => p.toggleReverse(clip.id)),
                  selected: clip.reversed,
                ),
                _act(Icons.rotate_90_degrees_cw_outlined, l.rotate, () => ctrl.update((p) => p.rotateClip(clip.id))),
                _act(Icons.crop, l.toolCrop, () => _cropDialog(context, clip)),
                _act(
                  Icons.copy,
                  l.duplicate,
                  () => ctrl.update((p) => p.duplicateClip(clip.id, newId: UniqueKey().toString())),
                ),
                _act(Icons.chevron_left, '', () {
                  final i = s.project.clips.indexOf(clip);
                  ctrl.update((p) => p.moveClip(i, i - 1));
                }),
                _act(Icons.chevron_right, '', () {
                  final i = s.project.clips.indexOf(clip);
                  ctrl.update((p) => p.moveClip(i, i + 1));
                }),
                _act(Icons.delete_outline, l.delete, () {
                  ctrl
                    ..update((p) => p.removeClip(clip.id))
                    ..select(null);
                }),
              ],
            ),
            LabeledSlider(
              label: l.volume,
              value: clip.volume,
              min: 0,
              max: 2,
              neutral: 0,
              onChanged: (v) => ctrl.update((p) => p.setClipVolume(clip.id, v), live: true),
              onChangeEnd: (_) => ctrl.commit(),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  Center(child: Text('${l.transition}: ')),
                  for (final t in TransitionKind.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: ChoiceChip(
                        label: Text(t.name),
                        selected: clip.transitionOut == t,
                        onSelected: (_) => ctrl.update((p) => p.setTransition(clip.id, t)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      case _VideoTool.look:
        final look = s.project.look;
        final lang = Localizations.localeOf(context).languageCode;
        return ListView(
          children: [
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  ChoiceChip(
                    label: Text(l.none),
                    selected: s.project.presetId == null,
                    onSelected: (_) => ctrl.applyPreset(null),
                  ),
                  for (final p in kBuiltInPresets)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 6),
                      child: ChoiceChip(
                        label: Text(p.name(lang)),
                        selected: s.project.presetId == p.id,
                        onSelected: (_) => ctrl.applyPreset(p.id),
                      ),
                    ),
                ],
              ),
            ),
            for (final param in const [
              AdjustmentParam.exposure,
              AdjustmentParam.contrast,
              AdjustmentParam.highlights,
              AdjustmentParam.shadows,
              AdjustmentParam.temperature,
              AdjustmentParam.tint,
              AdjustmentParam.vibrance,
              AdjustmentParam.saturation,
              AdjustmentParam.fade,
              AdjustmentParam.sharpen,
              AdjustmentParam.vignette,
              AdjustmentParam.grain,
            ])
              LabeledSlider(
                label: paramLabel(l, param),
                value: param.read(look),
                min: param.min,
                max: param.max,
                neutral: param.neutral,
                displayScale: param == AdjustmentParam.exposure ? 20 : 100,
                onChanged: (v) => ctrl.update((p) => p.copyWith(look: param.write(p.look, v)), live: true),
                onChangeEnd: (_) => ctrl.commit(),
              ),
          ],
        );
      case _VideoTool.text:
        final selected = s.project.texts.where((t) => t.id == s.selectedTextId).firstOrNull;
        return ListView(
          children: [
            Center(
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.title),
                label: Text(l.addText),
                onPressed: () async {
                  final t = await promptText(context, title: l.addText);
                  if (t != null && t.trim().isNotEmpty) ctrl.addText(t);
                },
              ),
            ),
            if (selected != null) ...[
              LabeledSlider(
                label: l.start,
                value: selected.startMs / 1000,
                min: 0,
                max: (s.project.totalDurationMs / 1000).clamp(0.1, double.infinity),
                displayScale: 1,
                onChanged: (v) =>
                    ctrl.updateText(selected.id, (t) => t.copyWith(startMs: (v * 1000).round()), live: true),
                onChangeEnd: (_) => ctrl.commit(),
              ),
              LabeledSlider(
                label: l.end,
                value: selected.endMs / 1000,
                min: 0,
                max: (s.project.totalDurationMs / 1000).clamp(0.1, double.infinity),
                displayScale: 1,
                onChanged: (v) =>
                    ctrl.updateText(selected.id, (t) => t.copyWith(endMs: (v * 1000).round()), live: true),
                onChangeEnd: (_) => ctrl.commit(),
              ),
              LabeledSlider(
                label: l.size,
                value: selected.fontSize,
                min: 0.02,
                max: 0.2,
                neutral: 0.02,
                onChanged: (v) => ctrl.updateText(selected.id, (t) => t.copyWith(fontSize: v), live: true),
                onChangeEnd: (_) => ctrl.commit(),
              ),
              LabeledSlider(
                label: 'Y',
                value: selected.y,
                min: 0,
                max: 1,
                onChanged: (v) => ctrl.updateText(selected.id, (t) => t.copyWith(y: v), live: true),
                onChangeEnd: (_) => ctrl.commit(),
              ),
              Center(
                child: TextButton.icon(
                  onPressed: () => ctrl.removeText(selected.id),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l.removeLayer),
                ),
              ),
            ],
          ],
        );
      case _VideoTool.audio:
        final music = s.project.music;
        return ListView(
          children: [
            LabeledSlider(
              label: l.originalAudio,
              value: s.project.originalVolume,
              min: 0,
              max: 2,
              neutral: 0,
              onChanged: (v) => ctrl.update((p) => p.copyWith(originalVolume: v), live: true),
              onChangeEnd: (_) => ctrl.commit(),
            ),
            if (music == null)
              Center(
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.library_music_outlined),
                  label: Text(l.addMusic),
                  onPressed: () async {
                    final path = (await FilePicker.pickFile(type: FileType.audio))?.path;
                    if (path != null) ctrl.setMusic(path);
                  },
                ),
              )
            else ...[
              LabeledSlider(
                label: l.music,
                value: music.volume,
                min: 0,
                max: 2,
                neutral: 0,
                onChanged: (v) => ctrl.update((p) => p.copyWith(music: music.copyWith(volume: v)), live: true),
                onChangeEnd: (_) => ctrl.commit(),
              ),
              Center(
                child: TextButton.icon(
                  onPressed: () => ctrl.setMusic(null),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l.delete),
                ),
              ),
            ],
          ],
        );
      case _VideoTool.format:
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            Text(l.aspectRatio),
            Wrap(
              spacing: 6,
              children: [
                for (final a in VideoAspect.values)
                  ChoiceChip(
                    label: Text('${a.w}:${a.h}'),
                    selected: s.project.aspect == a,
                    onSelected: (_) => ctrl.update((p) => p.copyWith(aspect: a)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l.resolution),
            Wrap(
              spacing: 6,
              children: [
                for (final r in VideoResolution.values)
                  ChoiceChip(
                    label: Text('${r.height}p'),
                    selected: s.project.resolution == r,
                    onSelected: (_) => ctrl.update((p) => p.copyWith(resolution: r)),
                  ),
                for (final fps in const [24, 30, 60])
                  ChoiceChip(
                    label: Text('$fps fps'),
                    selected: s.project.fps == fps,
                    onSelected: (_) => ctrl.update((p) => p.copyWith(fps: fps)),
                  ),
              ],
            ),
          ],
        );
    }
  }

  Widget _act(IconData icon, String label, VoidCallback onTap, {bool selected = false}) => Padding(
    padding: const EdgeInsets.all(2),
    child: IconButton(tooltip: label.isEmpty ? null : label, isSelected: selected, icon: Icon(icon), onPressed: onTap),
  );

  Future<void> _cropDialog(BuildContext context, VideoClip clip) async {
    final presets = <(String, List<double>)>[
      ('Full', [0, 0, 1, 1]),
      ('Center 80%', [0.1, 0.1, 0.9, 0.9]),
      ('Center square', _squareCrop(clip)),
      ('Top half', [0, 0, 1, 0.5]),
      ('Bottom half', [0, 0.5, 1, 1]),
    ];
    final pick = await showModalBottomSheet<List<double>>(
      context: context,
      builder: (c) => ListView(
        shrinkWrap: true,
        children: [
          for (final (name, rect) in presets) ListTile(title: Text(name), onTap: () => Navigator.pop(c, rect)),
        ],
      ),
    );
    if (pick != null) ref.read(videoEditorControllerProvider.notifier).update((p) => p.cropClip(clip.id, pick));
  }

  List<double> _squareCrop(VideoClip c) {
    if (c.sourceWidth == 0 || c.sourceHeight == 0) return [0, 0, 1, 1];
    if (c.sourceWidth > c.sourceHeight) {
      final w = c.sourceHeight / c.sourceWidth;
      return [(1 - w) / 2, 0, (1 + w) / 2, 1];
    }
    final h = c.sourceWidth / c.sourceHeight;
    return [0, (1 - h) / 2, 1, (1 + h) / 2];
  }

  Future<void> _export(BuildContext context) async {
    final l = context.l10n;
    final quality = await showModalBottomSheet<VideoExportQuality>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.bolt),
              title: Text(l.exportFast),
              onTap: () => Navigator.pop(c, VideoExportQuality.fast),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: Text(l.exportStudio),
              onTap: () => Navigator.pop(c, VideoExportQuality.studio),
            ),
          ],
        ),
      ),
    );
    if (quality == null) return;
    final out = await ref.read(videoEditorControllerProvider.notifier).export(quality);
    if (out == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.videoExported),
        action: SnackBarAction(
          label: l.share,
          onPressed: () => SharePlus.instance.share(ShareParams(files: [XFile(out)])),
        ),
      ),
    );
  }
}
