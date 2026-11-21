import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumora/core/diagnostics/crash_log.dart';
import 'package:lumora/core/providers.dart';
import 'package:lumora/core/utils/l10n_ext.dart';
import 'package:lumora/core/utils/storage.dart';
import 'package:lumora/features/ai/data/model_manager.dart';
import 'package:lumora/features/ai/data/onnx_engine.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:lumora/features/ai/presentation/ai_error_text.dart';
import 'package:lumora/features/ai/presentation/ai_tools_sheet.dart';
import 'package:material_ui/material_ui.dart';

/// Makes sure every model in [specs] is on the device before an AI tool
/// runs: asks before downloading, then shows a progress dialog. Returns true
/// when all models are installed.
Future<bool> ensureModelsDownloaded(BuildContext context, WidgetRef ref, List<ModelSpec> specs) async {
  final manager = ref.read(modelManagerProvider);
  final missing = <ModelSpec>[];
  for (final s in specs) {
    if (!await manager.isInstalled(s)) missing.add(s);
  }
  if (missing.isEmpty) return true;
  if (!context.mounted) return false;

  final l = context.l10n;
  final total = missing.fold<int>(0, (a, s) => a + s.sizeBytes);
  final names = missing.map((s) => s.displayName).join(' + ');
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: Icon(Icons.download_for_offline_outlined, color: Theme.of(context).colorScheme.primary),
      title: Text(l.modelNeededTitle),
      content: Text(l.modelNeededBody(names, formatBytes(total))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.downloadModel)),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  final progress = ref.read(modelDownloadProgressProvider.notifier);
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ModelDownloadDialog(manager: manager, specs: missing, onProgress: progress.set),
  );
  for (final s in missing) {
    progress.clear(s.id);
  }
  if (context.mounted) ref.invalidate(installedModelsProvider);
  return ok ?? false;
}

/// Downloads [specs] one after the other with a progress bar. Pops `true`
/// when done, `false` when the user closes it after an error.
class ModelDownloadDialog extends StatefulWidget {
  const ModelDownloadDialog({required this.manager, required this.specs, super.key, this.onProgress});

  final ModelManager manager;
  final List<ModelSpec> specs;

  /// Mirrors progress (model id, 0..1) to the AI tool cards.
  final void Function(String id, double fraction)? onProgress;

  @override
  State<ModelDownloadDialog> createState() => _ModelDownloadDialogState();
}

class _ModelDownloadDialogState extends State<ModelDownloadDialog> {
  int _index = 0;
  double? _fraction;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _fraction = null;
    });
    try {
      for (_index = 0; _index < widget.specs.length; _index++) {
        final spec = widget.specs[_index];
        CrashLog.instance.breadcrumb('AI: downloading ${spec.id}');
        await widget.manager.ensure(
          spec,
          onProgress: (p) {
            if (mounted) setState(() => _fraction = p.total > 0 ? p.fraction : null);
            if (p.total > 0) widget.onProgress?.call(spec.id, p.fraction);
          },
        );
        if (mounted) setState(() => _fraction = null);
      }
      if (mounted) Navigator.pop(context, true);
    } on Object catch (e, st) {
      CrashLog.instance.record('ModelDownload', describeNativeError(e), st);
      final spec = widget.specs[_index.clamp(0, widget.specs.length - 1)];
      final error = e is ModelChecksumException
          ? AiException(AiErrorKind.checksum, model: spec, detail: '$e')
          : AiException(AiErrorKind.download, model: spec, detail: describeNativeError(e));
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final spec = widget.specs[_index.clamp(0, widget.specs.length - 1)];
    final error = _error;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(l.modelDownloadingTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(spec.displayName, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            if (error == null) ...[
              LinearProgressIndicator(value: _fraction),
              const SizedBox(height: 6),
              Text(
                '${l.downloading('${((_fraction ?? 0) * 100).round()}')} · '
                '${_index + 1}/${widget.specs.length} · ${formatBytes(spec.sizeBytes)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else
              Text(aiErrorText(l, error), style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
        actions: [
          if (error != null) ...[
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.close)),
            FilledButton(onPressed: _start, child: Text(l.retry)),
          ],
        ],
      ),
    );
  }
}
