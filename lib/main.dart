import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumora/app.dart';
import 'package:lumora/core/app_info.dart';
import 'package:lumora/core/diagnostics/crash_log.dart';
import 'package:material_ui/material_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final log = CrashLog.instance;
  await log.init();
  log.breadcrumb('App start v$kAppVersion');
  runApp(const ProviderScope(child: LumoraApp()));
  // After the first frame: why did the previous run end (Android 11+)?
  unawaited(log.collectPlatformReports());
}
