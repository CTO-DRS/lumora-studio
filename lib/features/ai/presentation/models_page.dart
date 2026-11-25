import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumora/core/providers.dart';
import 'package:lumora/core/ui/ui.dart';
import 'package:lumora/core/utils/l10n_ext.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:material_ui/material_ui.dart';

/// Lists every on-device model with download / delete controls.
class ModelsPage extends ConsumerStatefulWidget {
  const ModelsPage({super.key});

  @override
  ConsumerState<ModelsPage> createState() => _ModelsPageState();
}

class _ModelsPageState extends ConsumerState<ModelsPage> {
  final Map<String, double> _progress = {};
  final Map<String, bool> _installed = {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final m = ref.read(modelManagerProvider);
    for (final spec in ModelRegistry.all) {
      _installed[spec.id] = await m.isInstalled(spec);
    }
    if (mounted) setState(() {});
  }

  Future<void> _download(ModelSpec spec) async {
    setState(() => _progress[spec.id] = 0);
    try {
      final manager = ref.read(modelManagerProvider);
      await manager.ensure(spec, onProgress: (p) => setState(() => _progress[spec.id] = p.fraction));
      // Fetch the LiteRT sibling too (same opt-in, one tap): NPU/GPU
      // acceleration then needs no second visit to this page. Progress for
      // the sibling rides the same indicator (it is the smaller file).
      final lite = spec.lite;
      if (lite != null && !await manager.isInstalled(lite)) {
        await manager.ensure(lite, onProgress: (p) => setState(() => _progress[spec.id] = 0.9 + 0.1 * p.fraction));
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.errorGeneric('$e'))));
      }
    } finally {
      _progress.remove(spec.id);
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return LumoraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: GlassAppBar(title: Text(l.aiModels)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(leading: const Icon(Icons.lock_outline), title: Text(l.modelsInfo)),
            ),
            const SizedBox(height: 8),
            for (final spec in ModelRegistry.all)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(spec.displayName, style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(
                        '${spec.sizeMb.toStringAsFixed(1)} MB · ${spec.license}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      if (_progress.containsKey(spec.id)) ...[
                        LinearProgressIndicator(value: _progress[spec.id]),
                        const SizedBox(height: 4),
                        Text(l.downloading('${((_progress[spec.id] ?? 0) * 100).round()}')),
                      ] else
                        Row(
                          children: [
                            if (_installed[spec.id] ?? false) ...[
                              Icon(Icons.check_circle, color: context.lumora.mint, size: 18),
                              const SizedBox(width: 6),
                              Text(l.installed),
                              const Spacer(),
                              TextButton(
                                onPressed: () async {
                                  await ref.read(modelManagerProvider).delete(spec);
                                  await _refresh();
                                },
                                child: Text(l.delete),
                              ),
                            ] else ...[
                              const Spacer(),
                              FilledButton.tonalIcon(
                                onPressed: () => _download(spec),
                                icon: const Icon(Icons.download),
                                label: Text(l.downloadModel),
                              ),
                            ],
                          ],
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
