import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lumora/core/providers.dart';
import 'package:lumora/core/router/app_router.dart';
import 'package:lumora/core/theme/app_theme.dart';
import 'package:lumora/core/utils/haptics.dart';
import 'package:lumora/core/utils/l10n_ext.dart';
import 'package:lumora/features/photo_editor/data/preset_store.dart';
import 'package:lumora/features/photo_editor/presentation/widgets/presets_panel.dart' show promptName;
import 'package:lumora/features/projects/data/project_repository.dart';
import 'package:lumora/features/settings/data/settings_controller.dart';
import 'package:lumora/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Friendly title for a project: the user's own name, otherwise
/// "Photo · 20 Nov 2026, 22:50" in the current language.
String projectDisplayName(ProjectSummary p, AppLocalizations l, String locale) {
  if (p.hasCustomName) return p.name;
  final date = DateFormat.yMMMd(locale).add_jm().format(p.createdAt);
  return p.kind == ProjectKind.photo ? l.photoProjectName(date) : l.videoProjectName(date);
}

enum _Filter { all, photos, videos }

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  _Filter _filter = _Filter.all;
  bool _onboardingShown = false;

  Future<void> _pickPhoto({QuickAction? action}) async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file != null && mounted) {
      await context.push(
        '/photo',
        extra: PhotoEditorArgs(sourcePath: file.path, initialAction: action),
      );
    }
  }

  Future<void> _pickVideo() async {
    final files = await ImagePicker().pickMultiVideo();
    if (files.isNotEmpty && mounted) {
      await context.push('/video', extra: VideoEditorArgs(paths: [for (final f in files) f.path]));
    }
  }

  void _maybeShowOnboarding(AppSettings settings) {
    if (_onboardingShown || !settings.loaded || settings.onboardingDone) return;
    _onboardingShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.push('/welcome'));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final projects = ref.watch(recentProjectsProvider);
    _maybeShowOnboarding(ref.watch(settingsControllerProvider));
    final tools = <(IconData, String, List<Color>, VoidCallback)>[
      (
        Icons.content_cut,
        l.aiRemoveBg,
        const [Color(0xFFFF6B6B), Color(0xFFFFB547)],
        () => _pickPhoto(action: QuickAction.removeBackground),
      ),
      (
        Icons.auto_fix_high,
        l.aiAutoEnhance,
        const [Color(0xFFFFB547), Color(0xFFFFE08A)],
        () => _pickPhoto(action: QuickAction.autoEnhance),
      ),
      (
        Icons.high_quality,
        l.aiUpscale,
        const [Color(0xFF3FC5F0), Color(0xFF8B7CFF)],
        () => _pickPhoto(action: QuickAction.upscale),
      ),
      (
        Icons.cleaning_services_outlined,
        l.aiEraser,
        const [Color(0xFF8B7CFF), Color(0xFFE56BFF)],
        () => _pickPhoto(action: QuickAction.eraser),
      ),
      (
        Icons.healing,
        l.toolHeal,
        const [Color(0xFF43E0A0), Color(0xFF3FC5F0)],
        () => _pickPhoto(action: QuickAction.heal),
      ),
      (
        Icons.document_scanner_outlined,
        l.scanDocument,
        const [Color(0xFF5AD1FF), Color(0xFF2E7BFF)],
        () => context.push('/scan'),
      ),
      (
        Icons.dashboard_outlined,
        l.collage,
        const [Color(0xFFFF8BB5), Color(0xFFFF6B6B)],
        () => context.push('/collage'),
      ),
      (
        Icons.burst_mode_outlined,
        l.batchEdit,
        const [Color(0xFF9BE15D), Color(0xFF00C9A7)],
        () => context.push('/batch'),
      ),
    ];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: ShaderMask(
              shaderCallback: (r) => const LinearGradient(colors: [AppTheme.seed, AppTheme.accent2]).createShader(r),
              child: Text(
                l.appTitle,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
            actions: [
              IconButton(tooltip: l.aiModels, icon: const Icon(Icons.memory), onPressed: () => context.push('/models')),
              IconButton(
                tooltip: l.settings,
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => context.push('/settings'),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.tagline,
                    style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _BigAction(
                          icon: Icons.photo_outlined,
                          label: l.editPhoto,
                          colors: const [Color(0xFFFFB547), Color(0xFFFF6B6B)],
                          onTap: _pickPhoto,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BigAction(
                          icon: Icons.movie_outlined,
                          label: l.editVideo,
                          colors: const [Color(0xFF8B7CFF), Color(0xFF3FC5F0)],
                          onTap: _pickVideo,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(l.quickTools, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 104,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: tools.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final (icon, label, colors, onTap) = tools[i];
                  return _QuickTool(icon: icon, label: label, colors: colors, onTap: onTap);
                },
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(child: Text(l.recentProjects, style: theme.textTheme.titleMedium)),
                  SegmentedButton<_Filter>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                    segments: [
                      ButtonSegment(value: _Filter.all, label: Text(l.filterAll)),
                      const ButtonSegment(value: _Filter.photos, icon: Icon(Icons.photo_outlined, size: 18)),
                      const ButtonSegment(value: _Filter.videos, icon: Icon(Icons.movie_outlined, size: 18)),
                    ],
                    selected: {_filter},
                    onSelectionChanged: (v) => setState(() => _filter = v.first),
                  ),
                ],
              ),
            ),
          ),
          projects.when(
            loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverToBoxAdapter(child: Text(l.errorGeneric('$e'))),
            data: (all) {
              final list = switch (_filter) {
                _Filter.all => all,
                _Filter.photos => all.where((p) => p.kind == ProjectKind.photo).toList(),
                _Filter.videos => all.where((p) => p.kind == ProjectKind.video).toList(),
              };
              if (list.isEmpty) {
                return SliverToBoxAdapter(child: _EmptyProjects(onOpen: _pickPhoto));
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 190,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, i) => _ProjectTile(project: list[i]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BigAction extends StatelessWidget {
  const _BigAction({required this.icon, required this.label, required this.colors, required this.onTap});

  final IconData icon;
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          height: 124,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: InkWell(
            onTap: () {
              Haptics.light();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: Colors.white, size: 32),
                  Text(
                    label,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickTool extends StatelessWidget {
  const _QuickTool({required this.icon, required this.label, required this.colors, required this.onTap});

  final IconData icon;
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Haptics.selection();
          onTap();
        },
        child: Ink(
          width: 92,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: colors),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyProjects extends StatelessWidget {
  const _EmptyProjects({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 48),
      child: Column(
        children: [
          SizedBox(
            width: 140,
            height: 110,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: -0.18,
                  child: _EmptyCard(color: scheme.secondaryContainer, icon: Icons.movie_outlined),
                ),
                Transform.translate(
                  offset: const Offset(24, 6),
                  child: Transform.rotate(
                    angle: 0.14,
                    child: _EmptyCard(color: scheme.primaryContainer, icon: Icons.photo_outlined),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(l.noProjectsTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            l.noProjects,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: onOpen,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(l.editPhoto),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.color, required this.icon});
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 74,
    height: 92,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [BoxShadow(blurRadius: 12, color: Color(0x33000000))],
    ),
    child: Icon(icon, size: 32),
  );
}

class _ProjectTile extends ConsumerWidget {
  const _ProjectTile({required this.project});
  final ProjectSummary project;

  void _open(BuildContext context) {
    Haptics.selection();
    unawaited(
      project.kind == ProjectKind.photo
          ? context.push('/photo', extra: PhotoEditorArgs(projectId: project.id))
          : context.push('/video', extra: VideoEditorArgs(projectId: project.id)),
    );
  }

  Future<void> _action(BuildContext context, WidgetRef ref, String action) async {
    final l = context.l10n;
    final repo = ref.read(projectRepositoryProvider);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final name = projectDisplayName(project, l, locale);
    switch (action) {
      case 'open':
        _open(context);
      case 'rename':
        final newName = await promptName(context, title: l.rename, initial: name);
        if (newName != null) await repo.rename(project.id, newName);
      case 'duplicate':
        await repo.duplicate(project.id, name: l.copyOf(name));
      case 'copyEdits':
        final edit = await repo.photoEdit(project.id);
        if (edit != null) {
          await ref.read(editClipboardProvider.notifier).copy(edit);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.editsCopied)));
          }
        }
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(l.deleteProjectQ),
            content: Text(name),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.delete)),
            ],
          ),
        );
        if (ok ?? false) {
          Haptics.medium();
          await repo.delete(project.id);
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final theme = Theme.of(context);
    final thumb = project.thumbnailPath;
    final name = projectDisplayName(project, l, locale);
    final when = DateFormat.MMMd(locale).add_jm().format(project.updatedAt);
    return Semantics(
      button: true,
      label: name,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: () => _open(context),
          onLongPress: () async {
            Haptics.medium();
            final box = context.findRenderObject() as RenderBox?;
            final origin = box?.localToGlobal(Offset.zero) ?? Offset.zero;
            final action = await showMenu<String>(
              context: context,
              position: RelativeRect.fromLTRB(origin.dx, origin.dy, origin.dx + 1, origin.dy + 1),
              items: _menuItems(l),
            );
            if (action != null && context.mounted) await _action(context, ref, action);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumb != null && File(thumb).existsSync())
                      Image.file(File(thumb), fit: BoxFit.cover, cacheWidth: 400, gaplessPlayback: true)
                    else
                      ColoredBox(
                        color: theme.colorScheme.surfaceContainerHigh,
                        child: Icon(project.kind == ProjectKind.photo ? Icons.photo : Icons.movie, size: 40),
                      ),
                    PositionedDirectional(
                      top: 6,
                      start: 6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0x99000000),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            project.kind == ProjectKind.photo ? Icons.photo_outlined : Icons.movie_outlined,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 0, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge),
                          Text(
                            when,
                            maxLines: 1,
                            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: l.more,
                      icon: const Icon(Icons.more_vert, size: 20),
                      onSelected: (a) => _action(context, ref, a),
                      itemBuilder: (_) => _menuItems(l),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _menuItems(AppLocalizations l) => [
    PopupMenuItem(
      value: 'open',
      child: ListTile(leading: const Icon(Icons.open_in_new), title: Text(l.open)),
    ),
    PopupMenuItem(
      value: 'rename',
      child: ListTile(leading: const Icon(Icons.drive_file_rename_outline), title: Text(l.rename)),
    ),
    PopupMenuItem(
      value: 'duplicate',
      child: ListTile(leading: const Icon(Icons.copy_all_outlined), title: Text(l.duplicate)),
    ),
    if (project.kind == ProjectKind.photo)
      PopupMenuItem(
        value: 'copyEdits',
        child: ListTile(leading: const Icon(Icons.copy), title: Text(l.copyEdits)),
      ),
    PopupMenuItem(
      value: 'delete',
      child: ListTile(leading: const Icon(Icons.delete_outline), title: Text(l.delete)),
    ),
  ];
}
