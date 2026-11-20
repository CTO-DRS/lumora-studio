import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/photo_editor/domain/edit_clipboard.dart';
import 'package:lumora/features/photo_editor/domain/edit_history.dart';
import 'package:lumora/features/photo_editor/domain/edit_state.dart';
import 'package:lumora/features/photo_editor/domain/finishing.dart';
import 'package:lumora/features/photo_editor/domain/geometry.dart';
import 'package:lumora/features/photo_editor/domain/layers.dart';

void main() {
  const source = EditState(
    adjustments: Adjustments(exposure: 0.4, saturation: -1),
    presetId: 'noir',
    presetIntensity: 0.6,
    geometry: GeometryState(cropRight: 0.5),
    localAdjustments: [
      LocalAdjustment(id: 'r', kind: MaskKind.radial),
      LocalAdjustment(id: 's', kind: MaskKind.subject, maskPath: '/m.png'),
    ],
    layers: [OverlayLayer.text(id: 't', text: 'hi')],
    frame: FrameSettings(style: FrameStyle.border),
    watermark: WatermarkSettings(text: '©'),
    rasterPath: '/ai.png',
  );

  group('copy / paste edits', () {
    test('clipboard copy drops image specific data', () {
      final c = clipboardCopy(source);
      expect(c.rasterPath, isNull);
      expect(c.localAdjustments.map((m) => m.id), ['r']);
      expect(decodeClipboard(encodeClipboard(c)), c);
      expect(decodeClipboard('nope'), isNull);
    });

    test('default paste: look, masks and finishing; keeps target pixels', () {
      const target = EditState(rasterPath: '/mine.png', geometry: GeometryState(quarterTurns: 1));
      final out = pasteEdit(target, clipboardCopy(source));
      expect(out.adjustments, source.adjustments);
      expect(out.presetId, 'noir');
      expect(out.presetIntensity, 0.6);
      expect(out.rasterPath, '/mine.png');
      expect(out.geometry, target.geometry);
      expect(out.localAdjustments, hasLength(1));
      expect(out.localAdjustments.single.kind, MaskKind.radial);
      expect(out.layers, isEmpty);
      expect(out.frame.style, FrameStyle.border);
      expect(out.watermark?.text, '©');
    });

    test('options select what is pasted', () {
      final out = pasteEdit(
        EditState.initial,
        source,
        options: const PasteOptions(adjustments: false, geometry: true, masks: false, overlays: true, finishing: false),
      );
      expect(out.adjustments, const Adjustments());
      expect(out.geometry.cropRight, 0.5);
      expect(out.localAdjustments, isEmpty);
      expect(out.layers, hasLength(1));
      expect(out.frame.isNone, isTrue);
      // Subject masks are never pasted, even when masks are selected.
      final masks = pasteEdit(EditState.initial, source);
      expect(masks.localAdjustments.every((m) => m.kind != MaskKind.subject), isTrue);
    });

    test('pasting twice gives unique mask ids', () {
      final once = pasteEdit(EditState.initial, source);
      final twice = pasteEdit(once, source);
      final ids = twice.localAdjustments.map((m) => m.id).toSet();
      expect(ids.length, twice.localAdjustments.length);
    });
  });

  group('describeChange', () {
    const base = EditState();
    test('classifies each kind of edit', () {
      expect(describeChange(null, base), EditChange.initial);
      expect(describeChange(base, base.copyWith(rasterPath: '/x')), EditChange.ai);
      expect(describeChange(base, base.copyWith(presetId: 'noir')), EditChange.preset);
      expect(describeChange(base, base.copyWith(geometry: const GeometryState(quarterTurns: 1))), EditChange.crop);
      expect(describeChange(base, base.copyWith(adjustments: const Adjustments(exposure: 1))), EditChange.light);
      expect(describeChange(base, base.copyWith(adjustments: const Adjustments(vibrance: 1))), EditChange.color);
      expect(describeChange(base, base.copyWith(adjustments: const Adjustments(sharpen: 1))), EditChange.detail);
      expect(describeChange(base, base.copyWith(adjustments: const Adjustments(grain: 1))), EditChange.effects);
      expect(describeChange(base, base.copyWith(adjustments: const Adjustments(lutId: 'x'))), EditChange.lut);
      expect(
        describeChange(
          base,
          base.copyWith(
            adjustments: const Adjustments(hsl: HslAdjustments(hue: [1, 0, 0, 0, 0, 0, 0, 0])),
          ),
        ),
        EditChange.hsl,
      );
      expect(
        describeChange(
          base,
          base.copyWith(
            adjustments: const Adjustments(curves: CurveSet(master: [CurvePoint(0, 0.2), CurvePoint(1, 1)])),
          ),
        ),
        EditChange.curves,
      );
      expect(
        describeChange(base, base.copyWith(frame: const FrameSettings(style: FrameStyle.polaroid))),
        EditChange.frame,
      );
      expect(describeChange(base, base.copyWith(watermark: const WatermarkSettings(text: 'a'))), EditChange.watermark);
      expect(
        describeChange(
          base,
          base.copyWith(
            layers: const [OverlayLayer.text(id: 'a', text: 'b')],
          ),
        ),
        EditChange.layers,
      );
    });
  });

  group('EditHistory timeline', () {
    test('jumpTo moves anywhere and keeps every step', () {
      var h = EditHistory(0).push(1).push(2).push(3);
      expect(h.timeline, [0, 1, 2, 3]);
      expect(h.currentIndex, 3);
      h = h.jumpTo(1);
      expect(h.present, 1);
      expect(h.timeline, [0, 1, 2, 3]);
      expect(h.canRedo, isTrue);
      h = h.jumpTo(3);
      expect(h.present, 3);
      expect(h.canRedo, isFalse);
      h = h.jumpTo(0).push(9);
      expect(h.timeline, [0, 9]);
      expect(h.jumpTo(42).present, 9);
    });

    test('timeline includes an uncommitted live change', () {
      final h = EditHistory(0).push(1).replace(5);
      expect(h.timeline, [0, 1, 5]);
      expect(h.currentIndex, 2);
    });
  });
}
