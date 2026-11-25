import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lumora/core/router/app_router.dart';
import 'package:lumora/core/ui/ui.dart';
import 'package:lumora/core/utils/haptics.dart';
import 'package:lumora/core/utils/l10n_ext.dart';
import 'package:lumora/features/photo_editor/domain/raw/raw_import.dart';
import 'package:material_ui/material_ui.dart';

/// Extensions the photo picker accepts — everyday images plus the RAW
/// formats the W2 pipeline handles (DNG/TIFF) and the ones it reports
/// honestly about.
const _photoPickerExtensions = [
  'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif', 'bmp', 'gif',
  'dng', 'tif', 'tiff',
];

/// Picks a photo (or a RAW/DNG file) and opens it in the editor, optionally
/// running a quick action or applying a look right away.
Future<void> pickAndEditPhoto(BuildContext context, {QuickAction? action, String? presetId}) async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: _photoPickerExtensions,
  );
  if (file?.path == null || !context.mounted) return;
  final sourcePath = file!.path!;

  // RAW path: sniff the header, decode on-device, open the result.
  if (_rawExtension(sourcePath)) {
    // Captured before the async gaps so the honest-failure snackbars never
    // touch a deactivated BuildContext.
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final bytes = await File(sourcePath).readAsBytes();
    if (!looksLikeDng(Uint8List.sublistView(bytes, 0, bytes.length.clamp(0, 4096)))) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.rawImportFailed('not a TIFF/DNG file'))),
      );
      return;
    }
    final result = await importDng(sourcePath);
    if (result is RawImportFailure) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.rawImportFailed(result.message))),
        );
      }
      return;
    }
    final success = result as RawImportSuccess;
    if (context.mounted) {
      if (success.fromPreview) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.rawPreviewOnly)),
        );
      }
      await _pushEditor(context, success.path, action, presetId);
    }
    return;
  }

  await _pushEditor(context, sourcePath, action, presetId);
}

bool _rawExtension(String path) {
  final ext = path.toLowerCase().split('.').last;
  return rawImportExtensions.contains(ext);
}

Future<void> _pushEditor(BuildContext context, String path, QuickAction? action, String? presetId) async {
  await context.push(
    '/photo',
    extra: PhotoEditorArgs(sourcePath: path, initialAction: action, initialPresetId: presetId),
  );
}

/// Picks one or more clips and opens the video editor.
Future<void> pickAndEditVideo(BuildContext context) async {
  final files = await ImagePicker().pickMultiVideo();
  if (files.isNotEmpty && context.mounted) {
    await context.push('/video', extra: VideoEditorArgs(paths: [for (final f in files) f.path]));
  }
}

/// The "Create" sheet of the centre navigation button.
Future<void> showCreateSheet(BuildContext context) async {
  final l = context.l10n;
  final t = context.lumora;
  final entries = <(IconData, Color, String, String, String)>[
    (Icons.photo_outlined, t.violet, l.editPhoto, l.createPhotoSub, 'photo'),
    (Icons.videocam_outlined, t.blue, l.editVideo, l.createVideoSub, 'video'),
    (Icons.dashboard_outlined, t.rose, l.collage, l.createCollageSub, 'collage'),
    (Icons.document_scanner_outlined, t.apricot, l.scanDocument, l.createScanSub, 'scan'),
    (Icons.burst_mode_outlined, t.teal, l.batchEdit, l.createBatchSub, 'batch'),
  ];
  final choice = await showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (c) {
      final theme = Theme.of(c);
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 4, bottom: 12),
                child: Text(l.createTitle, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              ),
              for (final (icon, color, title, subtitle, id) in entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PressScale(
                    child: GlassContainer(
                      radius: 22,
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          onTap: () {
                            Haptics.selection();
                            Navigator.pop(c, id);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                GlowIconOrb(icon: icon, color: color, size: 46),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: t.textMuted)),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: t.textMuted),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case 'photo':
      await pickAndEditPhoto(context);
    case 'video':
      await pickAndEditVideo(context);
    default:
      unawaited(context.push('/$choice'));
  }
}
