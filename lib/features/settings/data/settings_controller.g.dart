// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Persisted user preferences (SharedPreferences).

@ProviderFor(SettingsController)
final settingsControllerProvider = SettingsControllerProvider._();

/// Persisted user preferences (SharedPreferences).
final class SettingsControllerProvider extends $NotifierProvider<SettingsController, AppSettings> {
  /// Persisted user preferences (SharedPreferences).
  SettingsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsControllerHash();

  @$internal
  @override
  SettingsController create() => SettingsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppSettings value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<AppSettings>(value));
  }
}

String _$settingsControllerHash() => r'3facda61f747fed87ac9154e304370b1b7883fcb';

/// Persisted user preferences (SharedPreferences).

abstract class _$SettingsController extends $Notifier<AppSettings> {
  AppSettings build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppSettings, AppSettings>;
    final element =
        ref.element as $ClassProviderElement<AnyNotifier<AppSettings, AppSettings>, AppSettings, Object?, Object?>;
    return element.handleCreate(ref, build);
  }
}
