import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumora/core/ui/ui.dart';
import 'package:lumora/core/utils/haptics.dart';
import 'package:lumora/core/utils/l10n_ext.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:lumora/features/ai/presentation/model_download_dialog.dart';
import 'package:lumora/features/photo_editor/engine/preset_thumbnails.dart';
import 'package:lumora/features/photo_editor/presentation/photo_editor_controller.dart';
import 'package:lumora/features/photo_editor/presentation/widgets/presets_panel.dart';
import 'package:lumora/features/smart_edit/data/command_store.dart';
import 'package:lumora/features/smart_edit/domain/next_commands.dart';
import 'package:lumora/features/smart_edit/presentation/smart_actions.dart';
import 'package:material_ui/material_ui.dart';

/// "Smart" tab of the photo editor: a command bar that understands Arabic
/// and English instructions on the device, example commands, recent and
/// starred commands, and one-tap fixes suggested for this photo (live
/// thumbnails rendered by the real pipeline).
class SmartPanel extends ConsumerStatefulWidget {
  const SmartPanel({super.key});

  @override
  ConsumerState<SmartPanel> createState() => _SmartPanelState();
}

class _SmartPanelState extends ConsumerState<SmartPanel> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();
  late final PresetThumbnailCache _cache;
  bool _running = false;
  List<String> _next = const [];

  @override
  void initState() {
    super.initState();
    _cache = ref.read(presetThumbnailCacheProvider)..addListener(_onThumbs);
  }

  void _onThumbs() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cache.removeListener(_onThumbs);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit([String? command]) async {
    final text = (command ?? _text.text).trim();
    if (text.isEmpty || _running) return;
    Haptics.selection();
    _focus.unfocus();
    setState(() => _running = true);
    try {
      final plan = await runSmartCommand(context, ref, text);
      if (plan.isEmpty) return;
      ref.read(commandMemoryProvider).value?.record(text);
      ref.invalidate(commandMemoryProvider);
      if (mounted) {
        setState(() {
          _next = plan.unrecognized.isEmpty
              ? nextCommands(lang: Localizations.localeOf(context).languageCode, plan: plan)
              : const [];
        });
        if (plan.unrecognized.isEmpty) _text.clear();
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  void _toggleStar(String command) {
    Haptics.selection();
    ref.read(commandMemoryProvider).value?.toggleFavourite(command);
    ref.invalidate(commandMemoryProvider);
  }

  /// A row of command chips: tap runs the command, long press stars it.
  Widget _chips(List<String> commands, {required bool starred, required bool busy, Key? key}) => SizedBox(
    height: 42,
    child: ListView(
      key: key,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      children: [
        for (final c in commands)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 6),
            child: GestureDetector(
              onLongPress: () => _toggleStar(c),
              child: ActionChip(
                visualDensity: VisualDensity.compact,
                avatar: starred ? const Icon(Icons.star_rounded, size: 15) : null,
                label: Text(c),
                onPressed: busy ? null : () => _submit(c),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _rowLabel(IconData icon, String label, ThemeData theme) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 0),
    child: Row(
      children: [
        Icon(icon, size: 15, color: context.lumora.violet),
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.labelLarge),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(photoEditorControllerProvider);
    final ctrl = ref.read(photoEditorControllerProvider.notifier);
    final cache = ref.watch(presetThumbnailCacheProvider);
    final l = context.l10n;
    final t = context.lumora;
    final theme = Theme.of(context);
    cache.update(preview: s.preview, base: ctrl.adjustmentsWithoutPreset(s.edit), geometry: s.edit.geometry);
    final examples = [l.smartEx1, l.smartEx2, l.smartEx3, l.smartEx4, l.smartEx5, l.smartEx6];
    final memory = ref.watch(commandMemoryProvider).value;
    final favourites = memory?.favourites() ?? const <String>[];
    final history = memory?.history() ?? const <String>[];

    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GlassContainer(
            radius: 22,
            fill: t.glassFill,
            padding: const EdgeInsetsDirectional.fromSTEB(14, 2, 4, 2),
            child: Row(
              children: [
                Icon(Icons.tips_and_updates_outlined, size: 20, color: t.violet),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const ValueKey('smart-command'),
                    controller: _text,
                    focusNode: _focus,
                    enabled: !s.busy,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _submit,
                    decoration: InputDecoration(
                      hintText: l.smartHint,
                      hintMaxLines: 1,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('smart-send'),
                  tooltip: l.apply,
                  onPressed: s.busy || _running ? null : _submit,
                  icon: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: t.primaryGradient),
                    ),
                    child: _running
                        ? const Padding(
                            padding: EdgeInsets.all(9),
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_next.isNotEmpty) ...[
          _rowLabel(Icons.bolt_rounded, l.smartNext, theme),
          _chips(_next, key: const ValueKey('smart-next'), starred: false, busy: s.busy || _running),
        ],
        if (favourites.isNotEmpty) ...[
          _rowLabel(Icons.star_rounded, l.smartSaved, theme),
          _chips(favourites, key: const ValueKey('smart-favourites'), starred: true, busy: s.busy || _running),
        ],
        if (history.isNotEmpty) ...[
          _rowLabel(Icons.history_rounded, l.smartRecent, theme),
          _chips(history, key: const ValueKey('smart-history'), starred: false, busy: s.busy || _running),
        ],
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            children: [
              for (final e in examples)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: ActionChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(e),
                    onPressed: s.busy ? null : () => _submit(e),
                  ),
                ),
            ],
          ),
        ),
        if (s.suggestions.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 15, color: t.violet),
                const SizedBox(width: 6),
                Text(l.smartSuggestions, style: theme.textTheme.labelLarge),
              ],
            ),
          ),
          SizedBox(
            height: 96,
            child: ListView(
              key: const ValueKey('smart-suggestions'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final sg in s.suggestions)
                  PresetTile(
                    label: suggestionLabel(l, sg.kind),
                    image: cache.thumbnail(sg.preset),
                    fallback: presetSwatch(sg.preset),
                    selected: false,
                    onTap: s.busy
                        ? () {}
                        : () {
                            Haptics.selection();
                            ctrl.applySuggestion(sg);
                          },
                  ),
              ],
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: 13, color: t.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(l.smartOnDevice, style: theme.textTheme.bodySmall?.copyWith(color: t.textMuted)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tap-to-select controls (shown in the AI tab while selecting): prompt
/// mode (tap / box / refine brush), the decoder's three candidates, soft
/// edges, and what to do with the selection.
class SelectionPanel extends ConsumerWidget {
  const SelectionPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(photoEditorControllerProvider);
    final ctrl = ref.read(photoEditorControllerProvider.notifier);
    final l = context.l10n;
    final t = context.lumora;
    final theme = Theme.of(context);
    final ready = s.hasSelection && !s.busy;

    Future<void> erase() async {
      if (!await ensureModelsDownloaded(context, ref, aiToolModels(AiTool.eraser))) return;
      await ctrl.applySelection(SelectionAction.erase);
    }

    Widget action(IconData icon, Color color, String label, VoidCallback? onTap, {Key? key}) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: PressScale(
          enabled: onTap != null,
          child: GestureDetector(
            key: key,
            onTap: onTap,
            child: Opacity(
              opacity: onTap == null ? 0.45 : 1,
              child: GlassContainer(
                radius: 18,
                fill: t.glassFill,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: color, size: 22),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final hint = switch (s.selectMode) {
      SelectMode.box => l.selectHintBox,
      SelectMode.brush => l.selectHintBrush,
      SelectMode.point => s.selectPoints.isNotEmpty && !s.hasSelection ? l.selectNone : l.selectHint,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      children: [
        SegmentedButton<SelectMode>(
          segments: [
            ButtonSegment(
              value: SelectMode.point,
              label: Text(l.selectModeTap),
              icon: const Icon(Icons.touch_app_outlined),
            ),
            ButtonSegment(
              value: SelectMode.box,
              label: Text(l.selectModeBox),
              icon: const Icon(Icons.crop_free_rounded),
            ),
            ButtonSegment(
              value: SelectMode.brush,
              label: Text(l.selectModeBrush),
              icon: const Icon(Icons.brush_outlined),
            ),
          ],
          selected: {s.selectMode},
          onSelectionChanged: (v) => ctrl.setSelectMode(v.first),
        ),
        const SizedBox(height: 8),
        Text(hint, style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: true, label: Text(l.selectAdd), icon: const Icon(Icons.add_circle_outline)),
                  ButtonSegment(
                    value: false,
                    label: Text(l.selectSubtract),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                ],
                selected: {s.selectAdd},
                onSelectionChanged: (v) => ctrl.setSelectAdd(value: v.first),
              ),
            ),
            IconButton(
              tooltip: l.selectUndoPoint,
              onPressed: s.selectPoints.isEmpty || s.busy ? null : ctrl.undoSelectPoint,
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              tooltip: l.cancel,
              onPressed: s.busy ? null : ctrl.cancelSelection,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        if (s.selectCandidates != null && s.selectCandidates!.count > 1) ...[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 10, 4, 4),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_mosaic, size: 15, color: t.violet),
                const SizedBox(width: 6),
                Text(l.selectCandidates, style: theme.textTheme.labelLarge),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              key: const ValueKey('select-candidates'),
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < s.selectCandidates!.count; i++)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: ChoiceChip(
                      key: ValueKey('select-candidate-$i'),
                      visualDensity: VisualDensity.compact,
                      selected: s.selectChosen == i,
                      label: Text(
                        '${i + 1} · ${(s.selectCandidates!.scores[i] * 100).round()}%',
                        textDirection: TextDirection.ltr,
                      ),
                      onSelected: (_) => ctrl.pickCandidate(i),
                    ),
                  ),
              ],
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 4, 0),
          child: Row(
            children: [
              Icon(Icons.border_style_outlined, size: 15, color: t.textMuted),
              const SizedBox(width: 6),
              Text(l.selectSoftEdges, style: theme.textTheme.labelMedium),
              Expanded(
                child: Slider(value: s.selectFeather, min: 0, max: 1, onChanged: s.busy ? null : ctrl.setSelectFeather),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            action(
              Icons.cleaning_services_outlined,
              t.mint,
              l.selectErase,
              ready ? erase : null,
              key: const ValueKey('select-erase'),
            ),
            action(
              Icons.content_cut,
              t.violet,
              l.selectCutOut,
              ready ? () => ctrl.applySelection(SelectionAction.cutOut) : null,
            ),
            action(
              Icons.tune,
              t.blue,
              l.selectAdjust,
              ready ? () => ctrl.applySelection(SelectionAction.adjust) : null,
            ),
            action(
              Icons.blur_on,
              t.teal,
              l.selectBlurRest,
              ready ? () => ctrl.applySelection(SelectionAction.blurBackground) : null,
            ),
          ],
        ),
      ],
    );
  }
}
