import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumora/core/providers.dart';
import 'package:lumora/features/ai/data/whisper_transcriber_factory.dart';
import 'package:lumora/features/video_editor/engine/caption_service.dart';

/// Builds a [CaptionService] for one run; [language] null = auto-detect.
final captionServiceFactoryProvider = Provider<CaptionService Function(String? language)>((ref) {
  final models = ref.watch(modelManagerProvider);
  final engine = ref.watch(videoEngineProvider);
  return (language) => CaptionService(
    decodeAudio: engine.decodeSpeechAudio,
    openTranscriber: () => openWhisperTiny(models, language: language),
  );
});
