import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumora/core/utils/haptics.dart';
import 'package:lumora/core/utils/l10n_ext.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:lumora/features/ai/presentation/model_download_dialog.dart';
import 'package:lumora/features/photo_editor/presentation/widgets/tool_panels.dart' show promptText;
import 'package:lumora/features/video_editor/domain/caption_timeline.dart';
import 'package:lumora/features/video_editor/domain/timeline_ops.dart';
import 'package:lumora/features/video_editor/domain/video_project.dart';
import 'package:lumora/features/video_editor/engine/caption_service.dart';
import 'package:lumora/features/video_editor/presentation/caption_providers.dart';
import 'package:lumora/features/video_editor/presentation/video_editor_controller.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// The Captions tool panel (W3-M6b): generate with on-device Whisper, show
/// progress with cancel, edit the cue list, save SRT/VTT. The captions live
/// in the project as [VideoText] overlays (see caption_timeline.dart), so
/// the normal export burns them in.
class CaptionPanel extends ConsumerStatefulWidget {
  const CaptionPanel({super.key, this.onSeek});

  /// Moves the preview to a cue's start.
  final void Function(int ms)? onSeek;

  @override
  ConsumerState<CaptionPanel> createState() => _CaptionPanelState();
}

class _CaptionPanelState extends ConsumerState<CaptionPanel> {
  bool _running = false;
  bool _cancel = false;
  double _fraction = 0;
  String? _message;
  String? _language; // null = auto

  String _clock(int ms) {
    final s = ms ~/ 1000;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _generate() async {
    final l = context.l10n;
    final ctrl = ref.read(videoEditorControllerProvider.notifier);
    final s = ref.read(videoEditorControllerProvider);
    final clip = s.selectedClip ?? s.project.clips.firstOrNull;
    if (clip == null) {
      setState(() => _message = l.captionsNeedClip);
      return;
    }
    final ok = await ensureModelsDownloaded(context, ref, ModelRegistry.speech);
    if (!ok || !mounted) return;
    setState(() {
      _running = true;
      _cancel = false;
      _fraction = 0;
      _message = null;
    });
    try {
      final service = ref.read(captionServiceFactoryProvider)(_language);
      final result = await service.caption(
        clip.path,
        videoDurationMs: clip.sourceDurationMs,
        language: _language,
        onProgress: (pr) {
          if (mounted) setState(() => _fraction = pr.fraction);
        },
        isCancelled: () => _cancel,
      );
      if (!mounted) return;
      if (result.error != null) {
        setState(() => _message = l.errorGeneric('${result.error}'));
      } else if (result.cancelled && result.track.cues.isEmpty) {
        setState(() => _message = null);
      } else if (result.track.cues.isEmpty) {
        setState(() => _message = l.captionsNone);
      } else {
        // A cancelled run keeps what was transcribed so far.
        ctrl.setCaptions(clip.id, result.track);
        Haptics.medium();
      }
    } on NoAudioException {
      if (mounted) setState(() => _message = l.captionsNoAudio);
    } on Object catch (e) {
      if (mounted) setState(() => _message = l.errorGeneric('$e'));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _saveSidecars() async {
    final l = context.l10n;
    final s = ref.read(videoEditorControllerProvider);
    final track = captionTrack(s.project.texts, durationMs: s.project.totalDurationMs);
    final dir = Directory(p.join((await getTemporaryDirectory()).path, 'captions'));
    final base = p.basenameWithoutExtension(s.project.clips.firstOrNull?.path ?? 'captions');
    final files = await CaptionService(
      decodeAudio: (_) async => null,
      openTranscriber: () => throw UnsupportedError('sidecar export only'),
    ).exportSidecars(track, dir, base);
    if (!mounted) return;
    unawaited(SharePlus.instance.share(ShareParams(files: [for (final f in files) XFile(f)])));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.captionsSaved)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(videoEditorControllerProvider);
    final ctrl = ref.read(videoEditorControllerProvider.notifier);
    final cues = captionsOf(s.project.texts);

    if (_running) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(value: _fraction > 0 ? _fraction : null),
            const SizedBox(height: 10),
            Text(l.captionsProgress((_fraction * 100).round())),
            TextButton(onPressed: () => setState(() => _cancel = true), child: Text(l.cancel)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          children: [
            ChoiceChip(
              label: Text(l.captionsLanguageAuto),
              selected: _language == null,
              onSelected: (_) => setState(() => _language = null),
            ),
            ChoiceChip(
              label: const Text('العربية'),
              selected: _language == 'ar',
              onSelected: (_) => setState(() => _language = 'ar'),
            ),
            ChoiceChip(
              label: const Text('English'),
              selected: _language == 'en',
              onSelected: (_) => setState(() => _language = 'en'),
            ),
          ],
        ),
        Center(
          child: FilledButton.tonalIcon(
            icon: const Icon(Icons.closed_caption_outlined),
            label: Text(cues.isEmpty ? l.captionsGenerate : l.captionsRegenerate),
            onPressed: s.busy ? null : _generate,
          ),
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(_message!, textAlign: TextAlign.center),
          ),
        if (cues.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(l.captionsHint, style: Theme.of(context).textTheme.bodySmall),
          ),
          for (final c in cues)
            ListTile(
              dense: true,
              key: ValueKey(c.id),
              leading: Text(_clock(c.startMs)),
              title: Text(c.text),
              onTap: () async {
                widget.onSeek?.call(c.startMs);
                final t = await promptText(context, title: l.editText, initial: c.text);
                if (t != null && t.trim().isNotEmpty) ctrl.updateText(c.id, (x) => x.copyWith(text: t.trim()));
              },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PopupMenuButton<String>(
                    tooltip: l.captionsCueActions,
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (v) {
                      Haptics.selection();
                      switch (v) {
                        case 'earlier':
                          ctrl.shiftCaption(c.id, -250);
                        case 'later':
                          ctrl.shiftCaption(c.id, 250);
                        case 'split':
                          ctrl.splitCaption(c.id, (c.startMs + c.endMs) ~/ 2);
                        case 'merge':
                          ctrl.mergeCaption(c.id);
                      }
                    },
                    itemBuilder: (c2) => [
                      PopupMenuItem(value: 'earlier', child: Text(l.captionsShiftEarlier)),
                      PopupMenuItem(value: 'later', child: Text(l.captionsShiftLater)),
                      PopupMenuItem(value: 'split', child: Text(l.captionsSplit)),
                      PopupMenuItem(value: 'merge', child: Text(l.captionsMergeNext)),
                    ],
                  ),
                  IconButton(
                    tooltip: l.delete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => ctrl.removeText(c.id),
                  ),
                ],
              ),
            ),
          const Divider(),
          _CaptionStyleRow(cues: cues),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _saveSidecars,
                icon: const Icon(Icons.ios_share),
                label: Text(l.captionsExport),
              ),
              TextButton.icon(
                onPressed: ctrl.removeAllCaptions,
                icon: const Icon(Icons.layers_clear_outlined),
                label: Text(l.captionsRemoveAll),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Font size and background controls applied to every caption at once.
class _CaptionStyleRow extends ConsumerWidget {
  const _CaptionStyleRow({required this.cues});

  final List<VideoText> cues;

  static const _sizes = [0.04, 0.05, 0.06];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final ctrl = ref.read(videoEditorControllerProvider.notifier);
    final first = cues.first;
    return Column(
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(l.captionsStyle, style: Theme.of(context).textTheme.titleSmall),
        ),
        Row(
          children: [
            Text(l.captionsSize),
            const SizedBox(width: 8),
            for (final size in _sizes)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 4),
                child: ChoiceChip(
                  label: Text(['S', 'M', 'L'][_sizes.indexOf(size)]),
                  selected: (first.fontSize - size).abs() < 1e-6,
                  onSelected: (_) => ctrl.styleCaptions(fontSize: size),
                ),
              ),
            const Spacer(),
            Text(l.captionsBackground),
            Switch(
              value: first.backgroundColor != null,
              onChanged: (v) => ctrl.styleCaptions(backgroundColor: v ? 0xAA000000 : null, clearBackground: !v),
            ),
          ],
        ),
      ],
    );
  }
}
