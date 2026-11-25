import 'package:lumora/features/ai/data/model_manager.dart';
import 'package:lumora/features/ai/data/onnx_engine.dart';
import 'package:lumora/features/ai/data/onnx_whisper_runtime.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:lumora/features/video_editor/domain/captioning.dart';
import 'package:lumora/features/video_editor/domain/whisper_transcriber.dart';
import 'package:lumora/features/video_editor/engine/caption_service.dart';

/// True when the three Whisper files are on the device.
Future<bool> whisperInstalled(ModelManager models) async {
  for (final spec in ModelRegistry.speech) {
    if (!await models.isInstalled(spec)) return false;
  }
  return true;
}

/// Opens Whisper tiny from the installed model files. Throws [AiException]
/// (`notDownloaded`, `session`) with the model named, so the UI can offer
/// the download dialog.
Future<CaptionTranscriberHandle> openWhisperTiny(ModelManager models, {String? language}) async {
  if (!await models.isInstalled(ModelRegistry.whisperTinyVocab)) {
    throw const AiException(AiErrorKind.notDownloaded, model: ModelRegistry.whisperTinyVocab);
  }
  final vocabFile = await models.ensure(ModelRegistry.whisperTinyVocab);
  final Map<int, String> vocab;
  try {
    vocab = parseWhisperVocab(await vocabFile.readAsString());
  } on FormatException catch (e) {
    throw AiException(AiErrorKind.checksum, model: ModelRegistry.whisperTinyVocab, detail: e.message);
  }
  final runtime = await OnnxWhisperRuntime.open(models);
  return _Handle(runtime, WhisperTranscriber(encoder: runtime, decoder: runtime, vocab: vocab, language: language));
}

class _Handle implements CaptionTranscriberHandle {
  _Handle(this._runtime, this.transcriber);
  final OnnxWhisperRuntime _runtime;

  @override
  final AutoTranscriber transcriber;

  @override
  Future<void> close() => _runtime.close();
}
