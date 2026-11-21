import 'package:go_router/go_router.dart';
import 'package:lumora/core/ui/ui.dart';
import 'package:lumora/core/utils/l10n_ext.dart';
import 'package:lumora/features/home/presentation/launchers.dart';
import 'package:material_ui/material_ui.dart';

/// The tabbed root of the app: Home, Templates, Projects and Settings with
/// a floating glass navigation bar and a raised "Create" button.
class AppShell extends StatelessWidget {
  const AppShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return LumoraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: shell,
        bottomNavigationBar: GlassNavBar(
          selectedIndex: shell.currentIndex,
          createLabel: l.create,
          onCreate: () => showCreateSheet(context),
          onSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
          items: [
            GlassNavItem(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: l.navHome),
            GlassNavItem(
              icon: Icons.auto_awesome_mosaic_outlined,
              selectedIcon: Icons.auto_awesome_mosaic,
              label: l.navTemplates,
            ),
            GlassNavItem(icon: Icons.folder_outlined, selectedIcon: Icons.folder_rounded, label: l.navProjects),
            GlassNavItem(icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: l.settings),
          ],
        ),
      ),
    );
  }
}
