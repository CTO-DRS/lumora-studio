// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'photo_editor_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BrushController)
final brushControllerProvider = BrushControllerProvider._();

final class BrushControllerProvider
    extends $NotifierProvider<BrushController, BrushSettings> {
  BrushControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'brushControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$brushControllerHash();

  @$internal
  @override
  BrushController create() => BrushController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BrushSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BrushSettings>(value),
    );
  }
}

String _$brushControllerHash() => r'8311cb586c8e030faf0ea31e1594768073689b5b';

abstract class _$BrushController extends $Notifier<BrushSettings> {
  BrushSettings build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<BrushSettings, BrushSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<BrushSettings, BrushSettings>,
              BrushSettings,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(PhotoEditorController)
final photoEditorControllerProvider = PhotoEditorControllerProvider._();

final class PhotoEditorControllerProvider
    extends $NotifierProvider<PhotoEditorController, PhotoEditorState> {
  PhotoEditorControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'photoEditorControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$photoEditorControllerHash();

  @$internal
  @override
  PhotoEditorController create() => PhotoEditorController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PhotoEditorState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PhotoEditorState>(value),
    );
  }
}

String _$photoEditorControllerHash() =>
    r'1fda89eb701985e8575ec6c2f389290a12cd1436';

abstract class _$PhotoEditorController extends $Notifier<PhotoEditorState> {
  PhotoEditorState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PhotoEditorState, PhotoEditorState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PhotoEditorState, PhotoEditorState>,
              PhotoEditorState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
