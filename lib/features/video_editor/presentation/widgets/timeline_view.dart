import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumora/features/video_editor/domain/audio_analysis.dart';
import 'package:lumora/features/video_editor/domain/timeline_ops.dart';
import 'package:lumora/features/video_editor/domain/video_project.dart';
import 'package:lumora/features/video_editor/presentation/video_editor_controller.dart';
import 'package:material_ui/material_ui.dart';

/// Horizontally scrolling multi-track timeline: clips (with filmstrip
/// thumbnails and transition markers), text track and music track, with a
/// fixed centre playhead – scrolling scrubs.
class TimelineView extends ConsumerStatefulWidget {
  const TimelineView({required this.onScrub, super.key});

  final ValueChanged<int> onScrub;

  @override
  ConsumerState<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends ConsumerState<TimelineView> {
  final _scroll = ScrollController();
  double _pxPerSecond = 60;
  bool _userScrolling = false;
  double _scaleStart = 60;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  double _msToPx(int ms) => ms / 1000 * _pxPerSecond;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(videoEditorControllerProvider);
    final ctrl = ref.read(videoEditorControllerProvider.notifier);
    final project = s.project;
    final scheme = Theme.of(context).colorScheme;
    final musicWave = project.music == null ? null : s.audio[project.music!.path]?.waveform;

    // Follow the playhead while playing.
    if (!_userScrolling && _scroll.hasClients) {
      final target = _msToPx(s.playheadMs);
      if ((_scroll.offset - target).abs() > 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) _scroll.jumpTo(target.clamp(0, _scroll.position.maxScrollExtent));
        });
      }
    }

    return LayoutBuilder(
      builder: (context, c) {
        final half = c.maxWidth / 2;
        final starts = project.clipStarts;
        final totalPx = _msToPx(project.totalDurationMs);
        return GestureDetector(
          onScaleStart: (_) => _scaleStart = _pxPerSecond,
          onScaleUpdate: (d) {
            if (d.pointerCount > 1) setState(() => _pxPerSecond = (_scaleStart * d.scale).clamp(10, 400));
          },
          child: Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n is ScrollStartNotification && n.dragDetails != null) _userScrolling = true;
                  if (n is ScrollUpdateNotification && _userScrolling) {
                    final ms = (_scroll.offset / _pxPerSecond * 1000).round();
                    ctrl.seek(ms);
                    widget.onScrub(ms);
                  }
                  if (n is ScrollEndNotification) _userScrolling = false;
                  return false;
                },
                child: SingleChildScrollView(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: half),
                    child: SizedBox(
                      width: totalPx,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 64,
                            child: Stack(
                              children: [
                                for (var i = 0; i < project.clips.length; i++)
                                  Positioned(
                                    left: _msToPx(starts[i]),
                                    width: _msToPx(project.clips[i].durationMs),
                                    top: 0,
                                    bottom: 0,
                                    child: _ClipTile(
                                      clip: project.clips[i],
                                      selected: project.clips[i].id == s.selectedClipId,
                                      thumbs: s.thumbnails[project.clips[i].path] ?? const [],
                                      waveform: s.audio[project.clips[i].path]?.waveform,
                                      pxPerSecond: _pxPerSecond,
                                      onTap: () => ctrl.select(project.clips[i].id),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (s.snapToBeats && project.clips.isNotEmpty) ...[
                            SizedBox(
                              height: 12,
                              width: totalPx,
                              child: Stack(
                                children: [
                                  for (var i = 0; i < project.clips.length; i++)
                                    for (final beat in s.audio[project.clips[i].path]?.beats.beatMs ?? const <int>[])
                                      Positioned(
                                        left: _msToPx(starts[i] + (beat / project.clips[i].speed).round()) - 2,
                                        top: 2,
                                        bottom: 2,
                                        width: 4,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: scheme.primary.withValues(alpha: 0.85),
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                      ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                          ],
                          SizedBox(
                            height: 26,
                            child: Stack(
                              children: [
                                for (final t in project.texts)
                                  Positioned(
                                    left: _msToPx(t.startMs),
                                    width: _msToPx(t.endMs - t.startMs).clamp(8, double.infinity),
                                    top: 0,
                                    bottom: 0,
                                    child: GestureDetector(
                                      onTap: () => ctrl.selectText(t.id),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                        decoration: BoxDecoration(
                                          color: t.id == s.selectedTextId
                                              ? scheme.secondary
                                              : scheme.secondary.withValues(alpha: 0.45),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        alignment: AlignmentDirectional.centerStart,
                                        child: Text(
                                          t.text,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (project.music != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              height: 22,
                              width: totalPx,
                              decoration: BoxDecoration(
                                color: Colors.teal.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              alignment: AlignmentDirectional.centerStart,
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: musicWave == null
                                  ? const Row(
                                      children: [
                                        Icon(Icons.music_note, size: 14),
                                        SizedBox(width: 4),
                                        Icon(Icons.graphic_eq, size: 14),
                                      ],
                                    )
                                  : CustomPaint(
                                      painter: _WaveformPainter(
                                        musicWave.peaks,
                                        musicWave.bucketMs,
                                        Colors.white70,
                                        pxPerSecond: _pxPerSecond,
                                        loop: true,
                                      ),
                                    ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: half - 1,
                top: 0,
                bottom: 0,
                child: Container(width: 2, color: scheme.primary),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ClipTile extends StatelessWidget {
  const _ClipTile({
    required this.clip,
    required this.selected,
    required this.thumbs,
    required this.onTap,
    this.waveform,
    this.pxPerSecond = 60,
  });

  final VideoClip clip;
  final bool selected;
  final List<String> thumbs;
  final VoidCallback onTap;

  /// Level buckets of this clip's source audio (null while analysing or
  /// when the clip has no audio).
  final AudioWaveform? waveform;
  final double pxPerSecond;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wave = waveform;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? scheme.primary : Colors.transparent, width: 2),
          color: scheme.surfaceContainerHigh,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumbs.isNotEmpty)
              Row(
                children: [
                  for (final t in thumbs)
                    Expanded(child: Image.file(File(t), fit: BoxFit.cover, gaplessPlayback: true)),
                ],
              ),
            if (wave != null && clip.hasAudio)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 18,
                child: CustomPaint(
                  painter: _WaveformPainter(
                    wave.peaks,
                    wave.bucketMs,
                    Colors.white.withValues(alpha: 0.85),
                    pxPerSecond: pxPerSecond,
                  ),
                ),
              ),
            PositionedDirectional(
              start: 4,
              bottom: wave != null && clip.hasAudio ? 20 : 2,
              child: Text(
                [
                  if (clip.speed != 1) '${clip.speed}×',
                  if (clip.reversed) '⟲',
                  if (clip.transitionOut != TransitionKind.none) '⧉',
                ].join(' '),
                style: const TextStyle(fontSize: 11, color: Colors.white, shadows: [Shadow(blurRadius: 3)]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws vertical bars from waveform level buckets. [pxPerSecond] is the
/// timeline zoom; when [loop] is set (music track) buckets wrap around the
/// waveform duration, because the track repeats to fill the timeline.
class _WaveformPainter extends CustomPainter {
  _WaveformPainter(this.peaks, this.bucketMs, this.color, {this.pxPerSecond = 60, this.loop = false});

  final List<double> peaks;
  final int bucketMs;
  final Color color;
  final double pxPerSecond;
  final bool loop;

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty) return;
    final msPerPx = 1000 / pxPerSecond;
    final span = peaks.length * bucketMs;
    final paint = Paint()..color = color;
    const barWidth = 2.0;
    const gap = 1.0;
    for (var x = 0.0; x < size.width; x += barWidth + gap) {
      var ms = x * msPerPx;
      if (loop && span > 0) ms %= span;
      final i = (ms ~/ bucketMs).clamp(0, peaks.length - 1);
      final level = peaks[i].clamp(0.05, 1.0);
      final h = level * size.height;
      canvas.drawRect(Rect.fromLTWH(x, (size.height - h) / 2, barWidth, h), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) =>
      old.peaks != peaks || old.color != color || old.pxPerSecond != pxPerSecond;
}
