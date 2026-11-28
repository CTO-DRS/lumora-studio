import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/photo_editor/engine/image_exporter.dart';
import 'package:lumora/features/photo_editor/engine/pixel_ops.dart';
import 'package:lumora/features/photo_editor/presentation/photo_editor_page.dart';
import 'package:lumora/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Opens the export sheet, runs [act], and returns what the sheet popped
/// (`null` = dismissed).
Future<(ExportOptions, bool)?> _run(
  WidgetTester tester,
  Future<void> Function() act, {
  ExportOptions initial = const ExportOptions(),
}) async {
  (ExportOptions, bool)? result;
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showModalBottomSheet<(ExportOptions, bool)>(
                context: context,
                isScrollControlled: true,
                builder: (_) => SizedBox(height: 900, child: ExportSheet(initial: initial)),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
  await act();
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('Share pops share=true and keeps the file out of the gallery', (tester) async {
    final r = await _run(tester, () => tester.tap(find.text('Share')));
    expect(r, isNotNull);
    expect(r!.$2, isTrue);
    expect(r.$1.saveToGallery, isFalse);
  });

  testWidgets('PNG hides the quality slider and disables the EXIF switch', (tester) async {
    final r = await _run(tester, () async {
      expect(find.byType(Slider), findsOneWidget);
      await tester.tap(find.text('PNG'));
      await tester.pump();
      expect(find.byType(Slider), findsNothing);
      final exif = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Keep EXIF metadata'));
      expect(exif.onChanged, isNull);
      await tester.tap(find.text('Save to gallery'));
    });
    expect(r!.$1.format, ExportFormat.png);
  });

  testWidgets('TIFF also hides the quality slider', (tester) async {
    final r = await _run(tester, () async {
      await tester.tap(find.text('TIF'));
      await tester.pump();
      expect(find.byType(Slider), findsNothing);
      await tester.tap(find.text('Save to gallery'));
    });
    expect(r!.$1.format, ExportFormat.tiff);
  });

  testWidgets('the initial options seed the sheet', (tester) async {
    final r = await _run(tester, () async {
      expect(find.text('Quality: 80'), findsOneWidget);
      final exif = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Keep EXIF metadata'));
      expect(exif.value, isFalse);
      await tester.tap(find.text('Save to gallery'));
    }, initial: const ExportOptions(quality: 80, keepExif: false));
    expect(r!.$1.quality, 80);
    expect(r.$1.keepExif, isFalse);
  });

  testWidgets('a social size forces JPEG and its preset quality', (tester) async {
    final r = await _run(tester, () async {
      await tester.tap(find.text('PNG'));
      await tester.pump();
      await tester.tap(find.text('WhatsApp'));
      await tester.pump();
      // Picking a social size flips PNG back to JPEG with the size's quality.
      expect(find.byType(Slider), findsOneWidget);
      await tester.tap(find.text('Save to gallery'));
    });
    expect(r!.$1.format, ExportFormat.jpeg);
    expect(r.$1.social, SocialSize.whatsapp);
    expect(r.$1.quality, SocialSize.whatsapp.quality);
  });
}
