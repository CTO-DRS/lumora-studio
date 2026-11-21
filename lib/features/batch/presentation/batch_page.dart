import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lumora/core/providers.dart';
import 'package:lumora/core/ui/ui.dart';
import 'package:lumora/core/utils/haptics.dart';
import 'package:lumora/core/utils/l10n_ext.dart';
import 'package:lumora/core/widgets/labeled_slider.dart';
import 'package:lumora/features/batch/domain/batch_edit.dart';
import 'package:lumora/features/photo_editor/data/preset_store.dart';
import 'package:lumora/features/photo_editor/domain/auto_enhance.dart';
import 'package:lumora/features/photo_editor/domain/presets.dart';
import 'package:lumora/features/photo_editor/engine/finishing_renderer.dart';
import 'package:lumora/features/photo_editor/engine/image_exporter.dart';
import 'package:lumora/features/photo_editor/engine/pixel_ops.dart' show SocialSize;
import 'package:lumora/features/photo_editor/presentation/photo_editor_page.dart' show socialLabel;
import 'package:lumora/features/settings/data/settings_controller.dart';
import 'package:material_ui/material_ui.dart';

/// Apply one look (a preset, copied edits and/or auto enhance) to many
/// photos and export them all at full resolution.
class BatchPage extends ConsumerStatefulWidget {
  const BatchPage({super.key});

  @override
  ConsumerState<BatchPage> createState() => _BatchPageState();
}

class _BatchPageState extends ConsumerState<BatchPage> {
  final List<String> _paths = [];
  final Map<String, BatchItemStatus> _status = {};
  String? _presetId;
  double _intensity = 1;
  bool _useCopied = false;
  bool _autoEnhance = false;
  SocialSize _size = SocialSize.original;
  ExportFormat? _format;
  bool _running = false;
  bool _cancel = false;
  int _done = 0;

  Future<void> _pick() async {
    final files = await ImagePicker().pickMultiImage();
    if (files.isEmpty) return;
    setState(() {
      for (final f in files) {
        if (!_paths.contains(f.path)) {
          _paths.add(f.path);
          _status[f.path] = BatchItemStatus.pending;
        }
      }
    });
  }

  Future<ImageStats> _stats(String path) async {
    final bytes = await File(path).readAsBytes();
    final desc = await ui.ImageDescriptor.encoded(await ui.ImmutableBuffer.fromUint8List(bytes));
    final k = math.min(1, 512 / math.max(desc.width, desc.height));
    final codec = await desc.instantiateCodec(
      targetWidth: math.max(1, (desc.width * k).round()),
      targetHeight: math.max(1, (desc.height * k).round()),
    );
    final image = (await codec.getNextFrame()).image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    final stats = ImageStats.fromRgba(data!.buffer.asUint8List(), image.width, image.height);
    image.dispose();
    desc.dispose();
    return stats;
  }

  Future<void> _run() async {
    final settings = ref.read(settingsControllerProvider);
    final lib = ref.read(presetLibraryControllerProvider);
    final recipe = BatchRecipe(
      copied: _useCopied ? ref.read(editClipboardProvider) : null,
      preset: lib.byId(_presetId),
      intensity: _intensity,
      autoEnhance: _autoEnhance,
    );
    final options = ExportOptions(
      format: _format ?? settings.exportFormat,
      quality: _size == SocialSize.original ? settings.exportQuality : _size.quality,
      keepExif: settings.keepExif,
      maxDimension: _size == SocialSize.original ? settings.exportMaxDimension : null,
      social: _size,
    );
    setState(() {
      _running = true;
      _cancel = false;
      _done = 0;
    });
    final renderer = await createPhotoRenderer(ref.read);
    final exporter = ImageExporter(renderer);
    final finishing = FinishingRenderer();
    final gallery = await Gal.requestPermission();
    try {
      for (final path in List.of(_paths)) {
        if (_cancel || !mounted) break;
        if (_status[path] == BatchItemStatus.done) {
          _done++;
          continue;
        }
        setState(() => _status[path] = BatchItemStatus.running);
        try {
          final edit = buildBatchEdit(recipe, stats: recipe.autoEnhance ? await _stats(path) : null);
          final rendered = await exporter.renderFullResolution(path, edit);
          final finished = await exporter.finish(rendered, edit, options, finishing);
          final file = await exporter.encodeAndSave(finished, options, exifSourcePath: path);
          if (gallery) await Gal.putImage(file.path, album: 'Lumora');
          _status[path] = BatchItemStatus.done;
        } on Object catch (e) {
          debugPrint('batch $path: $e');
          _status[path] = BatchItemStatus.failed;
        }
        if (mounted) setState(() => _done++);
      }
    } finally {
      finishing.dispose();
      renderer.dispose();
      if (mounted) {
        setState(() => _running = false);
        Haptics.medium();
        final l = context.l10n;
        final ok = _status.values.where((s) => s == BatchItemStatus.done).length;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.batchDone(ok, _paths.length))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final lib = ref.watch(presetLibraryControllerProvider);
    final hasCopied = ref.watch(editClipboardProvider) != null;
    final settings = ref.watch(settingsControllerProvider);
    final presets = [...kBuiltInPresets, ...lib.custom];
    final canRun = _paths.isNotEmpty && !_running && (_presetId != null || (_useCopied && hasCopied) || _autoEnhance);
    return LumoraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: GlassAppBar(title: Text(l.batchEdit)),
        floatingActionButton: _paths.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: _running ? () => setState(() => _cancel = true) : (canRun ? _run : null),
                icon: Icon(_running ? Icons.stop : Icons.play_arrow),
                label: Text(_running ? l.cancel : l.batchStart(_paths.length)),
              ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            if (_running || _done > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(value: _paths.isEmpty ? 0 : _done / _paths.length),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.batchLook, style: Theme.of(context).textTheme.titleSmall),
                    DropdownButton<String?>(
                      isExpanded: true,
                      value: _presetId,
                      items: [
                        DropdownMenuItem(child: Text(l.none)),
                        for (final p in presets) DropdownMenuItem(value: p.id, child: Text(p.name(lang))),
                      ],
                      onChanged: _running ? null : (v) => setState(() => _presetId = v),
                    ),
                    if (_presetId != null)
                      LabeledSlider(
                        label: l.intensity,
                        value: _intensity,
                        min: 0,
                        max: 1,
                        onChanged: (v) => setState(() => _intensity = v),
                      ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.batchUseCopied),
                      subtitle: hasCopied ? null : Text(l.batchNoCopied),
                      value: _useCopied && hasCopied,
                      onChanged: hasCopied && !_running ? (v) => setState(() => _useCopied = v) : null,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.aiAutoEnhance),
                      value: _autoEnhance,
                      onChanged: _running ? null : (v) => setState(() => _autoEnhance = v),
                    ),
                    const Divider(),
                    Text(l.exportSize, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final s in SocialSize.values)
                          ChoiceChip(
                            label: Text(socialLabel(l, s)),
                            selected: _size == s,
                            onSelected: _running ? null : (_) => setState(() => _size = s),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<ExportFormat>(
                      segments: [
                        for (final f in ExportFormat.values)
                          ButtonSegment(value: f, label: Text(f.extension.toUpperCase())),
                      ],
                      selected: {_format ?? settings.exportFormat},
                      onSelectionChanged: _running ? null : (v) => setState(() => _format = v.first),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text(l.batchPhotos(_paths.length), style: Theme.of(context).textTheme.titleMedium)),
                TextButton.icon(
                  onPressed: _running ? null : _pick,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(l.batchAdd),
                ),
              ],
            ),
            if (_paths.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(Icons.burst_mode_outlined, size: 64),
                    const SizedBox(height: 12),
                    Text(l.batchIntro, textAlign: TextAlign.center),
                  ],
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 110,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                itemCount: _paths.length,
                itemBuilder: (context, i) {
                  final path = _paths[i];
                  final status = _status[path] ?? BatchItemStatus.pending;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(File(path), fit: BoxFit.cover, cacheWidth: 240),
                      ),
                      if (status != BatchItemStatus.pending)
                        Center(
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.black54,
                            child: switch (status) {
                              BatchItemStatus.running => const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              BatchItemStatus.done => Icon(Icons.check, color: context.lumora.mint, size: 18),
                              _ => Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 18),
                            },
                          ),
                        ),
                      if (!_running)
                        PositionedDirectional(
                          top: 0,
                          end: 0,
                          child: IconButton(
                            tooltip: l.remove,
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close, size: 16, color: Colors.white),
                            onPressed: () => setState(() {
                              _paths.removeAt(i);
                              _status.remove(path);
                            }),
                          ),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
