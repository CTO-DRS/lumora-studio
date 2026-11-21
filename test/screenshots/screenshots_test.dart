// Renders real screenshots of the v1.2 redesign (Home, photo editor, AI
// tools sheet) with real fonts, for comparing against the design mockups.
//
// Skipped by default. To run:
//   LUMORA_SCREENSHOTS=<output dir> LUMORA_SHOT_ASSETS=<dir with sample
//   photos> LUMORA_FONTS=<dir with Roboto + Noto Sans Arabic ttf files>
//   flutter test test/screenshots
//
// The sample photos (thumb0-3.jpg, city.jpg, face.jpg, pt_*.png) and fonts
// are not part of the repository.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/app.dart';
import 'package:lumora/core/providers.dart';
import 'package:lumora/core/router/app_router.dart';
import 'package:lumora/core/theme/app_theme.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:lumora/features/ai/presentation/ai_tools_sheet.dart';
import 'package:lumora/features/photo_editor/domain/edit_history.dart';
import 'package:lumora/features/photo_editor/domain/edit_state.dart';
import 'package:lumora/features/photo_editor/domain/presets.dart';
import 'package:lumora/features/photo_editor/engine/preset_thumbnails.dart';
import 'package:lumora/features/photo_editor/presentation/photo_editor_controller.dart';
import 'package:lumora/features/photo_editor/presentation/photo_editor_page.dart';
import 'package:lumora/features/photo_editor/presentation/widgets/presets_panel.dart';
import 'package:lumora/features/projects/data/app_database.dart';
import 'package:lumora/features/projects/data/project_repository.dart';
import 'package:lumora/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

final String? _out = Platform.environment['LUMORA_SCREENSHOTS'];
final String _assets = Platform.environment['LUMORA_SHOT_ASSETS'] ?? '/tmp/lumora_shots';
final String _fonts = Platform.environment['LUMORA_FONTS'] ?? '/tmp/fonts';
final String _locale = Platform.environment['LUMORA_SHOT_LOCALE'] ?? 'ar';
const _size = Size(390, 844);
const _dpr = 2.0;
const ValueKey<String> _shotKey = ValueKey('shot');
const _timeout = Timeout(Duration(seconds: 50));

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      final file = File(f);
      if (file.existsSync()) loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    }
    await loader.load();
  }

  const engineFonts = '/tmp/flutter/engine/src/flutter/txt/third_party/fonts';
  // Arabic glyphs fall back within the family, so both scripts render.
  // Tajawal covers Latin and Arabic (the test engine has no per-glyph
  // system fallback), registered as the theme's default family.
  final tajawal = [
    for (final w in ['Light', 'Regular', 'Medium', 'Bold', 'ExtraBold', 'Black']) '$_fonts/Tajawal-$w.ttf',
  ];
  await family(
    'Roboto',
    tajawal.where((f) => File(f).existsSync()).isEmpty
        ? ['$engineFonts/Roboto-Regular.ttf', '$engineFonts/Roboto-Medium.ttf']
        : tajawal,
  );
  await family('MaterialIcons', ['/tmp/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
}

void _device(WidgetTester tester) {
  tester.view
    ..physicalSize = _size * _dpr
    ..devicePixelRatio = _dpr
    ..padding = const FakeViewPadding(top: 47 * _dpr, bottom: 34 * _dpr)
    ..viewPadding = const FakeViewPadding(top: 47 * _dpr, bottom: 34 * _dpr);
  addTearDown(tester.view.reset);
}

Future<ui.Image> _decode(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  return (await codec.getNextFrame()).image;
}

/// Loads every on-screen image. File images are decoded by hand and put in
/// the image cache (file decoding does not complete inside widget tests).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        final provider = (element.widget as Image).image;
        final inner = provider is ResizeImage ? provider.imageProvider : provider;
        if (inner is FileImage) {
          final key = await provider.obtainKey(createLocalImageConfiguration(element));
          if (imageCache.containsKey(key) && imageCache.statusForKey(key).keepAlive) continue;
          imageCache.evict(key);
          final codec = await ui.instantiateImageCodec(
            inner.file.readAsBytesSync(),
            targetWidth: provider is ResizeImage ? provider.width : null,
          );
          final frame = await codec.getNextFrame();
          imageCache.putIfAbsent(key, () => OneFrameImageStreamCompleter(Future.value(ImageInfo(image: frame.image))));
        } else {
          await precacheImage(provider, element).timeout(const Duration(seconds: 3), onTimeout: () {});
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_shotKey));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _dpr);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory(_out!)..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

class _ShotEditor extends PhotoEditorController {
  _ShotEditor(this.image, this.tool);
  final ui.Image image;
  final EditorTool tool;

  @override
  PhotoEditorState build() => PhotoEditorState(
    history: EditHistory(const EditState(presetId: 'bright', presetIntensity: 0.62)),
    preview: image,
    rendered: image,
    tool: tool,
  );
}

class _ShotThumbs extends PresetThumbnailCache {
  _ShotThumbs(this.images) : super(() async => throw UnsupportedError('no GPU renderer in screenshots'));
  final Map<String, ui.Image> images;

  @override
  void update({required ui.Image? preview, required Object base, required Object geometry}) {}

  @override
  ui.Image? thumbnail(Preset? preset) => images[preset?.id ?? 'none'] ?? images['none'];
}

Widget _editorApp(List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark(),
    locale: Locale(_locale),
    localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
    supportedLocales: AppLocalizations.supportedLocales,
    home: const PhotoEditorPage(args: PhotoEditorArgs()),
  ),
);

void main() {
  final skip = _out == null ? 'Set LUMORA_SCREENSHOTS to render screenshots' : null;

  setUpAll(() async {
    if (_out != null) await _loadFonts();
  });

  testWidgets('home', skip: skip != null, timeout: _timeout, (tester) async {
    _device(tester);
    SharedPreferences.setMockInitialValues({'onboardingDone': true, 'locale': _locale});
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = ProjectRepository(db);
    final names = _locale == 'ar'
        ? ['غروب المدينة', 'بورتريه', 'حقل ذهبي', 'شارع المدينة']
        : ['City sunset', 'Portrait', 'Golden field', 'Street'];
    await tester.runAsync(() async {
      for (var i = 3; i >= 0; i--) {
        await repo.savePhoto(
          id: 'p$i',
          name: names[i],
          sourcePath: '/x/$i.jpg',
          state: EditState.initial,
          thumbnailPath: '$_assets/thumb$i.jpg',
        );
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    await tester.runAsync(() async {
      for (var i = 0; i < 4; i++) {
        final file = File('$_assets/thumb$i.jpg');
        final provider = ResizeImage(FileImage(file), width: 400);
        final key = await provider.obtainKey(ImageConfiguration.empty);
        final codec = await ui.instantiateImageCodec(file.readAsBytesSync(), targetWidth: 400);
        final frame = await codec.getNextFrame();
        imageCache.putIfAbsent(key, () => OneFrameImageStreamCompleter(Future.value(ImageInfo(image: frame.image))));
      }
    });
    await tester.pumpWidget(
      RepaintBoundary(
        key: _shotKey,
        child: ProviderScope(overrides: [appDatabaseProvider.overrideWithValue(db)], child: const LumoraApp()),
      ),
    );
    await _settle(tester);
    await _capture(tester, 'actual_home${_locale == 'ar' ? '' : '_$_locale'}');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('editor', skip: skip != null, timeout: _timeout, (tester) async {
    _device(tester);
    final (photo, thumbs) = (await tester.runAsync(() async {
      final photo = await _decode('$_assets/city.jpg');
      final thumbs = <String, ui.Image>{
        'none': await _decode('$_assets/pt_none.png'),
        'auto_pop': await _decode('$_assets/pt_vivid.png'),
        'bright': await _decode('$_assets/pt_cine.png'),
        'crisp': await _decode('$_assets/pt_cool.png'),
        'warm': await _decode('$_assets/pt_warm.png'),
        'cool': await _decode('$_assets/pt_cool.png'),
        'clean_paper': await _decode('$_assets/pt_mono.png'),
      };
      return (photo, thumbs);
    }))!;
    await tester.pumpWidget(
      RepaintBoundary(
        key: _shotKey,
        child: _editorApp([
          photoEditorControllerProvider.overrideWith(() => _ShotEditor(photo, EditorTool.presets)),
          presetThumbnailCacheProvider.overrideWith((ref) => _ShotThumbs(thumbs)),
        ]),
      ),
    );
    await _settle(tester);
    await _capture(tester, 'actual_editor${_locale == 'ar' ? '' : '_$_locale'}');
  });

  testWidgets('ai sheet', skip: skip != null, timeout: _timeout, (tester) async {
    _device(tester);
    final photo = (await tester.runAsync(() => _decode('$_assets/face.jpg')))!;
    final overrides = [
      photoEditorControllerProvider.overrideWith(() => _ShotEditor(photo, EditorTool.ai)),
      presetThumbnailCacheProvider.overrideWith((ref) => _ShotThumbs({})),
      installedModelsProvider.overrideWith(
        (ref) async => {
          for (final m in ModelRegistry.all)
            if (m != ModelRegistry.u2netp) m.id,
        },
      ),
    ];
    await tester.pumpWidget(RepaintBoundary(key: _shotKey, child: _editorApp(overrides)));
    await _settle(tester);
    final container = ProviderScope.containerOf(tester.element(find.byType(PhotoEditorPage)));
    container.read(modelDownloadProgressProvider.notifier).set(ModelRegistry.u2netp.id, 0.38);
    await tester.pump();
    await _capture(tester, 'actual_ai_panel${_locale == 'ar' ? '' : '_$_locale'}');
  });

  testWidgets('ai sheet from home', skip: skip != null, timeout: _timeout, (tester) async {
    _device(tester);
    SharedPreferences.setMockInitialValues({'onboardingDone': true, 'locale': _locale});
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      RepaintBoundary(
        key: _shotKey,
        child: ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            installedModelsProvider.overrideWith(
              (ref) async => {
                for (final m in ModelRegistry.all)
                  if (m != ModelRegistry.u2netp) m.id,
              },
            ),
          ],
          child: const LumoraApp(),
        ),
      ),
    );
    await _settle(tester);
    final l = AppLocalizations.of(tester.element(find.byType(Scaffold).first));
    await tester.dragUntilVisible(find.text(l.aiToolsShort), find.byType(ListView).first, const Offset(250, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.aiToolsShort));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.text(l.aiToolsTitle)));
    container.read(modelDownloadProgressProvider.notifier).set(ModelRegistry.u2netp.id, 0.38);
    await _settle(tester);
    await _capture(tester, 'actual_ai${_locale == 'ar' ? '' : '_$_locale'}');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  for (final (name, location, theme) in [
    ('actual_home_light', '/', 1),
    ('actual_settings', '/settings', 2),
    ('actual_templates', '/templates', 2),
    ('actual_onboarding', '/welcome', 2),
    ('actual_collage', '/collage', 2),
    ('actual_scanner', '/scan', 2),
    ('actual_batch', '/batch', 2),
    ('actual_video', '/video', 2),
  ]) {
    testWidgets(name, skip: skip != null, timeout: _timeout, (tester) async {
      _device(tester);
      SharedPreferences.setMockInitialValues({'onboardingDone': true, 'locale': _locale, 'themeMode': theme});
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.pumpWidget(
        RepaintBoundary(
          key: _shotKey,
          child: ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(db)],
            child: LumoraApp(initialLocation: location),
          ),
        ),
      );
      await _settle(tester);
      await _capture(tester, name);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
