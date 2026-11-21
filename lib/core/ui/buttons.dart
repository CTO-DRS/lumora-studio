import 'package:lumora/core/ui/glass.dart';
import 'package:lumora/core/ui/lumora_tokens.dart';
import 'package:lumora/core/utils/haptics.dart';
import 'package:material_ui/material_ui.dart';

/// The main call to action: a violet→blue gradient pill with a soft glow.
class GlowButton extends StatelessWidget {
  const GlowButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.height = 48,
    this.expand = false,
    this.glow = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 22),
  });

  /// Compact pill used in top bars.
  const GlowButton.small({required this.label, required this.onPressed, super.key, this.icon})
    : height = 38,
      expand = false,
      glow = true,
      padding = const EdgeInsets.symmetric(horizontal: 18);

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final bool expand;
  final bool glow;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = context.lumora;
    final enabled = onPressed != null;
    final radius = BorderRadius.circular(height / 2);
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: height >= 44 ? 15 : 14,
      ),
    );
    final body = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 18, color: Colors.white), const SizedBox(width: 8)],
        Flexible(child: text),
      ],
    );
    return Semantics(
      button: true,
      enabled: enabled,
      child: PressScale(
        enabled: enabled,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: enabled ? 1 : 0.45,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(colors: t.primaryGradient),
              boxShadow: glow && enabled
                  ? [BoxShadow(color: t.glow, blurRadius: 16, offset: const Offset(0, 4), spreadRadius: -4)]
                  : null,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: radius,
                onTap: enabled
                    ? () {
                        Haptics.light();
                        onPressed!();
                      }
                    : null,
                child: CustomPaint(
                  foregroundPainter: GradientBorderPainter(
                    colors: const [Color(0x40FFFFFF), Color(0x10FFFFFF)],
                    radius: height / 2,
                  ),
                  child: SizedBox(
                    height: height,
                    child: Padding(padding: padding, child: body),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A round frosted button for icons in glass bars.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    required this.icon,
    super.key,
    this.onPressed,
    this.tooltip,
    this.size = 40,
    this.selected = false,
    this.iconColor,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final bool selected;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    Widget button = GlassContainer(
      circle: true,
      width: size,
      height: size,
      active: selected,
      glow: selected,
      fill: context.lumora.glassFill,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Center(
            child: Icon(
              icon,
              size: size * 0.5,
              color: enabled ? (iconColor ?? scheme.onSurface) : scheme.onSurface.withValues(alpha: 0.32),
            ),
          ),
        ),
      ),
    );
    button = Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: tooltip,
      excludeSemantics: tooltip != null,
      child: PressScale(enabled: enabled, child: button),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

/// A round gradient orb holding a white icon, in one of the muted accent
/// colours. Glows only when [selected].
class GlowIconOrb extends StatelessWidget {
  const GlowIconOrb({required this.icon, required this.color, super.key, this.size = 56, this.selected = false});

  final IconData icon;
  final Color color;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [lighten(color, 0.1), color],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: selected ? 0.55 : 0.22)),
        boxShadow: selected
            ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 16, spreadRadius: -2)]
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.44),
    );
  }
}

/// A small frosted pill, e.g. "Runs on your device".
class GlassChip extends StatelessWidget {
  const GlassChip({required this.label, super.key, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassContainer(
      radius: 999,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: context.lumora.textMuted), const SizedBox(width: 6)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(color: context.lumora.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section heading used on Home, Templates and Projects.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(text, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      ),
      ?trailing,
    ],
  );
}
