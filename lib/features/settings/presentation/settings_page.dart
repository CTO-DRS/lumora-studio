import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lumora/core/providers.dart';
import 'package:lumora/core/utils/l10n_ext.dart';
import 'package:lumora/core/utils/storage.dart';
import 'package:lumora/features/photo_editor/engine/image_exporter.dart';
import 'package:lumora/features/settings/data/settings_controller.dart';
import 'package:material_ui/material_ui.dart';

const kAppVersion = '1.1.0';

final FutureProvider<(int, int)> _storageProvider = FutureProvider.autoDispose<(int, int)>((ref) async {
  final models = await ref.read(modelManagerProvider).installedBytes();
  return (models, await cacheSize());
});

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsControllerProvider);
    final c = ref.read(settingsControllerProvider.notifier);
    final storage = ref.watch(_storageProvider);
    final l = context.l10n;
    final theme = Theme.of(context);
    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
    );
    final sizes = <int?>[null, 4096, 3000, 2048, 1080];
    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        children: [
          header(l.appearance),
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
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(value: ThemeMode.system, label: Text(l.systemDefault)),
                  ButtonSegment(value: ThemeMode.dark, label: Text(l.dark)),
                  ButtonSegment(value: ThemeMode.light, label: Text(l.light)),
                ],
                selected: {s.themeMode},
                onSelectionChanged: (v) => c.setThemeMode(v.first),
              ),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.vibration),
            title: Text(l.haptics),
            value: s.haptics,
            onChanged: (v) => c.setHaptics(enabled: v),
          ),
          header(l.exportDefaults),
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
          ListTile(
            leading: const Icon(Icons.high_quality_outlined),
            title: Text('${l.quality}: ${s.exportQuality}'),
            subtitle: Slider(
              value: s.exportQuality.toDouble(),
              min: 50,
              max: 100,
              divisions: 50,
              onChanged: (v) => c.setExport(quality: v.round()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.photo_size_select_large),
            title: Text(l.exportMaxSize),
            trailing: DropdownButton<int?>(
              value: s.exportMaxDimension,
              underline: const SizedBox.shrink(),
              items: [
                for (final v in sizes) DropdownMenuItem(value: v, child: Text(v == null ? l.fullResolution : '$v px')),
              ],
              onChanged: c.setExportMaxDimension,
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.info_outline),
            title: Text(l.keepExif),
            value: s.keepExif,
            onChanged: (v) => c.setExport(keepExif: v),
          ),
          header(l.storage),
          ListTile(
            leading: const Icon(Icons.memory),
            title: Text(l.aiModels),
            subtitle: Text(storage.whenOrNull(data: (v) => formatBytes(v.$1)) ?? '…'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await context.push('/models');
              ref.invalidate(_storageProvider);
            },
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: Text(l.clearCache),
            subtitle: Text(storage.whenOrNull(data: (v) => formatBytes(v.$2)) ?? '…'),
            onTap: () async {
              final freed = await clearCache();
              ref.invalidate(_storageProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.cacheCleared(formatBytes(freed)))));
              }
            },
          ),
          header(l.about),
          ListTile(
            leading: const Icon(Icons.tips_and_updates_outlined),
            title: Text(l.showTips),
            onTap: () => context.push('/welcome'),
          ),
          AboutListTile(
            icon: const Icon(Icons.favorite_outline),
            applicationName: l.appTitle,
            applicationVersion: kAppVersion,
            aboutBoxChildren: [Text(l.aboutText)],
            child: Text('${l.about} · v$kAppVersion'),
          ),
        ],
      ),
    );
  }
}
