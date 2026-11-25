// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseProvider._();

final class AppDatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return appDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$appDatabaseHash() => r'59cce38d45eeaba199eddd097d8e149d66f9f3e1';

@ProviderFor(projectRepository)
final projectRepositoryProvider = ProjectRepositoryProvider._();

final class ProjectRepositoryProvider
    extends
        $FunctionalProvider<
          ProjectRepository,
          ProjectRepository,
          ProjectRepository
        >
    with $Provider<ProjectRepository> {
  ProjectRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'projectRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$projectRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProjectRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProjectRepository create(Ref ref) {
    return projectRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProjectRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProjectRepository>(value),
    );
  }
}

String _$projectRepositoryHash() => r'7800a2430e3bb493c4847d3d27e4cb15c16c46db';

@ProviderFor(recentProjects)
final recentProjectsProvider = RecentProjectsProvider._();

final class RecentProjectsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ProjectSummary>>,
          List<ProjectSummary>,
          Stream<List<ProjectSummary>>
        >
    with
        $FutureModifier<List<ProjectSummary>>,
        $StreamProvider<List<ProjectSummary>> {
  RecentProjectsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recentProjectsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recentProjectsHash();

  @$internal
  @override
  $StreamProviderElement<List<ProjectSummary>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ProjectSummary>> create(Ref ref) {
    return recentProjects(ref);
  }
}

String _$recentProjectsHash() => r'cf3a5525429c95506a665e2b1306e4488b7819ca';

@ProviderFor(lutRepository)
final lutRepositoryProvider = LutRepositoryProvider._();

final class LutRepositoryProvider
    extends $FunctionalProvider<LutRepository, LutRepository, LutRepository>
    with $Provider<LutRepository> {
  LutRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lutRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lutRepositoryHash();

  @$internal
  @override
  $ProviderElement<LutRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LutRepository create(Ref ref) {
    return lutRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LutRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LutRepository>(value),
    );
  }
}

String _$lutRepositoryHash() => r'0422ee758173fb25555fea5424270a4b8b8b4d2a';

@ProviderFor(shaderLibrary)
final shaderLibraryProvider = ShaderLibraryProvider._();

final class ShaderLibraryProvider
    extends
        $FunctionalProvider<
          AsyncValue<ShaderLibrary>,
          ShaderLibrary,
          FutureOr<ShaderLibrary>
        >
    with $FutureModifier<ShaderLibrary>, $FutureProvider<ShaderLibrary> {
  ShaderLibraryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shaderLibraryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shaderLibraryHash();

  @$internal
  @override
  $FutureProviderElement<ShaderLibrary> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ShaderLibrary> create(Ref ref) {
    return shaderLibrary(ref);
  }
}

String _$shaderLibraryHash() => r'3474056021146f2c2baffe5a101dfc7603583ab9';

/// A fresh renderer per consumer (each owns its GPU textures). Only for
/// widgets that `watch` it; see [createPhotoRenderer].

@ProviderFor(photoRenderer)
final photoRendererProvider = PhotoRendererProvider._();

/// A fresh renderer per consumer (each owns its GPU textures). Only for
/// widgets that `watch` it; see [createPhotoRenderer].

final class PhotoRendererProvider
    extends
        $FunctionalProvider<
          AsyncValue<PhotoRenderer>,
          PhotoRenderer,
          FutureOr<PhotoRenderer>
        >
    with $FutureModifier<PhotoRenderer>, $FutureProvider<PhotoRenderer> {
  /// A fresh renderer per consumer (each owns its GPU textures). Only for
  /// widgets that `watch` it; see [createPhotoRenderer].
  PhotoRendererProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'photoRendererProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$photoRendererHash();

  @$internal
  @override
  $FutureProviderElement<PhotoRenderer> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PhotoRenderer> create(Ref ref) {
    return photoRenderer(ref);
  }
}

String _$photoRendererHash() => r'167877c5daf60c7630074556d7a600db9ded3d39';

@ProviderFor(modelManager)
final modelManagerProvider = ModelManagerProvider._();

final class ModelManagerProvider
    extends $FunctionalProvider<ModelManager, ModelManager, ModelManager>
    with $Provider<ModelManager> {
  ModelManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'modelManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$modelManagerHash();

  @$internal
  @override
  $ProviderElement<ModelManager> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ModelManager create(Ref ref) {
    return modelManager(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ModelManager value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ModelManager>(value),
    );
  }
}

String _$modelManagerHash() => r'95d6ad03a96f213a3268a6a0375444d72b125b61';

@ProviderFor(inferenceEngine)
final inferenceEngineProvider = InferenceEngineProvider._();

final class InferenceEngineProvider
    extends
        $FunctionalProvider<InferenceEngine, InferenceEngine, InferenceEngine>
    with $Provider<InferenceEngine> {
  InferenceEngineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inferenceEngineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inferenceEngineHash();

  @$internal
  @override
  $ProviderElement<InferenceEngine> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  InferenceEngine create(Ref ref) {
    return inferenceEngine(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InferenceEngine value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InferenceEngine>(value),
    );
  }
}

String _$inferenceEngineHash() => r'221d6d25d04b5b7651bf1a546f99775e2ccb73b3';

@ProviderFor(segmentationPipeline)
final segmentationPipelineProvider = SegmentationPipelineProvider._();

final class SegmentationPipelineProvider
    extends
        $FunctionalProvider<
          SegmentationPipeline,
          SegmentationPipeline,
          SegmentationPipeline
        >
    with $Provider<SegmentationPipeline> {
  SegmentationPipelineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'segmentationPipelineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$segmentationPipelineHash();

  @$internal
  @override
  $ProviderElement<SegmentationPipeline> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SegmentationPipeline create(Ref ref) {
    return segmentationPipeline(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SegmentationPipeline value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SegmentationPipeline>(value),
    );
  }
}

String _$segmentationPipelineHash() =>
    r'1098f33c9e79eda07036821ed67f1be71520ead0';

@ProviderFor(upscalePipeline)
final upscalePipelineProvider = UpscalePipelineProvider._();

final class UpscalePipelineProvider
    extends
        $FunctionalProvider<UpscalePipeline, UpscalePipeline, UpscalePipeline>
    with $Provider<UpscalePipeline> {
  UpscalePipelineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'upscalePipelineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$upscalePipelineHash();

  @$internal
  @override
  $ProviderElement<UpscalePipeline> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UpscalePipeline create(Ref ref) {
    return upscalePipeline(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpscalePipeline value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpscalePipeline>(value),
    );
  }
}

String _$upscalePipelineHash() => r'84ff447657f5b08d1997df37eedcb231e0516b42';

@ProviderFor(inpaintPipeline)
final inpaintPipelineProvider = InpaintPipelineProvider._();

final class InpaintPipelineProvider
    extends
        $FunctionalProvider<InpaintPipeline, InpaintPipeline, InpaintPipeline>
    with $Provider<InpaintPipeline> {
  InpaintPipelineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inpaintPipelineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inpaintPipelineHash();

  @$internal
  @override
  $ProviderElement<InpaintPipeline> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  InpaintPipeline create(Ref ref) {
    return inpaintPipeline(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InpaintPipeline value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InpaintPipeline>(value),
    );
  }
}

String _$inpaintPipelineHash() => r'4bf926aeeb5a39338ec30ea9a1472afef2dc18db';

@ProviderFor(videoEngine)
final videoEngineProvider = VideoEngineProvider._();

final class VideoEngineProvider
    extends $FunctionalProvider<VideoEngine, VideoEngine, VideoEngine>
    with $Provider<VideoEngine> {
  VideoEngineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoEngineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoEngineHash();

  @$internal
  @override
  $ProviderElement<VideoEngine> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VideoEngine create(Ref ref) {
    return videoEngine(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoEngine value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoEngine>(value),
    );
  }
}

String _$videoEngineHash() => r'e5a1a04d319c277c096c6ddbf0fbb02862da76a0';

@ProviderFor(objectSelectPipeline)
final objectSelectPipelineProvider = ObjectSelectPipelineProvider._();

final class ObjectSelectPipelineProvider
    extends
        $FunctionalProvider<
          ObjectSelectPipeline,
          ObjectSelectPipeline,
          ObjectSelectPipeline
        >
    with $Provider<ObjectSelectPipeline> {
  ObjectSelectPipelineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'objectSelectPipelineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$objectSelectPipelineHash();

  @$internal
  @override
  $ProviderElement<ObjectSelectPipeline> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ObjectSelectPipeline create(Ref ref) {
    return objectSelectPipeline(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ObjectSelectPipeline value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ObjectSelectPipeline>(value),
    );
  }
}

String _$objectSelectPipelineHash() =>
    r'a003dda45ba835164d9b3e8abcace62473461c92';

@ProviderFor(depthPipeline)
final depthPipelineProvider = DepthPipelineProvider._();

final class DepthPipelineProvider
    extends $FunctionalProvider<DepthPipeline, DepthPipeline, DepthPipeline>
    with $Provider<DepthPipeline> {
  DepthPipelineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'depthPipelineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$depthPipelineHash();

  @$internal
  @override
  $ProviderElement<DepthPipeline> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DepthPipeline create(Ref ref) {
    return depthPipeline(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DepthPipeline value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DepthPipeline>(value),
    );
  }
}

String _$depthPipelineHash() => r'24c3c97446f0b93db16ddfff1ace71c32f68df6e';

@ProviderFor(sceneClassifierPipeline)
final sceneClassifierPipelineProvider = SceneClassifierPipelineProvider._();

final class SceneClassifierPipelineProvider
    extends
        $FunctionalProvider<
          SceneClassifierPipeline,
          SceneClassifierPipeline,
          SceneClassifierPipeline
        >
    with $Provider<SceneClassifierPipeline> {
  SceneClassifierPipelineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sceneClassifierPipelineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sceneClassifierPipelineHash();

  @$internal
  @override
  $ProviderElement<SceneClassifierPipeline> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SceneClassifierPipeline create(Ref ref) {
    return sceneClassifierPipeline(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SceneClassifierPipeline value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SceneClassifierPipeline>(value),
    );
  }
}

String _$sceneClassifierPipelineHash() =>
    r'58701b00f286e11ddd597fe56fd4f12acdd031b9';
