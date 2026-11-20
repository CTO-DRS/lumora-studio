import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;

/// A rectangle in unit coordinates (0..1).
@immutable
class UnitRect {
  const UnitRect(this.left, this.top, this.right, this.bottom);
  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;

  @override
  bool operator ==(Object other) =>
      other is UnitRect && other.left == left && other.top == top && other.right == right && other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);
}

/// A pixel rectangle.
class PxRect {
  const PxRect(this.left, this.top, this.width, this.height);
  final double left;
  final double top;
  final double width;
  final double height;
}

class CollageLayout {
  const CollageLayout(this.id, this.cells);
  final String id;
  final List<UnitRect> cells;
}

UnitRect _r(double l, double t, double r, double b) => UnitRect(l, t, r, b);

List<UnitRect> _grid(int cols, int rows) => [
  for (var y = 0; y < rows; y++)
    for (var x = 0; x < cols; x++) _r(x / cols, y / rows, (x + 1) / cols, (y + 1) / rows),
];

/// Built-in layouts for 1–9 photos.
final List<CollageLayout> kCollageLayouts = [
  CollageLayout('1', [_r(0, 0, 1, 1)]),
  CollageLayout('2h', _grid(2, 1)),
  CollageLayout('2v', _grid(1, 2)),
  CollageLayout('2big', [_r(0, 0, 2 / 3, 1), _r(2 / 3, 0, 1, 1)]),
  CollageLayout('3h', _grid(3, 1)),
  CollageLayout('3v', _grid(1, 3)),
  CollageLayout('3left', [_r(0, 0, 0.5, 1), _r(0.5, 0, 1, 0.5), _r(0.5, 0.5, 1, 1)]),
  CollageLayout('3top', [_r(0, 0, 1, 0.5), _r(0, 0.5, 0.5, 1), _r(0.5, 0.5, 1, 1)]),
  CollageLayout('3bottom', [_r(0, 0, 0.5, 0.5), _r(0.5, 0, 1, 0.5), _r(0, 0.5, 1, 1)]),
  CollageLayout('4grid', _grid(2, 2)),
  CollageLayout('4left', [
    _r(0, 0, 2 / 3, 1),
    _r(2 / 3, 0, 1, 1 / 3),
    _r(2 / 3, 1 / 3, 1, 2 / 3),
    _r(2 / 3, 2 / 3, 1, 1),
  ]),
  CollageLayout('4top', [
    _r(0, 0, 1, 2 / 3),
    _r(0, 2 / 3, 1 / 3, 1),
    _r(1 / 3, 2 / 3, 2 / 3, 1),
    _r(2 / 3, 2 / 3, 1, 1),
  ]),
  CollageLayout('4strips', _grid(1, 4)),
  CollageLayout('5mosaic', [
    _r(0, 0, 0.5, 0.5),
    _r(0.5, 0, 1, 0.5),
    _r(0, 0.5, 1 / 3, 1),
    _r(1 / 3, 0.5, 2 / 3, 1),
    _r(2 / 3, 0.5, 1, 1),
  ]),
  CollageLayout('5center', [
    _r(0, 0, 0.5, 0.5),
    _r(0.5, 0, 1, 0.5),
    _r(0, 0.5, 0.5, 1),
    _r(0.5, 0.5, 1, 1),
    _r(0.25, 0.25, 0.75, 0.75),
  ]),
  CollageLayout('6grid', _grid(2, 3)),
  CollageLayout('6wide', _grid(3, 2)),
  CollageLayout('7mosaic', [
    _r(0, 0, 2 / 3, 2 / 3),
    _r(2 / 3, 0, 1, 1 / 3),
    _r(2 / 3, 1 / 3, 1, 2 / 3),
    _r(0, 2 / 3, 1 / 4, 1),
    _r(1 / 4, 2 / 3, 1 / 2, 1),
    _r(1 / 2, 2 / 3, 3 / 4, 1),
    _r(3 / 4, 2 / 3, 1, 1),
  ]),
  CollageLayout('8grid', _grid(2, 4)),
  CollageLayout('9grid', _grid(3, 3)),
];

List<CollageLayout> layoutsFor(int count) {
  final exact = kCollageLayouts.where((l) => l.cells.length == count).toList();
  if (exact.isNotEmpty) return exact;
  final more = kCollageLayouts.where((l) => l.cells.length >= count).toList();
  return more.isEmpty ? [kCollageLayouts.last] : more;
}

CollageLayout layoutById(String id) =>
    kCollageLayouts.firstWhere((l) => l.id == id, orElse: () => kCollageLayouts.first);

/// Pixel rect of [cell] in a `w`×`h` canvas with an outer [margin] and
/// [spacing] between neighbouring cells (both in pixels).
PxRect cellRect(UnitRect cell, double w, double h, {double spacing = 0, double margin = 0}) {
  final iw = w - 2 * margin;
  final ih = h - 2 * margin;
  final half = spacing / 2;
  final l = margin + cell.left * iw + (cell.left > 1e-6 ? half : 0);
  final t = margin + cell.top * ih + (cell.top > 1e-6 ? half : 0);
  final r = margin + cell.right * iw - (cell.right < 1 - 1e-6 ? half : 0);
  final b = margin + cell.bottom * ih - (cell.bottom < 1 - 1e-6 ? half : 0);
  return PxRect(l, t, math.max(1, r - l), math.max(1, b - t));
}

/// Per-cell placement of a photo: zoom ≥ 1 and pan (-1..1 on each axis,
/// 0 = centred) within the cover-fitted image.
class CellTransform {
  const CellTransform({this.scale = 1, this.panX = 0, this.panY = 0});
  final double scale;
  final double panX;
  final double panY;

  CellTransform copyWith({double? scale, double? panX, double? panY}) => CellTransform(
    scale: (scale ?? this.scale).clamp(1.0, 6.0),
    panX: (panX ?? this.panX).clamp(-1.0, 1.0),
    panY: (panY ?? this.panY).clamp(-1.0, 1.0),
  );
}

/// The part of an `imgW`×`imgH` image shown in a `cellW`×`cellH` cell
/// ("cover" fit, then [t]'s zoom and pan). Returns (left, top, width,
/// height) in image pixels.
PxRect coverSource(double imgW, double imgH, double cellW, double cellH, CellTransform t) {
  final cellAspect = cellW / cellH;
  var sw = imgW;
  var sh = imgW / cellAspect;
  if (sh > imgH) {
    sh = imgH;
    sw = imgH * cellAspect;
  }
  sw /= t.scale;
  sh /= t.scale;
  final maxX = (imgW - sw) / 2;
  final maxY = (imgH - sh) / 2;
  final cx = imgW / 2 + t.panX * maxX;
  final cy = imgH / 2 + t.panY * maxY;
  return PxRect(cx - sw / 2, cy - sh / 2, sw, sh);
}

/// Aspect ratios offered for the collage canvas (w / h).
const kCollageAspects = <(String, double)>[
  ('1:1', 1),
  ('4:5', 4 / 5),
  ('9:16', 9 / 16),
  ('16:9', 16 / 9),
  ('3:4', 3 / 4),
];

/// Output pixel size for [aspect] with the long side [longSide].
(int, int) collageOutputSize(double aspect, {int longSide = 3000}) =>
    aspect >= 1 ? (longSide, (longSide / aspect).round()) : ((longSide * aspect).round(), longSide);
