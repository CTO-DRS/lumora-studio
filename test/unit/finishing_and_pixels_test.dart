import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/photo_editor/domain/color_bands.dart';
import 'package:lumora/features/photo_editor/domain/finishing.dart';
import 'package:lumora/features/photo_editor/domain/histogram.dart';
import 'package:lumora/features/photo_editor/engine/healing.dart';
import 'package:lumora/features/photo_editor/engine/pixel_ops.dart';

Rgba solid(int w, int h, int argb) => Rgba(w, h)..fill(argb);

List<int> px(Rgba img, int x, int y) {
  final o = img.offset(x, y);
  return img.data.sublist(o, o + 4);
}

void main() {
  group('layoutFrame', () {
    test('none is identity', () {
      final l = layoutFrame(400, 300, const FrameSettings());
      expect((l.width, l.height), (400, 300));
      expect(l.isIdentity, isTrue);
    });

    test('border adds the same width on every side', () {
      final l = layoutFrame(400, 300, const FrameSettings(style: FrameStyle.border, width: 0.1));
      expect((l.width, l.height), (460, 360));
      expect((l.imageRect.left, l.imageRect.top), (30, 30));
    });

    test('polaroid has a deep bottom edge', () {
      final l = layoutFrame(400, 400, const FrameSettings(style: FrameStyle.polaroid, width: 0.05));
      expect(l.imageRect.top, 20);
      expect(l.height - l.imageRect.top - 400, 80);
    });

    test('fitAspect pads to the target ratio without cropping', () {
      for (final (w, h, aspect) in [(400, 300, 1.0), (300, 400, 16 / 9), (1000, 500, 4 / 5), (500, 500, 9 / 16)]) {
        final l = layoutFrame(w, h, FrameSettings(style: FrameStyle.fitAspect, width: 0, aspect: aspect));
        expect(l.width / l.height, closeTo(aspect, 0.01), reason: '$w x $h → $aspect');
        expect(l.width, greaterThanOrEqualTo(w));
        expect(l.height, greaterThanOrEqualTo(h));
        expect(l.imageRect.left + w, lessThanOrEqualTo(l.width));
      }
    });
  });

  group('applyFrame (CPU export)', () {
    test('colour border surrounds the untouched photo', () {
      final src = solid(40, 20, 0xFF102030);
      final out = applyFrame(src, const FrameSettings(style: FrameStyle.border, width: 0.25));
      expect((out.width, out.height), (50, 30));
      expect(px(out, 0, 0), [255, 255, 255, 255]);
      expect(px(out, 25, 15), [16, 32, 48, 255]);
    });

    test('rounded corners fade the photo into the frame', () {
      final src = solid(100, 100, 0xFF000000);
      final out = applyFrame(src, const FrameSettings(cornerRadius: 0.2));
      expect((out.width, out.height), (100, 100));
      expect(px(out, 0, 0)[3], 0);
      expect(px(out, 50, 50)[3], 255);
      expect(px(out, 50, 0)[3], 255);
    });

    test('blur fill paints the padding from the photo', () {
      final src = solid(60, 20, 0xFFFF0000);
      final out = applyFrame(
        src,
        const FrameSettings(style: FrameStyle.fitAspect, width: 0, aspect: 1, fill: FrameFill.blur),
      );
      expect(out.width, out.height);
      final corner = px(out, 0, 0);
      expect(corner[0], greaterThan(150));
      expect(corner[1], lessThan(40));
    });
  });

  group('social sizes', () {
    final photo = solid(4000, 3000, 0xFF336699);

    test('fixed aspect sizes produce exact dimensions (pad and crop)', () {
      for (final size in SocialSize.values.where((s) => s.fixedAspect)) {
        for (final fit in SocialFit.values) {
          final out = fitSocial(solid(400, 300, 0xFF336699), size, fit: fit, blur: false);
          expect((out.width, out.height), (size.width, size.height), reason: '$size $fit');
        }
      }
    });

    test('long-edge sizes keep the aspect ratio and never upscale', () {
      final wa = fitSocial(photo, SocialSize.whatsapp);
      expect((wa.width, wa.height), (1600, 1200));
      final small = fitSocial(solid(800, 600, 0), SocialSize.facebook);
      expect((small.width, small.height), (800, 600));
      expect(identical(fitSocial(photo, SocialSize.original), photo), isTrue);
    });

    test('crop keeps the centre', () {
      final img = Rgba(30, 10);
      for (var y = 0; y < 10; y++) {
        for (var x = 0; x < 30; x++) {
          final o = img.offset(x, y);
          img.data[o] = x < 10 || x >= 20 ? 0 : 255;
          img.data[o + 3] = 255;
        }
      }
      final c = cropToAspect(img, 1);
      expect((c.width, c.height), (10, 10));
      for (var i = 0; i < c.data.length; i += 4) {
        expect(c.data[i], 255, reason: 'only the bright middle third remains');
      }
    });
  });

  test('blendPatch alpha-composites and clips at the edges', () {
    final dst = solid(10, 10, 0xFF000000);
    final patch = solid(4, 4, 0x80FFFFFF);
    blendPatch(dst, patch, 8, 8);
    expect(px(dst, 9, 9)[0], inInclusiveRange(126, 130));
    expect(px(dst, 7, 7)[0], 0);
  });

  test('anchorWatermark places boxes on the 3x3 grid', () {
    expect(anchorWatermark(WatermarkAnchor.topLeft, 100, 50, 10, 5, 2), (2.0, 2.0));
    expect(anchorWatermark(WatermarkAnchor.center, 100, 50, 10, 5, 2), (45.0, 22.5));
    expect(anchorWatermark(WatermarkAnchor.bottomRight, 100, 50, 10, 5, 2), (88.0, 43.0));
  });

  group('histogram', () {
    test('counts channels and clipping', () {
      final img = Rgba(10, 10);
      for (var i = 0; i < 100; i++) {
        final v = i < 10 ? 255 : (i < 20 ? 0 : 128);
        img.data.setAll(i * 4, [v, v, v, 255]);
      }
      final h = Histogram.fromRgba(img.data);
      expect(h.pixelCount, 100);
      expect(h.red[255], 10);
      expect(h.luma[128], greaterThan(70));
      expect(h.highlightClip, closeTo(0.1, 1e-9));
      expect(h.shadowClip, closeTo(0.1, 1e-9));
      expect(h.clipsHighlights && h.clipsShadows, isTrue);
      expect(h.meanLuma, closeTo((10 * 255 + 80 * 128) / 100, 1.5));
    });

    test('ignores transparent pixels', () {
      final h = Histogram.fromRgba(Uint8List.fromList([255, 255, 255, 0, 10, 10, 10, 255]));
      expect(h.pixelCount, 1);
      expect(h.clipsHighlights, isFalse);
    });
  });

  test('hslBandForRgb maps colours to the 8 mixer bands', () {
    expect(hslBandForRgb(220, 30, 30), 0);
    expect(hslBandForRgb(240, 140, 30), 1);
    expect(hslBandForRgb(230, 220, 40), 2);
    expect(hslBandForRgb(40, 200, 60), 3);
    expect(hslBandForRgb(40, 200, 210), 4);
    expect(hslBandForRgb(30, 60, 230), 5);
    expect(hslBandForRgb(130, 40, 220), 6);
    expect(hslBandForRgb(220, 40, 180), 7);
    expect(hslBandForRgb(128, 128, 128), 0);
    expect(hueOf(0, 0, 0), isNull);
  });

  group('healing brush', () {
    // Smooth horizontal gradient with fine texture.
    Rgba scene() {
      final img = Rgba(120, 80);
      for (var y = 0; y < 80; y++) {
        for (var x = 0; x < 120; x++) {
          final o = img.offset(x, y);
          final t = 60 + x + ((x * 7 + y * 13) % 5);
          img.data.setAll(o, [t, (t * 0.8).round(), (t * 0.6).round(), 255]);
        }
      }
      return img;
    }

    Uint8List circleMask(int w, int h, int cx, int cy, int r) {
      final m = Uint8List(w * h);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          if ((x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r) m[y * w + x] = 255;
        }
      }
      return m;
    }

    test('heal removes a dark blemish and matches the surroundings', () {
      final clean = scene();
      final dirty = Rgba(120, 80, Uint8List.fromList(clean.data));
      for (var y = 36; y < 44; y++) {
        for (var x = 56; x < 64; x++) {
          dirty.data.setAll(dirty.offset(x, y), [0, 0, 0, 255]);
        }
      }
      final mask = circleMask(120, 80, 60, 40, 7);
      final healed = applyHeal(HealRequest(image: dirty, mask: mask));
      var maxErr = 0;
      for (var y = 36; y < 44; y++) {
        for (var x = 56; x < 64; x++) {
          for (var c = 0; c < 3; c++) {
            final e = (healed.data[healed.offset(x, y) + c] - clean.data[clean.offset(x, y) + c]).abs();
            maxErr = math.max(maxErr, e);
          }
        }
      }
      expect(maxErr, lessThan(12), reason: 'colour corrected texture blends into the gradient');
      // Outside the mask nothing changes.
      expect(px(healed, 5, 5), px(dirty, 5, 5));
    });

    test('source search avoids the painted area and stays inside the image', () {
      final img = scene();
      final mask = circleMask(120, 80, 60, 40, 6);
      final (dx, dy) = findHealSource(img, mask)!;
      expect(dx.abs() + dy.abs(), greaterThan(12));
      expect(60 + dx, inInclusiveRange(0, 119));
      expect(40 + dy, inInclusiveRange(0, 79));
    });

    test('clone copies pixels from the offset unchanged', () {
      final img = scene();
      img.data.setAll(img.offset(20, 20), [1, 2, 3, 255]);
      final mask = Uint8List(120 * 80)..[40 * 120 + 50] = 255;
      final out = applyHeal(HealRequest(image: img, mask: mask, offset: (-30, -20), clone: true));
      expect(px(out, 50, 40), [1, 2, 3, 255]);
    });

    test('empty mask is a no-op', () {
      final img = scene();
      final out = applyHeal(HealRequest(image: img, mask: Uint8List(120 * 80)));
      expect(out.data, img.data);
    });
  });

  test('downscaleBox and resize keep sizes and averages', () {
    final img = solid(100, 50, 0xFF804020);
    final small = downscaleBox(img, 10);
    expect((small.width, small.height), (10, 5));
    expect(px(small, 3, 3), [128, 64, 32, 255]);
    final big = resizeBilinear(small, 33, 17);
    expect((big.width, big.height), (33, 17));
    expect(px(big, 16, 8), [128, 64, 32, 255]);
    final blurred = solid(20, 20, 0xFF808080);
    blurInPlace(blurred, 3);
    expect(px(blurred, 10, 10), [128, 128, 128, 255]);
  });
}
