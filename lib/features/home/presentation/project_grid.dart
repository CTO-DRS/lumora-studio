import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lumora/core/providers.dart';
import 'package:lumora/core/router/app_router.dart';
import 'package:lumora/core/ui/ui.dart';
import 'package:lumora/core/utils/haptics.dart';
import 'package:lumora/core/utils/l10n_ext.dart';
import 'package:lumora/features/photo_editor/data/preset_store.dart';
import 'package:lumora/features/photo_editor/presentation/widgets/presets_panel.dart' show promptName;
import 'package:lumora/features/projects/data/project_repository.dart';
import 'package:lumora/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Friendly title for a project: the user's own name, otherwise
/// "Photo · 20 Nov 2026, 22:50" in the current language.
String projectDisplayName(ProjectSummary p, AppLocalizations l, String locale) {
  if (p.hasCustomName) return p.name;
  final date = DateFormat.yMMMd(locale).add_jm().format(p.createdAt);
  return p.kind == ProjectKind.photo ? l.photoProjectName(date) : l.videoProjectName(date);
}

enum ProjectFilter { all, photos, videos }

/// All / photos / videos segmented filter.
class ProjectFilterButton extends StatelessWidget {
  const ProjectFilterButton({required this.value, required this.onChanged, super.key});

  final ProjectFilter value;
  final ValueChanged<ProjectFilter> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<ProjectFilter>(
    showSelectedIcon: false,
    style: const ButtonStyle(visualDensity: VisualDensity.compact),
    segments: [
      ButtonSegment(value: ProjectFilter.all, label: Text(context.l10n.filterAll)),
      const ButtonSegment(value: ProjectFilter.photos, icon: Icon(Icons.photo_outlined, size: 18)),
      const ButtonSegment(value: ProjectFilter.videos, icon: Icon(Icons.movie_outlined, size: 18)),
    ],
    selected: {value},
    onSelectionChanged: (v) {
      Haptics.selection();
      onChanged(v.first);
    },
  );
}

/// Two-column (wider on tablets) glass grid of projects with the
/// open / rename / duplicate / copy edits / delete actions.
class ProjectsSliver extends ConsumerWidget {
  const ProjectsSliver({required this.filter, required this.onEmptyOpen, super.key, this.query = '', this.limit});

  final ProjectFilter filter;
  final String query;
  final int? limit;
  final VoidCallback onEmptyOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final projects = ref.watch(recentProjectsProvider);
    return projects.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => SliverToBoxAdapter(child: Text(l.errorGeneric('$e'))),
      data: (all) {
        var list = switch (filter) {
          ProjectFilter.all => all,
          ProjectFilter.photos => all.where((p) => p.kind == ProjectKind.photo).toList(),
          ProjectFilter.videos => all.where((p) => p.kind == ProjectKind.video).toList(),
        };
        final q = query.trim().toLowerCase();
        if (q.isNotEmpty) {
          list = list.where((p) => projectDisplayName(p, l, locale).toLowerCase().contains(q)).toList();
        }
        if (list.isEmpty) {
          return SliverToBoxAdapter(
            child: q.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      l.noMatchingProjects,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.lumora.textMuted),
                    ),
                  )
                : EmptyProjects(onOpen: onEmptyOpen),
          );
        }
        if (limit != null && list.length > limit!) list = list.take(limit!).toList();
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 230,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.98,
            ),
            itemCount: list.length,
            itemBuilder: (context, i) => ProjectTile(project: list[i]),
          ),
        );
      },
    );
  }
}

class EmptyProjects extends StatelessWidget {
  const EmptyProjects({required this.onOpen, super.key});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.lumora;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: GlassContainer(
        radius: 26,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          children: [
            SizedBox(
              width: 150,
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.translate(
                    offset: const Offset(-26, 4),
                    child: Transform.rotate(
                      angle: -0.16,
                      child: _EmptyCard(color: t.blue, icon: Icons.movie_outlined),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(26, 4),
                    child: Transform.rotate(
                      angle: 0.14,
                      child: _EmptyCard(color: t.violet, icon: Icons.photo_outlined),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(l.noProjectsTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              l.noProjects,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: t.textMuted),
            ),
            const SizedBox(height: 16),
            GlowButton(icon: Icons.add_photo_alternate_outlined, label: l.editPhoto, onPressed: onOpen),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.color, required this.icon});
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => GlassContainer(
    width: 70,
    height: 88,
    radius: 18,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [color.withValues(alpha: 0.42), color.withValues(alpha: 0.2)],
    ),
    child: Icon(icon, size: 30, color: Colors.white.withValues(alpha: 0.9)),
  );
}

class ProjectTile extends ConsumerWidget {
  const ProjectTile({required this.project, super.key});
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
    final t = context.lumora;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final theme = Theme.of(context);
    final thumb = project.thumbnailPath;
    final name = projectDisplayName(project, l, locale);
    final when = DateFormat.MMMd(locale).add_jm().format(project.updatedAt);
    final isPhoto = project.kind == ProjectKind.photo;
    return Semantics(
      button: true,
      label: name,
      child: PressScale(
        scale: 0.97,
        child: GlassContainer(
          radius: 22,
          child: Material(
            type: MaterialType.transparency,
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
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (thumb != null && File(thumb).existsSync())
                              Image.file(File(thumb), fit: BoxFit.cover, cacheWidth: 400, gaplessPlayback: true)
                            else
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      (isPhoto ? t.violet : t.blue).withValues(alpha: 0.32),
                                      (isPhoto ? t.blue : t.teal).withValues(alpha: 0.16),
                                    ],
                                  ),
                                ),
                                child: Icon(
                                  isPhoto ? Icons.photo_outlined : Icons.movie_outlined,
                                  size: 36,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            PositionedDirectional(
                              top: 6,
                              start: 6,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: const Color(0x8C0E1022),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    isPhoto ? Icons.photo_outlined : Icons.movie_outlined,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(4, 6, 0, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  when,
                                  maxLines: 1,
                                  style: theme.textTheme.labelSmall?.copyWith(color: t.textMuted),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: PopupMenuButton<String>(
                              tooltip: l.more,
                              padding: EdgeInsets.zero,
                              icon: Icon(Icons.more_vert, size: 20, color: t.textMuted),
                              onSelected: (a) => _action(context, ref, a),
                              itemBuilder: (_) => _menuItems(l),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
