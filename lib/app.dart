import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumora/core/router/app_router.dart';
import 'package:lumora/core/theme/app_theme.dart';
import 'package:lumora/features/settings/data/settings_controller.dart';
import 'package:lumora/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

class LumoraApp extends ConsumerWidget {
  const LumoraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    return MaterialApp.router(
      onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
      routerConfig: appRouter,
    );
  }
}
