import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lumora/core/router/app_router.dart';
import 'package:lumora/core/ui/ui.dart';
import 'package:lumora/core/utils/haptics.dart';
import 'package:lumora/core/utils/l10n_ext.dart';
import 'package:lumora/core/widgets/labeled_slider.dart';
import 'package:lumora/features/photo_editor/data/preset_store.dart';
import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/photo_editor/domain/presets.dart';
import 'package:lumora/features/photo_editor/presentation/widgets/tool_panels.dart' show paramLabel, promptText;
import 'package:lumora/features/video_editor/domain/look_keyframes.dart';
import 'package:lumora/features/video_editor/domain/timeline_ops.dart';
import 'package:lumora/features/video_editor/domain/video_project.dart';
import 'package:lumora/features/video_editor/engine/video_engine.dart';
import 'package:lumora/features/video_editor/presentation/video_editor_controller.dart';
import 'package:lumora/features/video_editor/presentation/widgets/caption_panel.dart';
import 'package:lumora/features/video_editor/presentation/widgets/timeline_view.dart';
import 'package:lumora/features/video_editor/presentation/widgets/video_crop_sheet.dart';
import 'package:lumora/features/video_editor/presentation/widgets/video_preview.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

enum _VideoTool { clip, look, text, captions, audio, format }

enum _ExportKind { fast, studio, gif }

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
      child: LumoraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: GlassAppBar(
            actions: [
              IconButton(
                onPressed: s.history.canUndo ? ctrl.undo : null,
                icon: const Icon(Icons.undo),
                tooltip: l.undo,
              ),
              IconButton(
                onPressed: s.history.canRedo ? ctrl.redo : null,
                icon: const Icon(Icons.redo),
                tooltip: l.redo,
              ),
              const SizedBox(width: 6),
              GlowButton.small(
                onPressed: s.busy || s.project.clips.isEmpty ? null : () => _export(context),
                label: l.export,
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 840;
              final main = <Widget>[
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
                      tooltip: _preview.currentState?.playing ?? false ? l.pause : l.play,
                      icon: Icon(_preview.currentState?.playing ?? false ? Icons.pause : Icons.play_arrow),
                      onPressed: () async {
                        await _preview.currentState?.togglePlay();
                        setState(() {});
                      },
                    ),
                    Text('${_fmt(s.playheadMs)} / ${_fmt(s.project.totalDurationMs)}'),
                    const Spacer(),
                    IconButton(
                      tooltip: l.snapToBeats,
                      isSelected: s.snapToBeats,
                      icon: const Icon(Icons.music_note_outlined),
                      selectedIcon: const Icon(Icons.music_note),
                      onPressed: ctrl.toggleSnapToBeats,
                    ),
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
              ];
              if (wide) {
                return Row(
                  children: [
                    Expanded(child: Column(children: main)),
                    const VerticalDivider(width: 1),
                    SizedBox(
                      width: 360,
                      child: Column(
                        children: [
                          Expanded(child: _panel(context, s)),
                          _toolBar(context),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  ...main,
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: GlassContainer(
                      radius: 24,
                      height: 190,
                      fill: context.lumora.glassFillStrong,
                      padding: const EdgeInsets.only(top: 6),
                      child: _panel(context, s),
                    ),
                  ),
                  _toolBar(context),
                ],
              );
            },
          ),
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
      (_VideoTool.captions, Icons.closed_caption_outlined, l.captions),
      (_VideoTool.audio, Icons.music_note_outlined, l.music),
      (_VideoTool.format, Icons.aspect_ratio, l.aspectRatio),
    ];
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: GlassContainer(
          blur: true,
          radius: 26,
          fill: context.lumora.glassFillStrong,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final (tool, icon, label) in items)
                Expanded(
                  child: GlassToolTile(
                    icon: icon,
                    label: label,
                    active: tool == _tool,
                    onTap: () {
                      Haptics.selection();
                      setState(() => _tool = tool);
                    },
                  ),
                ),
            ],
          ),
        ),
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
                _act(Icons.crop, l.toolCrop, () => _cropDialog(context, clip), selected: clip.isCropped),
                _act(Icons.add_photo_alternate_outlined, l.saveFrame, () => _saveFrame(context)),
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
            SwitchListTile(
              dense: true,
              secondary: const Icon(Icons.video_stable),
              title: Text(l.stabilize),
              subtitle: Text(l.stabilizeHint),
              value: clip.stabilize,
              onChanged: (v) => ctrl.setStabilize(clip.id, enabled: v),
            ),
            if (clip.stabilize)
              LabeledSlider(
                label: l.intensity,
                value: clip.stabilizeStrength,
                min: 0,
                max: 1,
                onChanged: (v) => ctrl.setStabilize(clip.id, enabled: true, strength: v),
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
                  for (final p in [...kBuiltInPresets, ...ref.watch(presetLibraryControllerProvider).custom])
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
            Row(
              children: [
                Expanded(
                  child: LabeledSlider(
                    label: s.project.lookKeyframes.isEmpty ? l.lookStrength : '${l.lookStrength} ◆',
                    value: s.project.lookIntensityAt(s.playheadMs),
                    min: 0,
                    max: 1,
                    onChanged: (v) => ctrl.setLookIntensity(v, live: true),
                    onChangeEnd: (_) => ctrl.commit(),
                  ),
                ),
                IconButton(
                  tooltip: l.keyframe,
                  isSelected: s.project.keyframeNear(s.playheadMs) != null,
                  icon: const Icon(Icons.diamond_outlined),
                  selectedIcon: const Icon(Icons.diamond),
                  onPressed: () {
                    Haptics.selection();
                    ctrl.toggleKeyframeAtPlayhead();
                  },
                ),
                if (s.project.lookKeyframes.isNotEmpty)
                  IconButton(
                    tooltip: l.clearKeyframes,
                    icon: const Icon(Icons.layers_clear_outlined),
                    onPressed: ctrl.clearKeyframes,
                  ),
              ],
            ),
            if (s.project.lookKeyframes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  l.keyframesHint(s.project.lookKeyframes.length),
                  style: Theme.of(context).textTheme.bodySmall,
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
      case _VideoTool.captions:
        return CaptionPanel(
          onSeek: (ms) {
            ctrl.seek(ms);
            _preview.currentState?.scrubTo(ms);
          },
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
    final s = ref.read(videoEditorControllerProvider);
    final thumbs = s.thumbnails[clip.path];
    final frameAspect = clip.sourceWidth > 0 && clip.sourceHeight > 0 ? clip.sourceWidth / clip.sourceHeight : 16 / 9;
    final pick = await showModalBottomSheet<List<double>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => VideoCropSheet(
        initial: clip.crop,
        frameAspect: frameAspect,
        framePath: thumbs == null || thumbs.isEmpty ? null : thumbs[thumbs.length ~/ 2],
      ),
    );
    if (pick != null) ref.read(videoEditorControllerProvider.notifier).update((p) => p.cropClip(clip.id, pick));
  }

  Future<void> _saveFrame(BuildContext context) async {
    final l = context.l10n;
    final path = await ref.read(videoEditorControllerProvider.notifier).extractFrame();
    if (path == null || !context.mounted) return;
    Haptics.medium();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.frameSaved),
        action: SnackBarAction(
          label: l.editPhoto,
          onPressed: () => context.push('/photo', extra: PhotoEditorArgs(sourcePath: path)),
        ),
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    final l = context.l10n;
    final kind = await showModalBottomSheet<_ExportKind>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.bolt),
              title: Text(l.exportFast),
              onTap: () => Navigator.pop(c, _ExportKind.fast),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: Text(l.exportStudio),
              onTap: () => Navigator.pop(c, _ExportKind.studio),
            ),
            ListTile(
              leading: const Icon(Icons.gif_box_outlined),
              title: Text(l.exportGif),
              subtitle: Text(l.exportGifHint),
              onTap: () => Navigator.pop(c, _ExportKind.gif),
            ),
          ],
        ),
      ),
    );
    if (kind == null) return;
    final ctrl = ref.read(videoEditorControllerProvider.notifier);
    final out = switch (kind) {
      _ExportKind.fast => await ctrl.export(VideoExportQuality.fast),
      _ExportKind.studio => await ctrl.export(VideoExportQuality.studio),
      _ExportKind.gif => await ctrl.exportGif(),
    };
    if (out == null || !context.mounted) return;
    Haptics.medium();
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
