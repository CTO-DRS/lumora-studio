import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lumora/core/router/app_router.dart';
import 'package:lumora/core/theme/app_theme.dart';
import 'package:lumora/features/settings/data/settings_controller.dart';
import 'package:lumora/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

class LumoraApp extends ConsumerStatefulWidget {
  const LumoraApp({super.key, this.initialLocation = '/'});

  /// Start location (tests and deep links).
  final String initialLocation;

  @override
  ConsumerState<LumoraApp> createState() => _LumoraAppState();
}

class _LumoraAppState extends ConsumerState<LumoraApp> {
  late final GoRouter _router = createAppRouter(initialLocation: widget.initialLocation);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      routerConfig: _router,
    );
  }
}
