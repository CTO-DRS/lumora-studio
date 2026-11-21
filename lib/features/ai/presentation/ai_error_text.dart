import 'package:lumora/features/ai/data/model_manager.dart';
import 'package:lumora/features/ai/data/onnx_engine.dart';
import 'package:lumora/l10n/app_localizations.dart';

/// A plain-language explanation of an AI failure for the user.
///
/// The technical detail goes to the error log (Settings › Error log), not to
/// the snackbar.
String aiErrorText(AppLocalizations l, Object error) {
  final kind = switch (error) {
    AiException(:final kind) => kind,
    ModelChecksumException() => AiErrorKind.checksum,
    OutOfMemoryError() => AiErrorKind.memory,
    _ => null,
  };
  return switch (kind) {
    AiErrorKind.download => l.aiErrDownload,
    AiErrorKind.checksum => l.aiErrChecksum,
    AiErrorKind.notDownloaded => l.aiErrNotDownloaded,
    AiErrorKind.session => l.aiErrSession,
    AiErrorKind.inference => l.aiErrInference,
    AiErrorKind.memory => l.aiErrMemory,
    AiErrorKind.input => l.aiErrInput,
    null => '$error',
  };
}
