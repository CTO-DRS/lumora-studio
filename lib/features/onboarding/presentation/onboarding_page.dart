import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lumora/core/theme/app_theme.dart';
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
    final tips = <(IconData, List<Color>, String, String)>[
      (Icons.lock_outline, const [AppTheme.seed, AppTheme.accent2], l.tipPrivateTitle, l.tipPrivateBody),
      (Icons.auto_awesome, const [Color(0xFFFFB547), Color(0xFFFF6B6B)], l.tipLooksTitle, l.tipLooksBody),
      (Icons.psychology_alt_outlined, const [Color(0xFF8B7CFF), Color(0xFF3FC5F0)], l.tipAiTitle, l.tipAiBody),
      (Icons.document_scanner_outlined, const [Color(0xFF43E0A0), Color(0xFF2E7BFF)], l.tipToolsTitle, l.tipToolsBody),
    ];
    final last = _index == tips.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(onPressed: _finish, child: Text(l.skip)),
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
                  final (icon, colors, title, body) = tips[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                          key: ValueKey(i),
                          tween: Tween(begin: 0.7, end: 1),
                          duration: const Duration(milliseconds: 420),
                          curve: Curves.easeOutBack,
                          builder: (_, v, child) => Transform.scale(scale: v, child: child),
                          child: Container(
                            width: 132,
                            height: 132,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: colors),
                              boxShadow: [BoxShadow(blurRadius: 32, color: colors.first.withValues(alpha: 0.4))],
                            ),
                            child: Icon(icon, size: 60, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 36),
                        Text(title, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
                        const SizedBox(height: 12),
                        Text(
                          body,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.all(4),
                    width: i == _index ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: last
                      ? _finish
                      : () => _pages.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic),
                  child: Text(last ? l.getStarted : l.next),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
