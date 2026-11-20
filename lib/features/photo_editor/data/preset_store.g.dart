// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'preset_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The user's presets and favourites, persisted in SharedPreferences.

@ProviderFor(PresetLibraryController)
final presetLibraryControllerProvider = PresetLibraryControllerProvider._();

/// The user's presets and favourites, persisted in SharedPreferences.
final class PresetLibraryControllerProvider
    extends $NotifierProvider<PresetLibraryController, PresetLibrary> {
  /// The user's presets and favourites, persisted in SharedPreferences.
  PresetLibraryControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'presetLibraryControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$presetLibraryControllerHash();

  @$internal
  @override
  PresetLibraryController create() => PresetLibraryController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PresetLibrary value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PresetLibrary>(value),
    );
  }
}

String _$presetLibraryControllerHash() =>
    r'49aba61a335de530937df1b91c3c1f74c56559a7';

/// The user's presets and favourites, persisted in SharedPreferences.

abstract class _$PresetLibraryController extends $Notifier<PresetLibrary> {
  PresetLibrary build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PresetLibrary, PresetLibrary>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PresetLibrary, PresetLibrary>,
              PresetLibrary,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// "Copy edits" clipboard shared by the editor, batch mode and the home
/// screen. Persisted so a copied look survives an app restart.

@ProviderFor(EditClipboard)
final editClipboardProvider = EditClipboardProvider._();

/// "Copy edits" clipboard shared by the editor, batch mode and the home
/// screen. Persisted so a copied look survives an app restart.
final class EditClipboardProvider
    extends $NotifierProvider<EditClipboard, EditState?> {
  /// "Copy edits" clipboard shared by the editor, batch mode and the home
  /// screen. Persisted so a copied look survives an app restart.
  EditClipboardProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'editClipboardProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$editClipboardHash();

  @$internal
  @override
  EditClipboard create() => EditClipboard();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EditState? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EditState?>(value),
    );
  }
}

String _$editClipboardHash() => r'34ec6001aacd6ec5e8210e03f4544c99a47519ac';

/// "Copy edits" clipboard shared by the editor, batch mode and the home
/// screen. Persisted so a copied look survives an app restart.

abstract class _$EditClipboard extends $Notifier<EditState?> {
  EditState? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<EditState?, EditState?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<EditState?, EditState?>,
              EditState?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
