import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/core/diagnostics/crash_log.dart';
import 'package:lumora/features/settings/presentation/error_log_page.dart';
import 'package:lumora/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump();
  }
}

Future<void> _pumpPage(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
      supportedLocales: AppLocalizations.supportedLocales,
      home: ErrorLogPage(),
    ),
  );
  await _settle(tester);
}

void main() {
  late Directory tmp;
  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('lumora_errlog');
    CrashLog.instance.baseDir = () async => tmp;
    await CrashLog.instance.init(installHooks: false);
    await CrashLog.instance.clear();
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  testWidgets('an empty log shows the empty message and disables the actions', (tester) async {
    await _pumpPage(tester);
    expect(find.text('No errors recorded.'), findsOneWidget);
    final copy = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.copy_all_outlined));
    expect(copy.onPressed, isNull);
  });

  testWidgets('recorded entries show under a version header, and Clear empties the log', (tester) async {
    CrashLog.instance.breadcrumb('unit-test breadcrumb');
    await _pumpPage(tester);
    final shown = tester.widget<SelectableText>(find.byType(SelectableText)).data!;
    expect(shown, startsWith('Lumora Studio v'));
    expect(shown, contains('unit-test breadcrumb'));

    await tester.tap(find.widgetWithIcon(IconButton, Icons.delete_sweep_outlined));
    await _settle(tester);
    expect(find.text('No errors recorded.'), findsOneWidget);
    expect(find.text('Error log cleared'), findsOneWidget);
    expect(await tester.runAsync(CrashLog.instance.read), isEmpty);
  });
}
