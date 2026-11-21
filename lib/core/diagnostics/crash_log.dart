import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// On-device error log ("سجل الأخطاء" in Settings). Nothing ever leaves the
/// device unless the user copies or shares the log.
///
/// * Dart errors are caught by [FlutterError.onError],
///   [PlatformDispatcher.onError] and the root isolate's error listener.
/// * Breadcrumbs ([breadcrumb]) are written **synchronously** and flushed,
///   so when native code kills the process the last line shows which step
///   was running.
/// * On Android, the next launch also records why the previous process
///   ended (ApplicationExitInfo, Android 11+) and any uncaught JVM
///   exception captured by `MainActivity`.
class CrashLog {
  CrashLog._();

  static final CrashLog instance = CrashLog._();

  /// The log is trimmed to its newest half when it grows beyond this.
  static const int maxBytes = 256 * 1024;

  static const _channel = MethodChannel('lumora/diagnostics');

  File? _file;
  final List<String> _pending = [];

  /// The log file (created on first use). Visible for tests.
  File? get file => _file;

  /// Directory override for tests.
  @visibleForTesting
  Future<Directory> Function() baseDir = getApplicationSupportDirectory;

  /// Opens the log file and installs the error hooks. Safe to call twice.
  Future<void> init({bool installHooks = true}) async {
    try {
      final dir = Directory(p.join((await baseDir()).path, 'logs'));
      if (!dir.existsSync()) dir.createSync(recursive: true);
      _file = File(p.join(dir.path, 'errors.log'));
      _flushPending();
    } on Object catch (e) {
      debugPrint('CrashLog: cannot open log file: $e');
    }
    if (!installHooks) return;

    final previousFlutterHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      record('FlutterError', details.exceptionAsString(), details.stack, context: details.context?.toDescription());
      previousFlutterHandler?.call(details);
    };
    final previousPlatformHandler = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      record('Uncaught', '$error', stack);
      return previousPlatformHandler?.call(error, stack) ?? true;
    };
    final port = RawReceivePort((Object? pair) {
      if (pair is List && pair.length == 2) {
        record('Isolate', '${pair[0]}', StackTrace.fromString('${pair[1]}'));
      }
    });
    Isolate.current.addErrorListener(port.sendPort);
  }

  /// Records an error with its stack trace.
  void record(String kind, String message, StackTrace? stack, {String? context}) {
    final b = StringBuffer()
      ..writeln('[${_now()}] ERROR $kind${context == null ? '' : ' ($context)'}')
      ..writeln(message.trim());
    final trace = stack?.toString().trim() ?? '';
    if (trace.isNotEmpty) {
      final lines = trace.split('\n');
      b.writeln(lines.take(40).join('\n'));
      if (lines.length > 40) b.writeln('… ${lines.length - 40} more frames');
    }
    _append(b.toString());
  }

  /// A short "what is happening now" line, flushed to disk immediately.
  void breadcrumb(String message) => _append('[${_now()}] $message\n');

  /// Appends Android's record of how the previous runs ended and any JVM
  /// crash captured natively. Each exit is logged once.
  Future<void> collectPlatformReports() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final javaCrash = await _channel.invokeMethod<String>('takeJavaCrash');
      if (javaCrash != null && javaCrash.trim().isNotEmpty) {
        _append('[${_now()}] PREVIOUS RUN: uncaught JVM exception\n${javaCrash.trim()}\n');
      }
      final seenFile = _file == null ? null : File(p.join(_file!.parent.path, 'exit_seen.txt'));
      final seen = seenFile != null && seenFile.existsSync()
          ? int.tryParse(seenFile.readAsStringSync().trim()) ?? 0
          : 0;
      final exits = await _channel.invokeListMethod<Map<Object?, Object?>>('exitReasons') ?? const [];
      var newest = seen;
      for (final e in exits.reversed) {
        final ts = (e['timestamp'] as num?)?.toInt() ?? 0;
        if (ts <= seen) continue;
        if (ts > newest) newest = ts;
        final reason = '${e['reason']}';
        // Normal exits are noise; keep crashes, ANRs and memory kills.
        if (reason.startsWith('USER_') || reason.startsWith('EXIT_SELF') || reason.startsWith('PERMISSION')) continue;
        final when = DateTime.fromMillisecondsSinceEpoch(ts).toIso8601String();
        _append(
          '[${_now()}] PREVIOUS RUN ENDED at $when: $reason status=${e['status']} '
          'importance=${e['importance']} pss=${e['pssKb']}KB rss=${e['rssKb']}KB'
          '${e['description'] == null ? '' : ' — ${e['description']}'}\n',
        );
      }
      if (newest > seen) seenFile?.writeAsStringSync('$newest');
    } on Object catch (e) {
      debugPrint('CrashLog: platform reports unavailable: $e');
    }
  }

  /// One line describing the device (model, Android version, memory).
  Future<String?> deviceSummary() async {
    if (kIsWeb || !Platform.isAndroid) return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    try {
      final m = await _channel.invokeMapMethod<String, Object?>('deviceInfo');
      if (m == null) return null;
      return '${m['manufacturer']} ${m['model']} · Android ${m['release']} (SDK ${m['sdk']}) · ${m['abis']} · '
          'RAM ${m['totalMemMb']} MB (free ${m['availMemMb']} MB) · heap ${m['largeMemoryClassMb']} MB';
    } on Object {
      return null;
    }
  }

  /// The whole log ('' when empty).
  Future<String> read() async {
    final f = _file;
    if (f == null || !f.existsSync()) return '';
    return f.readAsString();
  }

  Future<void> clear() async {
    final f = _file;
    if (f != null && f.existsSync()) await f.writeAsString('');
  }

  void _append(String text) {
    if (kDebugMode && text.contains('] ERROR')) debugPrint(text.trimRight());
    final f = _file;
    if (f == null) {
      _pending.add(text);
      if (_pending.length > 200) _pending.removeAt(0);
      return;
    }
    try {
      _trimIfNeeded(f);
      f.writeAsStringSync(text, mode: FileMode.append, flush: true);
    } on Object catch (e) {
      debugPrint('CrashLog: write failed: $e');
    }
  }

  void _flushPending() {
    if (_pending.isEmpty) return;
    final copy = List.of(_pending);
    _pending.clear();
    copy.forEach(_append);
  }

  void _trimIfNeeded(File f) {
    if (!f.existsSync() || f.lengthSync() < maxBytes) return;
    final text = f.readAsStringSync();
    final cut = text.indexOf('\n[', text.length ~/ 2);
    f.writeAsStringSync(cut < 0 ? '' : text.substring(cut + 1), flush: true);
  }

  static String _now() => DateTime.now().toIso8601String();
}
