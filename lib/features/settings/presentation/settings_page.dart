import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumora/core/utils/l10n_ext.dart';
import 'package:lumora/features/photo_editor/engine/image_exporter.dart';
import 'package:lumora/features/settings/data/settings_controller.dart';
import 'package:material_ui/material_ui.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsControllerProvider);
    final c = ref.read(settingsControllerProvider.notifier);
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l.language),
            trailing: DropdownButton<String>(
              value: s.locale?.languageCode ?? 'system',
              underline: const SizedBox.shrink(),
              items: [
                DropdownMenuItem(value: 'system', child: Text(l.systemDefault)),
                const DropdownMenuItem(value: 'en', child: Text('English')),
                const DropdownMenuItem(value: 'ar', child: Text('العربية')),
              ],
              onChanged: (v) => c.setLocale(v == null || v == 'system' ? null : Locale(v)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: Text(l.theme),
            trailing: SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(value: ThemeMode.dark, label: Text(l.dark)),
                ButtonSegment(value: ThemeMode.light, label: Text(l.light)),
              ],
              selected: {if (s.themeMode == ThemeMode.system) ThemeMode.dark else s.themeMode},
              onSelectionChanged: (v) => c.setThemeMode(v.first),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: Text(l.exportFormat),
            trailing: DropdownButton<ExportFormat>(
              value: s.exportFormat,
              underline: const SizedBox.shrink(),
              items: [
                for (final f in ExportFormat.values) DropdownMenuItem(value: f, child: Text(f.extension.toUpperCase())),
              ],
              onChanged: (v) => c.setExport(format: v),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.info_outline),
            title: Text(l.keepExif),
            value: s.keepExif,
            onChanged: (v) => c.setExport(keepExif: v),
          ),
          const Divider(),
          AboutListTile(
            icon: const Icon(Icons.favorite_outline),
            applicationName: l.appTitle,
            applicationVersion: '0.1.0',
            aboutBoxChildren: [Text(l.aboutText)],
            child: Text(l.about),
          ),
        ],
      ),
    );
  }
}
