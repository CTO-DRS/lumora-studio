import 'dart:io';

import 'package:flutter/services.dart';
import 'package:lumora/core/app_info.dart';
import 'package:lumora/core/diagnostics/crash_log.dart';
import 'package:lumora/core/diagnostics/inference_telemetry.dart';
import 'package:lumora/core/ui/ui.dart';
import 'package:lumora/core/utils/l10n_ext.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Settings › Error log ("سجل الأخطاء"): the on-device crash breadcrumbs,
/// newest at the bottom, with copy / share / clear. Nothing is uploaded.
class ErrorLogPage extends StatefulWidget {
  const ErrorLogPage({super.key});

  @override
  State<ErrorLogPage> createState() => _ErrorLogPageState();
}

class _ErrorLogPageState extends State<ErrorLogPage> {
  String? _text;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final log = CrashLog.instance;
    final device = await log.deviceSummary();
    final telemetry = InferenceTelemetry.instance.report();
    final body = '${await log.read()}${telemetry.isEmpty ? '' : '\n$telemetry'}';
    final header = 'Lumora Studio v$kAppVersion${device == null ? '' : '\n$device'}\n\n';
    if (!mounted) return;
    setState(() => _text = body.trim().isEmpty ? '' : header + body);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _copy() async {
    final text = _text;
    if (text == null || text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.copied)));
  }

  Future<void> _share() async {
    final text = _text;
    if (text == null || text.isEmpty) return;
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'lumora-error-log.txt'));
    await file.writeAsString(text);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'text/plain')]));
  }

  Future<void> _clear() async {
    await CrashLog.instance.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.errorLogCleared)));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = _text;
    final empty = text != null && text.isEmpty;
    return LumoraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: GlassAppBar(
          title: Text(l.errorLog),
          actions: [
            IconButton(tooltip: l.copy, onPressed: empty ? null : _copy, icon: const Icon(Icons.copy_all_outlined)),
            IconButton(tooltip: l.share, onPressed: empty ? null : _share, icon: const Icon(Icons.share_outlined)),
            IconButton(
              tooltip: l.clear,
              onPressed: empty ? null : _clear,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          ],
        ),
        body: text == null
            ? Center(child: CircularProgressIndicator(semanticsLabel: l.loading))
            : empty
            ? Center(child: Text(l.errorLogEmpty))
            : Directionality(
                // Stack traces are always left-to-right.
                textDirection: TextDirection.ltr,
                child: Scrollbar(
                  controller: _scroll,
                  child: SingleChildScrollView(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(
                      text,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.35),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
