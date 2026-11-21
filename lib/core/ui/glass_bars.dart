import 'package:lumora/core/ui/buttons.dart';
import 'package:lumora/core/ui/glass.dart';
import 'package:lumora/core/ui/lumora_tokens.dart';
import 'package:lumora/core/utils/haptics.dart';
import 'package:material_ui/material_ui.dart';

/// A floating frosted bar for the top of a screen.
class GlassTopBar extends StatelessWidget {
  const GlassTopBar({required this.children, super.key, this.height = 64, this.padding});

  final List<Widget> children;
  final double height;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      blur: true,
      radius: 26,
      height: height,
      fill: context.lumora.glassFillStrong,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 10),
      child: Row(children: children),
    );
  }
}

/// Drop-in replacement for [AppBar]: a floating [GlassTopBar] with a back
/// button (when the route can pop), a title and actions.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({super.key, this.title, this.actions = const [], this.leading, this.showBack = true});

  final Widget? title;
  final List<Widget> actions;
  final Widget? leading;
  final bool showBack;

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context) {
    final canPop = showBack && (ModalRoute.of(context)?.impliesAppBarDismissal ?? false);
    final theme = Theme.of(context);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: GlassTopBar(
          children: [
            if (leading != null)
              leading!
            else if (canPop)
              GlassIconButton(
                icon: Icons.arrow_back,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => Navigator.maybePop(context),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: DefaultTextStyle(
                style: theme.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: title ?? const SizedBox.shrink(),
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

/// One destination of [GlassNavBar].
class GlassNavItem {
  const GlassNavItem({required this.icon, required this.selectedIcon, required this.label});

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Floating frosted bottom navigation with a raised "create" button in
/// the middle and an animated indicator behind the selected item.
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.createLabel,
    required this.onCreate,
    super.key,
  }) : assert(items.length == 4, 'two items on each side of the create button');

  final List<GlassNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final String createLabel;
  final VoidCallback onCreate;

  static const barHeight = 68.0;

  @override
  Widget build(BuildContext context) {
    final t = context.lumora;
    final duration = context.reduceMotion ? Duration.zero : const Duration(milliseconds: 280);
    // Slot 2 is the create button.
    int slotOf(int item) => item < 2 ? item : item + 1;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: SizedBox(
          height: barHeight + 22,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              GlassContainer(
                blur: true,
                radius: 30,
                height: barHeight,
                fill: t.glassFillStrong,
                child: LayoutBuilder(
                  builder: (context, c) {
                    final slot = c.maxWidth / 5;
                    return Stack(
                      children: [
                        AnimatedPositionedDirectional(
                          duration: duration,
                          curve: Curves.easeOutCubic,
                          start: slotOf(selectedIndex) * slot + 8,
                          top: 8,
                          width: slot - 16,
                          bottom: 8,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                gradient: LinearGradient(
                                  colors: [
                                    t.primaryGradient.first.withValues(alpha: 0.26),
                                    t.primaryGradient.last.withValues(alpha: 0.18),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(color: t.glow.withValues(alpha: 0.25), blurRadius: 14, spreadRadius: -4),
                                ],
                              ),
                              child: CustomPaint(
                                painter: GradientBorderPainter(colors: t.borderActiveColors, radius: 18),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            for (var i = 0; i < 2; i++) Expanded(child: _item(context, i)),
                            const Expanded(child: SizedBox()),
                            for (var i = 2; i < 4; i++) Expanded(child: _item(context, i)),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              PositionedDirectional(
                top: 0,
                bottom: 6,
                child: _CreateButton(label: createLabel, onTap: onCreate),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, int i) {
    final item = items[i];
    final active = i == selectedIndex;
    final theme = Theme.of(context);
    final color = active ? theme.colorScheme.onSurface : context.lumora.textMuted;
    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: () {
          Haptics.selection();
          onSelected(i);
        },
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? item.selectedIcon : item.icon, color: active ? theme.colorScheme.primary : color, size: 24),
            const SizedBox(height: 3),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.lumora;
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Haptics.light();
            onTap();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: t.primaryGradient,
                  ),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                  boxShadow: [BoxShadow(color: t.glow, blurRadius: 18, spreadRadius: -3, offset: const Offset(0, 4))],
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One tool of a floating editor toolbar: a rounded tile with an icon and a
/// label. The active tool gets the gradient fill and a soft glow.
class GlassToolTile extends StatelessWidget {
  const GlassToolTile({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    super.key,
    this.width = 64,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = context.lumora;
    final theme = Theme.of(context);
    return Semantics(
      selected: active,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: width,
          height: 72,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: active ? LinearGradient(colors: t.primaryGradient) : null,
                  color: active ? null : t.glassFill,
                  border: Border.all(color: active ? Colors.white.withValues(alpha: 0.3) : t.borderColors.first),
                  boxShadow: active ? [BoxShadow(color: t.glow, blurRadius: 14, spreadRadius: -3)] : null,
                ),
                child: Icon(icon, size: 22, color: active ? Colors.white : theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: active ? theme.colorScheme.onSurface : t.textMuted,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
