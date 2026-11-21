import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumora/core/providers.dart';
import 'package:lumora/core/ui/ui.dart';
import 'package:lumora/core/utils/haptics.dart';
import 'package:lumora/core/utils/l10n_ext.dart';
import 'package:lumora/features/home/presentation/launchers.dart';
import 'package:lumora/features/home/presentation/sample_scene.dart';
import 'package:lumora/features/photo_editor/data/preset_store.dart';
import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/photo_editor/domain/geometry.dart';
import 'package:lumora/features/photo_editor/domain/presets.dart';
import 'package:lumora/features/photo_editor/engine/photo_renderer.dart';
import 'package:lumora/features/photo_editor/engine/preset_thumbnails.dart';
import 'package:lumora/features/photo_editor/presentation/widgets/presets_panel.dart';
import 'package:material_ui/material_ui.dart';

/// Thumbnails of the Templates tab. Separate from the editor's cache (the
/// tab stays alive in the shell while the editor is open).
final Provider<PresetThumbnailCache> _templateThumbsProvider = Provider.autoDispose<PresetThumbnailCache>((ref) {
  final cache = PresetThumbnailCache(() async {
    final shaders = await ref.read(shaderLibraryProvider.future);
    return PhotoRenderer(shaders, ref.read(lutRepositoryProvider));
  });
  ref.onDispose(cache.dispose);
  return cache;
});

/// The Templates tab: browse every look (built-in and custom) by category,
/// then pick a photo to open it with the look applied.
class TemplatesPage extends ConsumerStatefulWidget {
  const TemplatesPage({super.key});

  @override
  ConsumerState<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends ConsumerState<TemplatesPage> {
  late final PresetThumbnailCache _cache;
  ui.Image? _scene;

  @override
  void initState() {
    super.initState();
    // Live previews: every look rendered by the real pipeline on a small
    // drawn landscape (falls back to a colour swatch while rendering).
    _cache = ref.read(_templateThumbsProvider)..addListener(_onThumbs);
    unawaited(
      renderSampleScene().then((img) {
        if (!mounted) {
          img.dispose();
          return;
        }
        setState(() => _scene = img);
      }),
    );
  }

  void _onThumbs() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cache.removeListener(_onThumbs);
    _scene?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.lumora;
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final lib = ref.watch(presetLibraryControllerProvider);
    final category = ref.watch(presetCategoryProvider);
    final categories = <PresetCategory?>[
      null,
      ...PresetCategory.values.where((c) => c != PresetCategory.custom),
      PresetCategory.custom,
    ];
    final presets = lib.presetsFor(category);
    final cache = ref.watch(_templateThumbsProvider)
      ..update(preview: _scene, base: Adjustments.neutral, geometry: const GeometryState());
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(title: Text(l.navTemplates), showBack: false),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Text(l.templatesSubtitle, style: theme.textTheme.bodyMedium?.copyWith(color: t.textMuted)),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final c in categories)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(
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
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          if (presets.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  category == PresetCategory.custom ? l.noCustomPresets : l.noFavorites,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: t.textMuted),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.82,
                ),
                itemCount: presets.length,
                itemBuilder: (context, i) {
                  final preset = presets[i];
                  return _TemplateCard(
                    preset: preset,
                    label: preset.name(lang),
                    favorite: lib.isFavorite(preset.id),
                    image: _scene == null ? null : cache.thumbnail(preset),
                    onTap: () => pickAndEditPhoto(context, presetId: preset.id),
                  );
                },
              ),
            ),
          SliverToBoxAdapter(child: SizedBox(height: bottom + 24)),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.preset,
    required this.label,
    required this.favorite,
    required this.onTap,
    this.image,
  });

  final Preset preset;
  final ui.Image? image;
  final String label;
  final bool favorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final swatch = presetSwatch(preset);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: PressScale(
        scale: 0.97,
        child: GlassContainer(
          radius: 22,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () {
                Haptics.selection();
                onTap();
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
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: swatch,
                                ),
                              ),
                            ),
                            if (image != null)
                              RawImage(image: image, fit: BoxFit.cover)
                            else
                              // A soft "landscape" silhouette so the swatch reads as a photo.
                              const CustomPaint(painter: _HillsPainter()),
                            if (favorite)
                              const PositionedDirectional(
                                top: 6,
                                end: 6,
                                child: Icon(Icons.star_rounded, size: 18, color: Color(0xFFF2D58A)),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 2),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
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
}

class _HillsPainter extends CustomPainter {
  const _HillsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas
      ..drawCircle(Offset(w * 0.72, h * 0.3), w * 0.09, Paint()..color = const Color(0x40FFFFFF))
      ..drawPath(
        Path()
          ..moveTo(0, h * 0.78)
          ..quadraticBezierTo(w * 0.3, h * 0.52, w * 0.58, h * 0.74)
          ..quadraticBezierTo(w * 0.8, h * 0.6, w, h * 0.7)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close(),
        Paint()..color = const Color(0x33000000),
      );
  }

  @override
  bool shouldRepaint(_HillsPainter oldDelegate) => false;
}
