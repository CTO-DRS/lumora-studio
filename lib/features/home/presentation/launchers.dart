import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lumora/core/router/app_router.dart';
import 'package:lumora/core/ui/ui.dart';
import 'package:lumora/core/utils/haptics.dart';
import 'package:lumora/core/utils/l10n_ext.dart';
import 'package:material_ui/material_ui.dart';

/// Picks a photo from the gallery and opens it in the editor, optionally
/// running a quick action or applying a look right away.
Future<void> pickAndEditPhoto(BuildContext context, {QuickAction? action, String? presetId}) async {
  final file = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (file != null && context.mounted) {
    await context.push(
      '/photo',
      extra: PhotoEditorArgs(sourcePath: file.path, initialAction: action, initialPresetId: presetId),
    );
  }
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
