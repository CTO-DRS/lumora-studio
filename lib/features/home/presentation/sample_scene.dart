import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

/// A small procedurally drawn landscape (sky, sun, hills, water) used to
/// preview looks on the Templates tab before the user has picked a photo.
/// Drawn once; nothing is bundled or downloaded.
Future<ui.Image> renderSampleScene({int width = 240, int height = 240}) {
  final w = width.toDouble();
  final h = height.toDouble();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));
  final horizon = h * 0.58;
  canvas
    ..drawRect(
      Rect.fromLTWH(0, 0, w, horizon),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, horizon),
          const [Color(0xFF3B5BA9), Color(0xFF8C7BC4), Color(0xFFF2A97E), Color(0xFFF7D59C)],
          const [0, 0.45, 0.82, 1],
        ),
    )
    ..drawCircle(Offset(w * 0.68, horizon - h * 0.06), h * 0.09, Paint()..color = const Color(0xFFFFF1C9))
    ..drawPath(
      Path()
        ..moveTo(0, horizon)
        ..lineTo(w * 0.18, horizon - h * 0.16)
        ..lineTo(w * 0.34, horizon - h * 0.06)
        ..lineTo(w * 0.5, horizon - h * 0.2)
        ..lineTo(w * 0.72, horizon - h * 0.04)
        ..lineTo(w * 0.86, horizon - h * 0.12)
        ..lineTo(w, horizon - h * 0.03)
        ..lineTo(w, horizon)
        ..close(),
      Paint()..color = const Color(0xFF433E6B),
    )
    ..drawRect(
      Rect.fromLTWH(0, horizon, w, h - horizon),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, horizon),
          Offset(0, h),
          const [Color(0xFFC88E86), Color(0xFF3F5E8C), Color(0xFF1E2C4E)],
          const [0, 0.35, 1],
        ),
    )
    ..drawPath(
      Path()
        ..moveTo(0, h * 0.82)
        ..quadraticBezierTo(w * 0.35, h * 0.7, w * 0.62, h * 0.86)
        ..quadraticBezierTo(w * 0.82, h * 0.96, w, h * 0.88)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = const Color(0xFF2E5940),
    );
  final picture = recorder.endRecording();
  return picture.toImage(width, height).whenComplete(picture.dispose);
}
