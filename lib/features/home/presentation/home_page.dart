import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lumora/core/providers.dart';
import 'package:lumora/core/router/app_router.dart';
import 'package:lumora/core/ui/ui.dart';
import 'package:lumora/core/utils/haptics.dart';
import 'package:lumora/core/utils/l10n_ext.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:lumora/features/ai/presentation/ai_tools_sheet.dart';
import 'package:lumora/features/home/presentation/launchers.dart';
import 'package:lumora/features/home/presentation/project_grid.dart';
import 'package:lumora/features/settings/data/settings_controller.dart';
import 'package:material_ui/material_ui.dart';

export 'project_grid.dart' show projectDisplayName;

/// Projects shown on Home; the Projects tab lists all of them.
const kHomeProjectLimit = 6;

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  ProjectFilter _filter = ProjectFilter.all;
  bool _onboardingShown = false;
  bool _searching = false;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _maybeShowOnboarding(AppSettings settings) {
    if (_onboardingShown || !settings.loaded || settings.onboardingDone) return;
    _onboardingShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.push('/welcome'));
    });
  }

  void _toggleSearch() {
    Haptics.selection();
    setState(() {
      _searching = !_searching;
      if (!_searching) _search.clear();
    });
  }

  /// The model-backed tools, opened on a freshly picked photo.
  List<AiToolCard> _aiCards(BuildContext context) {
    final l = context.l10n;
    final t = context.lumora;
    AiToolCard card(IconData icon, Color color, String label, QuickAction action, [AiTool? tool]) => AiToolCard(
      icon: icon,
      color: color,
      label: label,
      tool: tool,
      onTap: () => pickAndEditPhoto(context, action: action),
    );
    return [
      card(Icons.content_cut, t.violet, l.aiRemoveBg, QuickAction.removeBackground, AiTool.removeBackground),
      card(Icons.auto_fix_high, t.apricot, l.aiAutoEnhance, QuickAction.autoEnhance),
      card(Icons.blur_on, t.blue, l.aiBlurBg, QuickAction.blurBackground, AiTool.backgroundBlur),
      card(Icons.person_outline, t.teal, l.aiPortraitBg, QuickAction.cutOutPerson, AiTool.cutOutPerson),
      card(Icons.cleaning_services_outlined, t.mint, l.aiEraser, QuickAction.eraser, AiTool.eraser),
      card(Icons.face_retouching_natural, t.rose, l.aiRetouch, QuickAction.retouch, AiTool.portraitRetouch),
      // Tools added in 1.3, now reachable from Home too.
      card(Icons.photo_size_select_large, t.violet, l.aiSelectObject, QuickAction.selectObject, AiTool.selectObject),
      card(Icons.layers_clear_outlined, t.blue, l.aiDepthBlur, QuickAction.depthBlur, AiTool.depthBlur),
      card(Icons.wb_incandescent_outlined, t.apricot, l.aiRelight, QuickAction.relight, AiTool.relight),
      card(Icons.person_remove_outlined, t.rose, l.aiErasePerson, QuickAction.erasePerson, AiTool.erasePerson),
      AiToolCard(
        icon: Icons.document_scanner_outlined,
        color: t.teal,
        label: l.docScanner,
        onTap: () => context.push('/scan'),
      ),
      card(Icons.open_in_full, t.violet, l.aiUpscale, QuickAction.upscale, AiTool.upscale),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.lumora;
    _maybeShowOnboarding(ref.watch(settingsControllerProvider));
    final tools = <(IconData, String, Color, VoidCallback)>[
      (
        Icons.content_cut,
        l.aiRemoveBg,
        t.violet,
        () => pickAndEditPhoto(context, action: QuickAction.removeBackground),
      ),
      (Icons.auto_fix_high, l.aiAutoEnhance, t.teal, () => pickAndEditPhoto(context, action: QuickAction.autoEnhance)),
      (Icons.open_in_full, l.aiUpscale, t.rose, () => pickAndEditPhoto(context, action: QuickAction.upscale)),
      (
        Icons.cleaning_services_outlined,
        l.aiEraser,
        t.mint,
        () => pickAndEditPhoto(context, action: QuickAction.eraser),
      ),
      (Icons.document_scanner_outlined, l.scanDocument, t.apricot, () => context.push('/scan')),
      (Icons.psychology_alt_outlined, l.aiToolsShort, t.blue, () => showAiToolsSheet(context, _aiCards(context))),
      (Icons.healing, l.toolHeal, t.teal, () => pickAndEditPhoto(context, action: QuickAction.heal)),
      (Icons.dashboard_outlined, l.collage, t.rose, () => context.push('/collage')),
      (Icons.burst_mode_outlined, l.batchEdit, t.violet, () => context.push('/batch')),
    ];
    final bottom = MediaQuery.paddingOf(context).bottom;
    final total = ref.watch(recentProjectsProvider).value?.length ?? 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              sliver: SliverToBoxAdapter(child: _topBar(context)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            sliver: SliverToBoxAdapter(
              child: _Hero(onPhoto: () => pickAndEditPhoto(context), onVideo: () => pickAndEditVideo(context)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            sliver: SliverToBoxAdapter(child: SectionTitle(l.quickTools)),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: tools.length,
                separatorBuilder: (_, _) => const SizedBox(width: 4),
                itemBuilder: (context, i) {
                  final (icon, label, color, onTap) = tools[i];
                  return _QuickTool(icon: icon, label: label, color: color, onTap: onTap);
                },
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            sliver: SliverToBoxAdapter(
              child: SectionTitle(
                l.recentProjects,
                trailing: ProjectFilterButton(value: _filter, onChanged: (f) => setState(() => _filter = f)),
              ),
            ),
          ),
          ProjectsSliver(
            filter: _filter,
            query: _search.text,
            limit: kHomeProjectLimit,
            onEmptyOpen: () => pickAndEditPhoto(context),
          ),
          if (total > kHomeProjectLimit && _search.text.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: TextButton.icon(
                    onPressed: () => context.go('/projects'),
                    icon: const Icon(Icons.grid_view_rounded, size: 18),
                    label: Text(l.seeAll),
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(child: SizedBox(height: bottom + 24)),
        ],
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return GlassTopBar(
      height: 68,
      padding: const EdgeInsetsDirectional.fromSTEB(10, 0, 12, 0),
      children: [
        const AppLogo(size: 46),
        const SizedBox(width: 12),
        Expanded(
          child: AnimatedSwitcher(
            duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
            child: _searching
                ? TextField(
                    key: const ValueKey('search'),
                    controller: _search,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: l.searchProjects,
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  )
                : Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      l.appTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.2),
                    ),
                  ),
          ),
        ),
        GlassIconButton(
          icon: _searching ? Icons.close : Icons.search,
          tooltip: _searching ? l.clearSearch : l.search,
          selected: _searching,
          onPressed: _toggleSearch,
        ),
        const SizedBox(width: 8),
        GlassIconButton(icon: Icons.settings_outlined, tooltip: l.settings, onPressed: () => context.go('/settings')),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onPhoto, required this.onVideo});

  final VoidCallback onPhoto;
  final VoidCallback onVideo;

  @override
  Widget build(BuildContext context) {
    final t = context.lumora;
    final l = context.l10n;
    return GlassContainer(
      radius: 28,
      glow: true,
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: t.heroGradient),
      borderColors: t.borderActiveColors.map((c) => c.withValues(alpha: 0.6)).toList(),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _HeroButton(icon: Icons.photo_outlined, label: l.editPhoto, color: t.violet, onTap: onPhoto),
          const SizedBox(height: 12),
          _HeroButton(icon: Icons.videocam_outlined, label: l.editVideo, color: t.blue, onTap: onVideo),
        ],
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({required this.icon, required this.label, required this.color, required this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: PressScale(
        child: GlassContainer(
          radius: 22,
          height: 78,
          fill: Colors.white.withValues(alpha: context.lumora.isDark ? 0.07 : 0.45),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () {
                Haptics.light();
                onTap();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    GlassContainer(
                      width: 50,
                      height: 50,
                      radius: 15,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [color.withValues(alpha: 0.5), color.withValues(alpha: 0.22)],
                      ),
                      child: Icon(icon, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: context.lumora.textMuted),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickTool extends StatelessWidget {
  const _QuickTool({required this.icon, required this.label, required this.color, required this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: PressScale(
        scale: 0.93,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Haptics.selection();
            onTap();
          },
          child: SizedBox(
            width: 80,
            child: Column(
              children: [
                const SizedBox(height: 4),
                GlowIconOrb(icon: icon, color: color, size: 58),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(height: 1.2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
