import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:lumora/features/photo_editor/domain/edit_state.dart';
import 'package:lumora/features/photo_editor/domain/finishing.dart';
import 'package:lumora/features/photo_editor/engine/pixel_ops.dart';

final _rtl = RegExp(r'[\u0590-\u08FF]');

/// Layout of a watermark inside a `size` image.
class WatermarkLayout {
  const WatermarkLayout({required this.bounds, this.logoRect, this.text, this.textOffset = Offset.zero});

  /// Union of logo and text (without shadow).
  final Rect bounds;
  final Rect? logoRect;
  final TextPainter? text;
  final Offset textOffset;
}

WatermarkLayout layoutWatermark(Size size, WatermarkSettings wm, {Size? logoSize}) {
  final short = math.min(size.width, size.height);
  final fontSize = math.max(6, wm.size * short).toDouble();
  final margin = wm.margin * short;
  final gap = fontSize * 0.4;
  TextPainter? tp;
  if (wm.text.trim().isNotEmpty) {
    tp = TextPainter(
      text: TextSpan(
        text: wm.text,
        style: TextStyle(
          color: Color(wm.color),
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          shadows: wm.shadow
              ? [Shadow(blurRadius: fontSize * 0.2, color: const Color(0x99000000), offset: Offset(0, fontSize * 0.05))]
              : null,
        ),
      ),
      textDirection: _rtl.hasMatch(wm.text) ? TextDirection.rtl : TextDirection.ltr,
    )..layout(maxWidth: size.width - 2 * margin);
  }
  var logoW = 0.0;
  var logoH = 0.0;
  if (logoSize != null && logoSize.height > 0) {
    logoH = fontSize * 1.8;
    logoW = logoH * logoSize.width / logoSize.height;
    final maxW = size.width * 0.5;
    if (logoW > maxW) {
      logoH *= maxW / logoW;
      logoW = maxW;
    }
  }
  final textW = tp?.width ?? 0;
  final textH = tp?.height ?? 0;
  final boxW = logoW + textW + (logoW > 0 && textW > 0 ? gap : 0);
  final boxH = math.max(logoH, textH);
  final (x, y) = anchorWatermark(wm.anchor, size.width, size.height, boxW, boxH, margin);
  final bounds = Rect.fromLTWH(x, y, boxW, boxH);
  return WatermarkLayout(
    bounds: bounds,
    logoRect: logoW > 0 ? Rect.fromLTWH(x, y + (boxH - logoH) / 2, logoW, logoH) : null,
    text: tp,
    textOffset: Offset(x + logoW + (logoW > 0 && textW > 0 ? gap : 0), y + (boxH - textH) / 2),
  );
}

/// Paints [wm] for an image of [size] (shared by preview and export).
void paintWatermark(Canvas canvas, Size size, WatermarkSettings wm, {ui.Image? logo}) {
  if (wm.isEmpty) return;
  final layout = layoutWatermark(
    size,
    wm,
    logoSize: logo == null ? null : Size(logo.width.toDouble(), logo.height.toDouble()),
  );
  final layer = layout.bounds.inflate(math.min(size.width, size.height) * 0.05);
  canvas.saveLayer(layer, Paint()..color = Color.fromRGBO(0, 0, 0, wm.opacity.clamp(0.0, 1.0)));
  final logoRect = layout.logoRect;
  if (logo != null && logoRect != null) {
    canvas.drawImageRect(
      logo,
      Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
      logoRect,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }
  layout.text?.paint(canvas, layout.textOffset);
  canvas.restore();
}

/// Frames and watermarks rendered images. The preview runs on the GPU;
/// full resolution export composes on the CPU ([applyFrame]) and only
/// rasterises the small watermark patch on the GPU, so any image size works.
class FinishingRenderer {
  final Map<String, ui.Image> _logos = {};

  Future<ui.Image?> logoFor(WatermarkSettings? wm) async {
    final path = wm?.logoPath;
    if (path == null) return null;
    final cached = _logos[path];
    if (cached != null) return cached;
    final file = File(path);
    if (!file.existsSync()) return null;
    final codec = await ui.instantiateImageCodec(await file.readAsBytes());
    return _logos[path] = (await codec.getNextFrame()).image;
  }

  void dispose() {
    for (final l in _logos.values) {
      l.dispose();
    }
    _logos.clear();
  }

  /// GPU preview: draws [image] into its frame and paints the watermark.
  /// Returns [image] itself when there is nothing to do.
  ui.Image preview(ui.Image image, EditState s, {ui.Image? logo}) {
    final wm = s.watermark;
    final frame = s.frame;
    final hasWm = wm != null && !wm.isEmpty;
    if (frame.isNone && frame.cornerRadius <= 0 && !hasWm) return image;
    final w = image.width;
    final h = image.height;
    final layout = layoutFrame(w, h, frame);
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    final full = Rect.fromLTWH(0, 0, layout.width.toDouble(), layout.height.toDouble());
    final imgSrc = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
    if (!frame.isNone) {
      if (frame.fill == FrameFill.blur) {
        final k = math.max(layout.width / w, layout.height / h);
        final dst = Rect.fromCenter(center: full.center, width: w * k, height: h * k);
        canvas
          ..save()
          ..clipRect(full);
        final sigma = math.max(layout.width, layout.height) / 40;
        canvas.drawImageRect(
          image,
          imgSrc,
          dst,
          Paint()
            ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.clamp)
            ..colorFilter = const ColorFilter.mode(Color(0x26000000), BlendMode.srcOver),
        );
        canvas.restore();
      } else {
        canvas.drawRect(full, Paint()..color = Color(frame.color));
      }
    }
    final r = layout.imageRect;
    final dst = Rect.fromLTWH(r.left.toDouble(), r.top.toDouble(), w.toDouble(), h.toDouble());
    final radius = frame.cornerRadius * math.min(w, h);
    if (radius > 0) {
      canvas
        ..save()
        ..clipRRect(RRect.fromRectAndRadius(dst, Radius.circular(radius)));
    }
    canvas.drawImageRect(image, imgSrc, dst, Paint()..filterQuality = FilterQuality.none);
    if (radius > 0) canvas.restore();
    if (hasWm) paintWatermark(canvas, full.size, wm, logo: logo);
    final pic = rec.endRecording();
    final out = pic.toImageSync(layout.width, layout.height);
    pic.dispose();
    return out;
  }

  /// Export: applies frame (CPU) and watermark (GPU patch) to [pixels].
  Future<Rgba> finish(Rgba pixels, EditState s) async {
    final frame = s.frame;
    var out = frame.isNone && frame.cornerRadius <= 0 ? pixels : await Isolate.run(() => applyFrame(pixels, frame));
    final wm = s.watermark;
    if (wm == null || wm.isEmpty) return out;
    final logo = await logoFor(wm);
    final size = Size(out.width.toDouble(), out.height.toDouble());
    final layout = layoutWatermark(
      size,
      wm,
      logoSize: logo == null ? null : Size(logo.width.toDouble(), logo.height.toDouble()),
    );
    final inflated = layout.bounds.inflate(math.min(size.width, size.height) * 0.02).intersect(Offset.zero & size);
    final patchRect = Rect.fromLTRB(
      inflated.left.floorToDouble(),
      inflated.top.floorToDouble(),
      inflated.right.ceilToDouble(),
      inflated.bottom.ceilToDouble(),
    );
    if (patchRect.isEmpty) return out;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec)..translate(-patchRect.left, -patchRect.top);
    paintWatermark(canvas, size, wm, logo: logo);
    final pic = rec.endRecording();
    final img = await pic.toImage(patchRect.width.toInt(), patchRect.height.toInt());
    pic.dispose();
    final data = await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    final patchW = img.width;
    final patchH = img.height;
    img.dispose();
    if (data == null) return out;
    final patch = Rgba(patchW, patchH, Uint8List.view(data.buffer));
    if (identical(out, pixels)) out = Rgba(out.width, out.height, Uint8List.fromList(out.data));
    blendPatch(out, patch, patchRect.left.toInt(), patchRect.top.toInt());
    return out;
  }
}
