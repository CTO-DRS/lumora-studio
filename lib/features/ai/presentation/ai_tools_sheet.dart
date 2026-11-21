import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumora/core/providers.dart';
import 'package:lumora/core/ui/ui.dart';
import 'package:lumora/core/utils/haptics.dart';
import 'package:lumora/core/utils/l10n_ext.dart';
import 'package:lumora/core/utils/storage.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:material_ui/material_ui.dart';

/// Ids of the models that are fully downloaded. Invalidated after every
/// download so AI cards drop their "download" ring.
final FutureProvider<Set<String>> installedModelsProvider = FutureProvider.autoDispose<Set<String>>((ref) async {
  final manager = ref.watch(modelManagerProvider);
  return {
    for (final spec in ModelRegistry.all)
      if (await manager.isInstalled(spec)) spec.id,
  };
});

/// Live download progress (0..1) by model id while a download runs.
final NotifierProvider<ModelDownloadProgress, Map<String, double>> modelDownloadProgressProvider =
    NotifierProvider<ModelDownloadProgress, Map<String, double>>(ModelDownloadProgress.new);

class ModelDownloadProgress extends Notifier<Map<String, double>> {
  @override
  Map<String, double> build() => const {};

  void set(String id, double fraction) => state = {...state, id: fraction};

  void clear(String id) => state = {...state}..remove(id);
}

/// One card of the AI tools grid.
class AiToolCard {
  const AiToolCard({required this.icon, required this.color, required this.label, required this.onTap, this.tool});

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  /// The model-backed tool (shows the download size and a progress ring
  /// while its models are not on the device).
  final AiTool? tool;
}

/// Header ("AI tools" + "Runs on your device") used by the sheet and the
/// editor's AI panel.
class AiToolsHeader extends StatelessWidget {
  const AiToolsHeader({super.key, this.compact = false});

  /// Smaller title for the editor panel.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final style = (compact ? Theme.of(context).textTheme.titleMedium : Theme.of(context).textTheme.titleLarge)
        ?.copyWith(fontWeight: FontWeight.w700);
    return Row(
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(l.aiToolsTitle, maxLines: 1, style: style),
          ),
        ),
        const SizedBox(width: 8),
        GlassChip(icon: Icons.lock_outline, label: l.onDevice),
      ],
    );
  }
}

/// Two-column grid of frosted AI tool cards.
class AiToolsGrid extends ConsumerWidget {
  const AiToolsGrid({required this.cards, super.key, this.enabled = true, this.shrinkWrap = false, this.padding});

  final List<AiToolCard> cards;
  final bool enabled;
  final bool shrinkWrap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final installed = ref.watch(installedModelsProvider).value;
    final progress = ref.watch(modelDownloadProgressProvider);
    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: padding ?? EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 72,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: cards.length,
      itemBuilder: (context, i) {
        final card = cards[i];
        final models = card.tool == null ? const <ModelSpec>[] : aiToolModels(card.tool!);
        // While the installed set is loading, assume installed (no flicker).
        final missing = installed == null
            ? const <ModelSpec>[]
            : models.where((m) => !installed.contains(m.id)).toList();
        final fractions = [for (final m in missing) progress[m.id]].whereType<double>();
        return _AiCard(
          card: card,
          enabled: enabled,
          downloadBytes: missing.isEmpty ? null : missing.fold<int>(0, (a, m) => a + m.sizeBytes),
          progress: fractions.isEmpty ? null : fractions.reduce((a, b) => a + b) / missing.length,
        );
      },
    );
  }
}

class _AiCard extends StatelessWidget {
  const _AiCard({required this.card, required this.enabled, this.downloadBytes, this.progress});

  final AiToolCard card;
  final bool enabled;
  final int? downloadBytes;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final t = context.lumora;
    final theme = Theme.of(context);
    final l = context.l10n;
    final size = downloadBytes == null ? null : formatBytes(downloadBytes!);
    return Semantics(
      button: true,
      enabled: enabled,
      label: size == null ? card.label : '${card.label}. ${l.modelNotInstalled(size)}',
      excludeSemantics: true,
      child: PressScale(
        enabled: enabled,
        child: GlassContainer(
          radius: 22,
          gradient: LinearGradient(
            begin: AlignmentDirectional.centerStart.resolve(Directionality.of(context)),
            end: AlignmentDirectional.centerEnd.resolve(Directionality.of(context)),
            colors: [
              card.color.withValues(alpha: t.isDark ? 0.16 : 0.12),
              t.glassFill,
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: enabled
                  ? () {
                      Haptics.selection();
                      card.onTap();
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 10, 8),
                child: Row(
                  children: [
                    GlowIconOrb(icon: card.icon, color: card.color, size: 42),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        card.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (size != null) ...[
                      const SizedBox(width: 6),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox.square(
                            dimension: 22,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: progress ?? 0,
                                  strokeWidth: 2.5,
                                  backgroundColor: t.trackInactive,
                                  color: theme.colorScheme.primary,
                                ),
                                if (progress == null) Icon(Icons.arrow_downward_rounded, size: 12, color: t.textMuted),
                              ],
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            size,
                            textDirection: TextDirection.ltr,
                            style: theme.textTheme.labelSmall?.copyWith(color: t.textMuted, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the frosted "AI tools" bottom sheet. Returns after the sheet is
/// closed; the tapped card's action runs once the sheet is gone.
Future<void> showAiToolsSheet(BuildContext context, List<AiToolCard> cards) async {
  VoidCallback? chosen;
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AiToolsHeader(),
            const SizedBox(height: 14),
            AiToolsGrid(
              shrinkWrap: true,
              cards: [
                for (final card in cards)
                  AiToolCard(
                    icon: card.icon,
                    color: card.color,
                    label: card.label,
                    tool: card.tool,
                    onTap: () {
                      chosen = card.onTap;
                      Navigator.pop(c);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  chosen?.call();
}
