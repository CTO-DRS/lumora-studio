import 'package:lumora/core/ui/glass.dart';
import 'package:lumora/core/ui/lumora_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The Lumora Studio app icon as a rounded tile.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 44});

  static const asset = 'assets/branding/app_icon.png';

  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.24;
    return CustomPaint(
      foregroundPainter: GradientBorderPainter(colors: context.lumora.borderColors, radius: radius),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => SizedBox.square(dimension: size),
        ),
      ),
    );
  }
}
