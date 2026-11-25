import 'package:lumora/features/ai/data/model_manager.dart';
import 'package:lumora/features/ai/data/onnx_engine.dart';
import 'package:lumora/features/ai/pipelines/ai_pipelines.dart';
import 'package:lumora/features/ai/pipelines/face_pipeline.dart';
import 'package:lumora/features/ai/pipelines/sky_pipeline.dart';
import 'package:lumora/features/ai/pipelines/smart_pipelines.dart';
import 'package:lumora/features/photo_editor/engine/lut/lut_repository.dart';
import 'package:lumora/features/photo_editor/engine/photo_renderer.dart';
import 'package:lumora/features/photo_editor/engine/shader_library.dart';
import 'package:lumora/features/projects/data/app_database.dart';
import 'package:lumora/features/projects/data/project_repository.dart';
import 'package:lumora/features/settings/data/settings_controller.dart';
import 'package:lumora/features/video_editor/engine/video_engine.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}

@Riverpod(keepAlive: true)
ProjectRepository projectRepository(Ref ref) => ProjectRepository(ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
Stream<List<ProjectSummary>> recentProjects(Ref ref) => ref.watch(projectRepositoryProvider).watchRecent();

@Riverpod(keepAlive: true)
LutRepository lutRepository(Ref ref) => LutRepository();

@Riverpod(keepAlive: true)
Future<ShaderLibrary> shaderLibrary(Ref ref) => ShaderLibrary.load();

/// Creates a renderer owned by the caller, who must `dispose()` it.
///
/// Prefer this over reading [photoRendererProvider] from a notifier or a
/// callback: an auto-dispose provider that is only `read` is disposed as
/// soon as its future completes, which would free the renderer's GPU
/// textures while it is still in use.
/// Pass `ref.read` (works with both `Ref` and `WidgetRef`).
Future<PhotoRenderer> createPhotoRenderer(T Function<T>(ProviderListenable<T>) read) async =>
    PhotoRenderer(await read(shaderLibraryProvider.future), read(lutRepositoryProvider));

/// A fresh renderer per consumer (each owns its GPU textures). Only for
/// widgets that `watch` it; see [createPhotoRenderer].
@riverpod
Future<PhotoRenderer> photoRenderer(Ref ref) async {
  final shaders = await ref.watch(shaderLibraryProvider.future);
  final renderer = PhotoRenderer(shaders, ref.watch(lutRepositoryProvider));
  ref.onDispose(renderer.dispose);
  return renderer;
}

@Riverpod(keepAlive: true)
ModelManager modelManager(Ref ref) => ModelManager();

@Riverpod(keepAlive: true)
InferenceEngine inferenceEngine(Ref ref) {
  final engine = OnnxInferenceEngine(
    ref.watch(modelManagerProvider),
    // Read on every session load, so toggling the setting takes effect at the
    // next model load (the setter releases the current session).
    accelerated: () => ref.read(settingsControllerProvider).aiAcceleration,
  );
  ref.onDispose(engine.release);
  return engine;
}

@Riverpod(keepAlive: true)
SegmentationPipeline segmentationPipeline(Ref ref) => SegmentationPipeline(ref.watch(inferenceEngineProvider));

@Riverpod(keepAlive: true)
UpscalePipeline upscalePipeline(Ref ref) => UpscalePipeline(ref.watch(inferenceEngineProvider));

@Riverpod(keepAlive: true)
InpaintPipeline inpaintPipeline(Ref ref) => InpaintPipeline(ref.watch(inferenceEngineProvider));

@Riverpod(keepAlive: true)
VideoEngine videoEngine(Ref ref) => VideoEngine();

@Riverpod(keepAlive: true)
ObjectSelectPipeline objectSelectPipeline(Ref ref) => ObjectSelectPipeline(ref.watch(inferenceEngineProvider));

@Riverpod(keepAlive: true)
DepthPipeline depthPipeline(Ref ref) => DepthPipeline(ref.watch(inferenceEngineProvider));

@Riverpod(keepAlive: true)
FaceAnalysisPipeline faceAnalysisPipeline(Ref ref) => FaceAnalysisPipeline(ref.watch(inferenceEngineProvider));

@Riverpod(keepAlive: true)
SkyPipeline skyPipeline(Ref ref) => SkyPipeline(ref.watch(inferenceEngineProvider));
