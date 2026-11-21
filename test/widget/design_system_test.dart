import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/core/theme/app_theme.dart';
import 'package:lumora/core/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

double _luminance(Color c) => c.computeLuminance();

double _contrast(Color a, Color b) {
  final hi = _luminance(a) > _luminance(b) ? a : b;
  final lo = identical(hi, a) ? b : a;
  return (_luminance(hi) + 0.05) / (_luminance(lo) + 0.05);
}

Widget _app(Widget child, {ThemeData? theme, bool reduceMotion = false}) => MaterialApp(
  theme: theme ?? AppTheme.dark(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  test('both themes carry the Lumora tokens and calm, readable colours', () {
    for (final theme in [AppTheme.dark(), AppTheme.light()]) {
      final t = theme.extension<LumoraTokens>();
      expect(t, isNotNull);
      final scheme = theme.colorScheme;
      // Body text and muted text meet WCAG AA on the page background.
      expect(_contrast(scheme.onSurface, t!.background), greaterThan(7));
      expect(_contrast(t.textMuted, t.background), greaterThan(4.5));
      // White CTA labels stay readable on the start of the gradient.
      expect(_contrast(Colors.white, t.primaryGradient.first), greaterThan(4.5));
      // Background glows stay faint.
      for (final blob in t.blobs) {
        expect(blob.color.a, lessThanOrEqualTo(0.12 + 1e-3));
      }
    }
    expect(AppTheme.dark().scaffoldBackgroundColor, const Color(0xFF0E1022));
  });

  testWidgets('GlowButton runs its action and disables cleanly', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(GlowButton(label: 'Export', onPressed: () => taps++)));
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    expect(taps, 1);

    await tester.pumpWidget(_app(const GlowButton(label: 'Export', onPressed: null)));
    await tester.tap(find.text('Export'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('press feedback is skipped when the OS reduces motion', (tester) async {
    await tester.pumpWidget(_app(const PressScale(child: Text('x')), reduceMotion: true));
    expect(find.byType(AnimatedScale), findsNothing);
    await tester.pumpWidget(_app(const PressScale(child: Text('x'))));
    expect(find.byType(AnimatedScale), findsOneWidget);
  });

  testWidgets('glass nav bar reports taps and the create button', (tester) async {
    var selected = -1;
    var created = false;
    await tester.pumpWidget(
      _app(
        GlassNavBar(
          items: const [
            GlassNavItem(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'A'),
            GlassNavItem(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'B'),
            GlassNavItem(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'C'),
            GlassNavItem(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'D'),
          ],
          selectedIndex: 0,
          onSelected: (i) => selected = i,
          createLabel: 'New',
          onCreate: () => created = true,
        ),
        theme: AppTheme.light(),
      ),
    );
    await tester.tap(find.text('C'));
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    expect(selected, 2);
    expect(created, isTrue);
  });
}
