// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_editor_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(VideoEditorController)
final videoEditorControllerProvider = VideoEditorControllerProvider._();

final class VideoEditorControllerProvider
    extends $NotifierProvider<VideoEditorController, VideoEditorState> {
  VideoEditorControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoEditorControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoEditorControllerHash();

  @$internal
  @override
  VideoEditorController create() => VideoEditorController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoEditorState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoEditorState>(value),
    );
  }
}

String _$videoEditorControllerHash() =>
    r'5dd166f488330669a412ce4875a1819d4e997859';

abstract class _$VideoEditorController extends $Notifier<VideoEditorState> {
  VideoEditorState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<VideoEditorState, VideoEditorState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<VideoEditorState, VideoEditorState>,
              VideoEditorState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
