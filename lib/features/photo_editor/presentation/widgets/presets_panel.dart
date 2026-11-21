import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumora/core/providers.dart';
import 'package:lumora/core/ui/ui.dart';
import 'package:lumora/core/utils/haptics.dart';
import 'package:lumora/core/utils/l10n_ext.dart';
import 'package:lumora/core/widgets/labeled_slider.dart';
import 'package:lumora/features/photo_editor/data/preset_store.dart';
import 'package:lumora/features/photo_editor/domain/presets.dart';
import 'package:lumora/features/photo_editor/engine/photo_renderer.dart';
import 'package:lumora/features/photo_editor/engine/preset_thumbnails.dart';
import 'package:lumora/features/photo_editor/presentation/photo_editor_controller.dart';
import 'package:lumora/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Thumbnail cache that lives as long as the photo editor page watches it.
final Provider<PresetThumbnailCache> presetThumbnailCacheProvider = Provider.autoDispose<PresetThumbnailCache>((ref) {
  final cache = PresetThumbnailCache(() async {
    final shaders = await ref.read(shaderLibraryProvider.future);
    return PhotoRenderer(shaders, ref.read(lutRepositoryProvider));
  });
  ref.onDispose(cache.dispose);
  return cache;
});

/// Category shown in the presets row (`null` = favourites). Kept while the
/// app runs so switching tools does not lose the user's place.
final NotifierProvider<PresetCategoryNotifier, PresetCategory?> presetCategoryProvider =
    NotifierProvider<PresetCategoryNotifier, PresetCategory?>(PresetCategoryNotifier.new);

class PresetCategoryNotifier extends Notifier<PresetCategory?> {
  @override
  PresetCategory? build() => PresetCategory.essentials;

  // A method (not a setter) reads better at call sites in widgets.
  // ignore: use_setters_to_change_properties
  void select(PresetCategory? c) => state = c;
}

String presetCategoryLabel(AppLocalizations l, PresetCategory? c) => switch (c) {
  null => l.catFavorites,
  PresetCategory.essentials => l.catEssentials,
  PresetCategory.portrait => l.catPortrait,
  PresetCategory.food => l.catFood,
  PresetCategory.film => l.catFilm,
  PresetCategory.vintage => l.catVintage,
  PresetCategory.cinematic => l.catCinematic,
  PresetCategory.landscape => l.catLandscape,
  PresetCategory.bw => l.catBw,
  PresetCategory.creative => l.catCreative,
  PresetCategory.custom => l.catCustom,
};

class PresetsPanel extends ConsumerStatefulWidget {
  const PresetsPanel({super.key});

  @override
  ConsumerState<PresetsPanel> createState() => _PresetsPanelState();
}

class _PresetsPanelState extends ConsumerState<PresetsPanel> {
  late final PresetThumbnailCache _cache;

  @override
  void initState() {
    super.initState();
    _cache = ref.read(presetThumbnailCacheProvider)..addListener(_onThumbs);
  }

  void _onThumbs() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cache.removeListener(_onThumbs);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(photoEditorControllerProvider);
    final ctrl = ref.read(photoEditorControllerProvider.notifier);
    final lib = ref.watch(presetLibraryControllerProvider);
    final category = ref.watch(presetCategoryProvider);
    final cache = ref.watch(presetThumbnailCacheProvider);
    final l = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;

    cache.update(preview: s.preview, base: ctrl.adjustmentsWithoutPreset(s.edit), geometry: s.edit.geometry);
    final presets = lib.presetsFor(category);
    final categories = <PresetCategory?>[
      null,
      PresetCategory.custom,
      ...PresetCategory.values.where((c) => c != PresetCategory.custom),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          child: s.edit.presetId == null
              ? const SizedBox(width: double.infinity)
              : LabeledSlider(
                  label: l.intensity,
                  value: s.edit.presetIntensity,
                  min: 0,
                  max: 1,
                  onChanged: (v) => ctrl.applyPreset(s.edit.presetId, intensity: v, live: true),
                  onChangeEnd: (_) => ctrl.commit(),
                ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final c in categories)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    avatar: c == null ? const Icon(Icons.star_rounded, size: 16) : null,
                    label: Text(presetCategoryLabel(l, c)),
                    selected: c == category,
                    onSelected: (_) {
                      Haptics.selection();
                      ref.read(presetCategoryProvider.notifier).select(c);
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              PresetTile(
                label: l.none,
                image: cache.thumbnail(null),
                selected: s.edit.presetId == null,
                onTap: () => ctrl.applyPreset(null),
              ),
              if (category == PresetCategory.custom)
                _ActionTile(icon: Icons.add, label: l.savePreset, onTap: () => savePresetDialog(context, ref)),
              if (category == PresetCategory.custom)
                _ActionTile(
                  icon: Icons.file_open_outlined,
                  label: l.importPresets,
                  onTap: () => importPresets(context, ref),
                ),
              for (final preset in presets)
                PresetTile(
                  label: preset.name(lang),
                  image: cache.thumbnail(preset),
                  fallback: presetSwatch(preset),
                  selected: s.edit.presetId == preset.id,
                  favorite: lib.isFavorite(preset.id),
                  onTap: () {
                    Haptics.selection();
                    ctrl.applyPreset(preset.id);
                  },
                  onLongPress: () => _presetMenu(context, preset),
                ),
              if (presets.isEmpty && category != PresetCategory.custom)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(l.noFavorites, style: Theme.of(context).textTheme.bodySmall),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _presetMenu(BuildContext context, Preset preset) async {
    Haptics.medium();
    final l = context.l10n;
    final libCtrl = ref.read(presetLibraryControllerProvider.notifier);
    final fav = ref.read(presetLibraryControllerProvider).isFavorite(preset.id);
    final lang = Localizations.localeOf(context).languageCode;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(preset.name(lang), style: Theme.of(c).textTheme.titleMedium)),
            ListTile(
              leading: Icon(fav ? Icons.star_rounded : Icons.star_outline_rounded),
              title: Text(fav ? l.unfavorite : l.favorite),
              onTap: () => Navigator.pop(c, 'fav'),
            ),
            if (preset.isCustom) ...[
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline),
                title: Text(l.rename),
                onTap: () => Navigator.pop(c, 'rename'),
              ),
              ListTile(
                leading: const Icon(Icons.ios_share),
                title: Text(l.exportPresets),
                onTap: () => Navigator.pop(c, 'export'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(l.delete),
                onTap: () => Navigator.pop(c, 'delete'),
              ),
            ],
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case 'fav':
        await libCtrl.toggleFavorite(preset.id);
      case 'rename':
        final name = await promptName(context, title: l.rename, initial: preset.nameEn);
        if (name != null) await libCtrl.rename(preset.id, name);
      case 'export':
        await sharePresets(context, ref, ids: [preset.id]);
      case 'delete':
        await libCtrl.delete(preset.id);
    }
  }
}

/// Asks for a short name; returns null when cancelled or empty.
Future<String?> promptName(BuildContext context, {required String title, String initial = ''}) async {
  final controller = TextEditingController(text: initial);
  final l = context.l10n;
  final result = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 40,
        textInputAction: TextInputAction.done,
        onSubmitted: (v) => Navigator.pop(c, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.pop(c, controller.text), child: Text(l.done)),
      ],
    ),
  );
  controller.dispose();
  final name = result?.trim();
  return name == null || name.isEmpty ? null : name;
}

Future<void> savePresetDialog(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final name = await promptName(context, title: l.savePreset, initial: l.presetDefaultName);
  if (name == null || !context.mounted) return;
  await ref.read(photoEditorControllerProvider.notifier).saveCurrentAsPreset(name);
  ref.read(presetCategoryProvider.notifier).select(PresetCategory.custom);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.presetSaved(name))));
  }
}

Future<void> importPresets(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final file = await FilePicker.pickFile();
  final path = file?.path;
  if (path == null) return;
  try {
    final bytes = await File(path).readAsBytes();
    final count = await ref.read(presetLibraryControllerProvider.notifier).importFile(utf8.decode(bytes));
    ref.read(presetCategoryProvider.notifier).select(PresetCategory.custom);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.presetsImported(count))));
    }
  } on Object catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.importFailed('$e'))));
    }
  }
}

Future<void> sharePresets(BuildContext context, WidgetRef ref, {Iterable<String>? ids}) async {
  final lib = ref.read(presetLibraryControllerProvider);
  if (lib.custom.isEmpty) return;
  final doc = ref.read(presetLibraryControllerProvider.notifier).exportFile(ids);
  final dir = await getTemporaryDirectory();
  final file = File(p.join(dir.path, 'lumora-presets-${DateTime.now().millisecondsSinceEpoch}.json'));
  await file.writeAsString(doc);
  await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'application/json')]));
}

/// Copies the preset document to the clipboard (fallback when sharing is
/// not available).
Future<void> copyPresetsToClipboard(WidgetRef ref) =>
    Clipboard.setData(ClipboardData(text: ref.read(presetLibraryControllerProvider.notifier).exportFile()));

class PresetTile extends StatelessWidget {
  const PresetTile({
    required this.label,
    super.key,
    required this.image,
    required this.selected,
    required this.onTap,
    this.fallback = const [Color(0xFF2A2A33), Color(0xFF3A3A45)],
    this.favorite = false,
    this.onLongPress,
  });

  final String label;
  final ui.Image? image;
  final List<Color> fallback;
  final bool selected;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.lumora;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 6),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: SizedBox(
            width: 76,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
                  width: 70,
                  height: 70,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(19),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: selected ? t.borderActiveColors : [t.glassFill, t.glassFill],
                    ),
                    border: selected ? null : Border.all(color: t.borderColors.first),
                    boxShadow: selected ? [BoxShadow(color: t.glow, blurRadius: 14, spreadRadius: -3)] : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: fallback,
                            ),
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          layoutBuilder: (current, previous) =>
                              Stack(fit: StackFit.expand, children: [...previous, ?current]),
                          child: image == null
                              ? const SizedBox.expand()
                              : RawImage(key: ValueKey(image), image: image, fit: BoxFit.cover),
                        ),
                        if (favorite)
                          const PositionedDirectional(
                            top: 3,
                            end: 3,
                            child: Icon(
                              Icons.star_rounded,
                              size: 15,
                              color: Color(0xFFF2D58A),
                              shadows: [Shadow(blurRadius: 4)],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: selected ? theme.colorScheme.onSurface : t.textMuted,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 6, bottom: 22),
      child: GlassContainer(
        radius: 19,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 70,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: scheme.primary),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A cheap visual signature of a look, shown until its live thumbnail is
/// rendered.
List<Color> presetSwatch(Preset? p) {
  if (p == null) return const [Color(0xFF2A2A33), Color(0xFF3A3A45)];
  final a = p.adjustments;
  if (a.duotone.strength > 0) return [Color(a.duotone.shadowColor), Color(a.duotone.highlightColor)];
  if (a.saturation <= -0.9) return const [Color(0xFF111111), Color(0xFFBBBBBB)];
  final warm = a.temperature;
  final base = HSLColor.fromAHSL(
    1,
    warm >= 0 ? 32 : 205,
    (0.4 + a.vibrance).clamp(0.1, 0.9),
    (0.35 + a.exposure * 0.1).clamp(0.1, 0.9),
  );
  final tint = HSLColor.fromAHSL(
    1,
    (a.splitTone.shadowHue * 360) % 360,
    (0.3 + a.splitTone.shadowSaturation).clamp(0, 1),
    0.25,
  );
  return [tint.toColor(), base.toColor()];
}
