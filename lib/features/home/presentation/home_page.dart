import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lumora/core/providers.dart';
import 'package:lumora/core/router/app_router.dart';
import 'package:lumora/core/theme/app_theme.dart';
import 'package:lumora/core/utils/l10n_ext.dart';
import 'package:lumora/features/projects/data/project_repository.dart';
import 'package:material_ui/material_ui.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  Future<void> _pickPhoto(BuildContext context) async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file != null && context.mounted) {
      await context.push('/photo', extra: PhotoEditorArgs(sourcePath: file.path));
    }
  }

  Future<void> _pickVideo(BuildContext context) async {
    final files = await ImagePicker().pickMultiVideo();
    if (files.isNotEmpty && context.mounted) {
      await context.push('/video', extra: VideoEditorArgs(paths: [for (final f in files) f.path]));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final projects = ref.watch(recentProjectsProvider);
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
                          onTap: () => _pickPhoto(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BigAction(
                          icon: Icons.movie_outlined,
                          label: l.editVideo,
                          colors: const [Color(0xFF8B7CFF), Color(0xFF3FC5F0)],
                          onTap: () => _pickVideo(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(l.recentProjects, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          projects.when(
            loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverToBoxAdapter(child: Text(l.errorGeneric('$e'))),
            data: (list) => list.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(l.noProjects, textAlign: TextAlign.center),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    sliver: SliverGrid.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 180,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: list.length,
                      itemBuilder: (context, i) => _ProjectTile(project: list[i]),
                    ),
                  ),
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
    return Material(
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        height: 132,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: InkWell(
          onTap: onTap,
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
    );
  }
}

class _ProjectTile extends ConsumerWidget {
  const _ProjectTile({required this.project});
  final ProjectSummary project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumb = project.thumbnailPath;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => project.kind == ProjectKind.photo
            ? context.push('/photo', extra: PhotoEditorArgs(projectId: project.id))
            : context.push('/video', extra: VideoEditorArgs(projectId: project.id)),
        onLongPress: () async {
          final l = context.l10n;
          final ok = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: Text(l.deleteProjectQ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
                FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.delete)),
              ],
            ),
          );
          if (ok ?? false) await ref.read(projectRepositoryProvider).delete(project.id);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: thumb != null && File(thumb).existsSync()
                  ? Image.file(File(thumb), fit: BoxFit.cover)
                  : ColoredBox(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      child: Icon(project.kind == ProjectKind.photo ? Icons.photo : Icons.movie, size: 40),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Icon(project.kind == ProjectKind.photo ? Icons.photo_outlined : Icons.movie_outlined, size: 14),
                  const SizedBox(width: 4),
                  Expanded(child: Text(project.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
