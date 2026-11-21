import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lumora/core/ui/ui.dart';
import 'package:lumora/core/utils/haptics.dart';
import 'package:lumora/core/utils/l10n_ext.dart';
import 'package:lumora/features/settings/data/settings_controller.dart';
import 'package:material_ui/material_ui.dart';

/// First-run tips: four swipeable cards. Shown once; can be reopened from
/// Settings.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(settingsControllerProvider.notifier).setOnboardingDone();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final t = context.lumora;
    final tips = <(IconData, Color, String, String)>[
      (Icons.lock_outline, t.violet, l.tipPrivateTitle, l.tipPrivateBody),
      (Icons.auto_awesome, t.apricot, l.tipLooksTitle, l.tipLooksBody),
      (Icons.psychology_alt_outlined, t.blue, l.tipAiTitle, l.tipAiBody),
      (Icons.document_scanner_outlined, t.mint, l.tipToolsTitle, l.tipToolsBody),
    ];
    final last = _index == tips.length - 1;
    return LumoraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 8, 0),
                child: Row(
                  children: [
                    const AppLogo(size: 40),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l.appTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    TextButton(onPressed: _finish, child: Text(l.skip)),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: tips.length,
                  onPageChanged: (i) {
                    Haptics.selection();
                    setState(() => _index = i);
                  },
                  itemBuilder: (context, i) {
                    final (icon, color, title, body) = tips[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TweenAnimationBuilder<double>(
                            key: ValueKey(i),
                            tween: Tween(begin: 0.7, end: 1),
                            duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 420),
                            curve: Curves.easeOutBack,
                            builder: (_, v, child) => Transform.scale(scale: v, child: child),
                            child: i == 0
                                ? Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      const AppLogo(size: 148),
                                      PositionedDirectional(
                                        bottom: -10,
                                        end: -10,
                                        child: GlowIconOrb(icon: icon, color: color, size: 52, selected: true),
                                      ),
                                    ],
                                  )
                                : GlowIconOrb(icon: icon, color: color, size: 132, selected: true),
                          ),
                          const SizedBox(height: 36),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            body,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(color: t.textMuted),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < tips.length; i++)
                    AnimatedContainer(
                      duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
                      margin: const EdgeInsets.all(4),
                      width: i == _index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: i == _index ? LinearGradient(colors: t.primaryGradient) : null,
                        color: i == _index ? null : t.trackInactive,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  child: GlowButton(
                    expand: true,
                    height: 52,
                    onPressed: last
                        ? _finish
                        : () =>
                              _pages.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic),
                    label: last ? l.getStarted : l.next,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
