import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/video_editor/domain/video_project.dart';
import 'package:lumora/features/video_editor/engine/video_engine.dart';

/// Golden tests for caption/text overlay styling (roadmap §6 gate). The
/// burn-in path rasterises VideoText through Flutter's text stack, so these
/// goldens pin shaping, RTL direction, size fractions and the background box.
/// Fonts are bundled in test/golden/fonts (Tajawal, OFL) so the goldens are
/// reproducible across machines.
///
/// The comparison decodes both PNGs and requires identical pixels. Regenerate
/// the goldens after an intentional styling change with:
///   LUMORA_UPDATE_GOLDENS=1 flutter test test/golden
void main() {
  const goldenDir = 'test/golden/files';
  final update = Platform.environment['LUMORA_UPDATE_GOLDENS'] == '1';

  setUpAll(() async {
    // One loader for the whole family, registered as the engine default —
    // two loaders for one family leave the collection empty in the tester.
    final loader = FontLoader('Roboto');
    for (final f in ['Tajawal-Regular.ttf', 'Tajawal-Bold.ttf']) {
      loader.addFont(Future.value(ByteData.sublistView(File('test/golden/fonts/$f').readAsBytesSync())));
    }
    await loader.load();
  });

  Future<List<int>> render(VideoText t, {int w = 720, int h = 1280}) async {
    final path = '${Directory.systemTemp.path}/golden_text_${t.id}.png';
    await VideoEngine.renderTextOverlay(t, w, h, path, fontFamily: 'Roboto');
    final bytes = File(path).readAsBytesSync();
    File(path).deleteSync();
    return bytes;
  }

  Future<ui.Image> decodePng(List<int> bytes) async =>
      (await (await ui.instantiateImageCodec(Uint8List.fromList(bytes))).getNextFrame()).image;

  Future<void> check(String name, VideoText t) async {
    final png = await render(t);
    final file = File('$goldenDir/$name.png');
    if (update) {
      file.createSync(recursive: true);
      file.writeAsBytesSync(png);
      return;
    }
    expect(file.existsSync(), isTrue, reason: 'missing golden $name — run with LUMORA_UPDATE_GOLDENS=1');
    final actual = await decodePng(png);
    final expected = await decodePng(file.readAsBytesSync());
    expect(actual.width, expected.width, reason: name);
    expect(actual.height, expected.height, reason: name);
    final a = (await actual.toByteData())!.buffer.asUint8List();
    final e = (await expected.toByteData())!.buffer.asUint8List();
    expect(a.length, e.length, reason: name);
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != e[i]) diff++;
    }
    expect(
      diff,
      0,
      reason: '$name: $diff of ${a.length} bytes differ — regenerate goldens if the styling change was intended',
    );
  }

  testWidgets('latin caption, default style', (tester) async {
    await tester.runAsync(() => check('text_latin', const VideoText(id: 'g1', text: 'Hello world')));
  });

  testWidgets('arabic caption, RTL shaping', (tester) async {
    await tester.runAsync(() => check('text_arabic', const VideoText(id: 'g2', text: 'مرحبا بالعالم')));
  });

  testWidgets('caption with background box', (tester) async {
    await tester.runAsync(
      () => check('text_background', const VideoText(id: 'g3', text: 'مغلف بخلفية', backgroundColor: 0xAA000000)),
    );
  });

  testWidgets('small size fraction stays legible', (tester) async {
    await tester.runAsync(
      () => check('text_small', const VideoText(id: 'g4', text: 'Small caption', fontSize: 0.035, bold: false)),
    );
  });
}
