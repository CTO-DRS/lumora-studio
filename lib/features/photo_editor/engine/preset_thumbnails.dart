import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/photo_editor/domain/edit_state.dart';
import 'package:lumora/features/photo_editor/domain/geometry.dart';
import 'package:lumora/features/photo_editor/domain/presets.dart';
import 'package:lumora/features/photo_editor/engine/photo_renderer.dart';

/// Downscales [image] so its longer side is at most [maxSide] (GPU draw).
ui.Image downscaleImage(ui.Image image, int maxSide) {
  final k = math.min(1, maxSide / math.max(image.width, image.height));
  final w = math.max(1, (image.width * k).round());
  final h = math.max(1, (image.height * k).round());
  final rec = ui.PictureRecorder();
  Canvas(rec).drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..filterQuality = FilterQuality.medium,
  );
  final pic = rec.endRecording();
  final out = pic.toImageSync(w, h);
  pic.dispose();
  return out;
}

/// Live preset thumbnails: the user's own photo (a low-res proxy) rendered
/// through every preset by the real GPU pipeline, on top of the user's
/// current edits without the active preset. Thumbnails render lazily (only
/// those requested), one per frame, and are cached until the photo, the
/// base edit or the crop changes.
class PresetThumbnailCache extends ChangeNotifier {
  PresetThumbnailCache(this._rendererFactory, {this.maxSide = 220});

  final Future<PhotoRenderer> Function() _rendererFactory;
  final int maxSide;

  PhotoRenderer? _renderer;
  ui.Image? _proxy;
  ui.Image? _proxySource;
  Adjustments _base = Adjustments.neutral;
  GeometryState _geometry = const GeometryState();
  final Map<String, ui.Image> _cache = {};
  final List<Preset?> _queue = [];
  final Set<String> _queued = {};
  bool _running = false;
  bool _disposed = false;
  int _generation = 0;

  static const _noneKey = '__none__';

  /// Number of cached thumbnails (for tests and diagnostics).
  int get cachedCount => _cache.length;

  /// Updates the photo and base edit. Clears the cache when they change.
  void update({required ui.Image? preview, required Adjustments base, required GeometryState geometry}) {
    if (_disposed || preview == null) return;
    var invalidate = false;
    if (!identical(preview, _proxySource)) {
      _proxy?.dispose();
      _proxy = downscaleImage(preview, maxSide);
      _proxySource = preview;
      invalidate = true;
    }
    if (base != _base || geometry != _geometry) {
      _base = base;
      _geometry = geometry;
      invalidate = true;
    }
    if (invalidate) _clear();
  }

  void _clear() {
    _generation++;
    for (final img in _cache.values) {
      img.dispose();
    }
    _cache.clear();
    _queue.clear();
    _queued.clear();
  }

  /// Returns the thumbnail for [preset] (`null` = no preset) or schedules it.
  ui.Image? thumbnail(Preset? preset) {
    final key = preset?.id ?? _noneKey;
    final hit = _cache[key];
    if (hit != null) return hit;
    if (_proxy != null && _queued.add(key)) {
      _queue.add(preset);
      unawaited(_pump());
    }
    return null;
  }

  /// The edit a thumbnail renders: base edit + crop, plus [preset].
  EditState stateFor(Preset? preset) =>
      EditState(adjustments: preset == null ? _base : preset.apply(_base), geometry: _geometry);

  Future<void> _pump() async {
    if (_running) return;
    _running = true;
    try {
      final renderer = _renderer ??= await _rendererFactory();
      var sinceNotify = 0;
      while (_queue.isNotEmpty && !_disposed) {
        final generation = _generation;
        final preset = _queue.removeAt(0);
        final key = preset?.id ?? _noneKey;
        final proxy = _proxy;
        if (proxy == null) break;
        final state = stateFor(preset);
        await renderer.prepare(state);
        if (_disposed || generation != _generation) continue;
        final img = renderer.render(proxy, state, includeOverlays: false, includeLocal: false);
        _cache[key]?.dispose();
        _cache[key] = img;
        _queued.remove(key);
        if (++sinceNotify >= 3 || _queue.isEmpty) {
          sinceNotify = 0;
          notifyListeners();
        }
        // Yield so scrolling and slider gestures stay smooth.
        await Future<void>.delayed(Duration.zero);
      }
    } on Object catch (e) {
      debugPrint('Preset thumbnails failed: $e');
    } finally {
      _running = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _clear();
    _proxy?.dispose();
    _proxy = null;
    _renderer?.dispose();
    super.dispose();
  }
}
