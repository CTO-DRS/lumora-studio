import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'package:lumora/core/diagnostics/crash_log.dart';
import 'package:lumora/features/ai/data/model_manager.dart';
import 'package:lumora/features/ai/data/onnx_engine.dart';
import 'package:lumora/features/ai/domain/model_registry.dart';
import 'package:lumora/features/video_editor/domain/whisper_transcriber.dart';

/// ONNX Runtime binding for the Whisper encoder and merged decoder graphs
/// (Wave 2 W3-M5). Two sessions live side by side (about 41 MB of weights),
/// so unlike [OnnxInferenceEngine] this keeps both open for the whole
/// captioning job and [close]s them at the end.
///
/// Large tensors never cross the platform channel more than once: the
/// encoder output and the decoder KV cache stay inside the runtime as
/// [OrtValue] handles (wrapped in [WhisperTensor.opaque]) and are fed back
/// as inputs; only the logits of the newest position are copied to Dart.
///
/// The orchestration around this class is covered by unit tests with fakes
/// (`whisper_transcriber_test.dart`); the native calls here are verified
/// against the pinned graphs' real input/output contract with desktop ONNX
/// Runtime, and need an on-device smoke test.
class OnnxWhisperRuntime implements WhisperEncoder, WhisperDecoderGraph {
  OnnxWhisperRuntime._(this._encoder, this._decoder);

  final OrtSession _encoder;
  final OrtSession _decoder;
  Future<void> _queue = Future.value();

  /// Ensures the model files are installed and opens both sessions.
  static Future<OnnxWhisperRuntime> open(ModelManager models, {bool accelerated = false}) async {
    for (final spec in [ModelRegistry.whisperTinyEncoder, ModelRegistry.whisperTinyDecoder]) {
      if (!await models.isInstalled(spec)) {
        throw AiException(AiErrorKind.notDownloaded, model: spec);
      }
    }
    final ort = OnnxRuntime();
    final options = sessionOptionsFor(
      accelerated: false, // Whisper graphs use dynamic shapes: CPU only
      android: Platform.isAndroid,
      apple: Platform.isIOS || Platform.isMacOS,
      cores: Platform.numberOfProcessors,
    );
    OrtSession? enc;
    try {
      final encFile = await models.ensure(ModelRegistry.whisperTinyEncoder);
      final decFile = await models.ensure(ModelRegistry.whisperTinyDecoder);
      CrashLog.instance.breadcrumb('AI: loading Whisper tiny (${options.intraOpNumThreads} threads)');
      enc = await ort.createSession(encFile.path, options: options);
      final dec = await ort.createSession(decFile.path, options: options);
      return OnnxWhisperRuntime._(enc, dec);
    } on Object catch (e) {
      await enc?.close();
      throw AiException(AiErrorKind.session, model: ModelRegistry.whisperTinyDecoder, detail: describeNativeError(e));
    }
  }

  Future<T> _serialized<T>(Future<T> Function() job) {
    final result = _queue.then((_) => job());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  @override
  Future<WhisperTensor> encode(Float32List logMel) => _serialized(() async {
    final input = await OrtValue.fromList(logMel, const [1, 80, 3000]);
    Map<String, OrtValue>? out;
    try {
      out = await _encoder.run({'input_features': input});
      final hidden = out['last_hidden_state'];
      if (hidden == null) throw StateError('encoder returned no last_hidden_state');
      // Drop any extra outputs; keep the hidden states inside the runtime.
      for (final e in out.entries) {
        if (e.key != 'last_hidden_state') await _safeDispose(e.value);
      }
      return WhisperTensor.opaque(hidden, hidden.shape, onDispose: () => _safeDispose(hidden));
    } on Object catch (e) {
      for (final v in out?.values ?? const <OrtValue>[]) {
        await _safeDispose(v);
      }
      throw AiException(AiErrorKind.inference, model: ModelRegistry.whisperTinyEncoder, detail: describeNativeError(e));
    } finally {
      await _safeDispose(input);
    }
  });

  @override
  Future<Map<String, WhisperTensor>> run(Map<String, WhisperTensor> inputs) => _serialized(() async {
    final temporary = <OrtValue>[];
    final feed = <String, OrtValue>{};
    Map<String, OrtValue>? out;
    try {
      for (final e in inputs.entries) {
        final t = e.value;
        final handle = t.handle;
        if (handle is OrtValue) {
          feed[e.key] = handle;
          continue;
        }
        final OrtValue v;
        if (t.floats != null) {
          v = await OrtValue.fromList(t.floats, t.shape);
        } else if (t.ints != null) {
          v = await OrtValue.fromList(t.ints, t.shape);
        } else {
          v = await OrtValue.fromList(<bool>[t.flag ?? false], t.shape);
        }
        temporary.add(v);
        feed[e.key] = v;
      }
      out = await _decoder.run(feed);
      final result = <String, WhisperTensor>{};
      for (final e in out.entries) {
        final v = e.value;
        if (e.key == 'logits') {
          final shape = v.shape;
          final flat = await v.asFlattenedList();
          final data = Float32List(flat.length);
          for (var i = 0; i < flat.length; i++) {
            data[i] = (flat[i] as num).toDouble();
          }
          result[e.key] = WhisperTensor.float(data, shape);
          await _safeDispose(v);
        } else {
          result[e.key] = WhisperTensor.opaque(v, v.shape, onDispose: () => _safeDispose(v));
        }
      }
      return result;
    } on Object catch (e) {
      for (final v in out?.values ?? const <OrtValue>[]) {
        await _safeDispose(v);
      }
      throw AiException(AiErrorKind.inference, model: ModelRegistry.whisperTinyDecoder, detail: describeNativeError(e));
    } finally {
      for (final v in temporary) {
        await _safeDispose(v);
      }
    }
  });

  /// Closes both sessions.
  Future<void> close() => _serialized(() async {
    await _encoder.close();
    await _decoder.close();
  });

  static Future<void> _safeDispose(OrtValue v) async {
    try {
      await v.dispose();
    } on Object catch (_) {
      // Already released.
    }
  }
}
