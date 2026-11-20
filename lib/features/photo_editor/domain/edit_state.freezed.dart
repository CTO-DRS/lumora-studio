// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'edit_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EditState {

 Adjustments get adjustments; GeometryState get geometry; List<OverlayLayer> get layers; List<LocalAdjustment> get localAdjustments; String? get presetId; double get presetIntensity;/// Result of a destructive AI step (background removal, inpainting,
/// upscaling) stored as a new file. Undo simply restores the previous
/// path, so the AI step itself stays non-destructive.
 String? get rasterPath;
/// Create a copy of EditState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EditStateCopyWith<EditState> get copyWith => _$EditStateCopyWithImpl<EditState>(this as EditState, _$identity);

  /// Serializes this EditState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as EditState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EditState&&(identical(other.adjustments, _this.adjustments) || other.adjustments == _this.adjustments)&&(identical(other.geometry, _this.geometry) || other.geometry == _this.geometry)&&const DeepCollectionEquality().equals(other.layers, _this.layers)&&const DeepCollectionEquality().equals(other.localAdjustments, _this.localAdjustments)&&(identical(other.presetId, _this.presetId) || other.presetId == _this.presetId)&&(identical(other.presetIntensity, _this.presetIntensity) || other.presetIntensity == _this.presetIntensity)&&(identical(other.rasterPath, _this.rasterPath) || other.rasterPath == _this.rasterPath));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as EditState;
  return Object.hash(runtimeType,_this.adjustments,_this.geometry,const DeepCollectionEquality().hash(_this.layers),const DeepCollectionEquality().hash(_this.localAdjustments),_this.presetId,_this.presetIntensity,_this.rasterPath);
}

@override
String toString() {
  final _this = this as EditState;
  return 'EditState(adjustments: ${_this.adjustments}, geometry: ${_this.geometry}, layers: ${_this.layers}, localAdjustments: ${_this.localAdjustments}, presetId: ${_this.presetId}, presetIntensity: ${_this.presetIntensity}, rasterPath: ${_this.rasterPath})';
}


}

/// @nodoc
abstract mixin class $EditStateCopyWith<$Res>  {
  factory $EditStateCopyWith(EditState value, $Res Function(EditState) _then) = _$EditStateCopyWithImpl;
@useResult
$Res call({
 Adjustments adjustments, GeometryState geometry, List<OverlayLayer> layers, List<LocalAdjustment> localAdjustments, String? presetId, double presetIntensity, String? rasterPath
});


$AdjustmentsCopyWith<$Res> get adjustments;$GeometryStateCopyWith<$Res> get geometry;

}
/// @nodoc
class _$EditStateCopyWithImpl<$Res>
    implements $EditStateCopyWith<$Res> {
  _$EditStateCopyWithImpl(this._self, this._then);

  final EditState _self;
  final $Res Function(EditState) _then;

/// Create a copy of EditState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? adjustments = null,Object? geometry = null,Object? layers = null,Object? localAdjustments = null,Object? presetId = freezed,Object? presetIntensity = null,Object? rasterPath = freezed,}) {
  return _then(EditState(
adjustments: null == adjustments ? _self.adjustments : adjustments // ignore: cast_nullable_to_non_nullable
as Adjustments,geometry: null == geometry ? _self.geometry : geometry // ignore: cast_nullable_to_non_nullable
as GeometryState,layers: null == layers ? _self.layers : layers // ignore: cast_nullable_to_non_nullable
as List<OverlayLayer>,localAdjustments: null == localAdjustments ? _self.localAdjustments : localAdjustments // ignore: cast_nullable_to_non_nullable
as List<LocalAdjustment>,presetId: freezed == presetId ? _self.presetId : presetId // ignore: cast_nullable_to_non_nullable
as String?,presetIntensity: null == presetIntensity ? _self.presetIntensity : presetIntensity // ignore: cast_nullable_to_non_nullable
as double,rasterPath: freezed == rasterPath ? _self.rasterPath : rasterPath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of EditState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AdjustmentsCopyWith<$Res> get adjustments {
  
  return $AdjustmentsCopyWith<$Res>(_self.adjustments, (value) {
    return _then(_self.copyWith(adjustments: value));
  });
}/// Create a copy of EditState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeometryStateCopyWith<$Res> get geometry {
  
  return $GeometryStateCopyWith<$Res>(_self.geometry, (value) {
    return _then(_self.copyWith(geometry: value));
  });
}
}


/// Adds pattern-matching-related methods to [EditState].
extension EditStatePatterns on EditState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EditState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EditState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EditState value)  $default,){
final _that = this;
switch (_that) {
case _EditState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EditState value)?  $default,){
final _that = this;
switch (_that) {
case _EditState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Adjustments adjustments,  GeometryState geometry,  List<OverlayLayer> layers,  List<LocalAdjustment> localAdjustments,  String? presetId,  double presetIntensity,  String? rasterPath)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EditState() when $default != null:
return $default(_that.adjustments,_that.geometry,_that.layers,_that.localAdjustments,_that.presetId,_that.presetIntensity,_that.rasterPath);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Adjustments adjustments,  GeometryState geometry,  List<OverlayLayer> layers,  List<LocalAdjustment> localAdjustments,  String? presetId,  double presetIntensity,  String? rasterPath)  $default,) {final _that = this;
switch (_that) {
case _EditState():
return $default(_that.adjustments,_that.geometry,_that.layers,_that.localAdjustments,_that.presetId,_that.presetIntensity,_that.rasterPath);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Adjustments adjustments,  GeometryState geometry,  List<OverlayLayer> layers,  List<LocalAdjustment> localAdjustments,  String? presetId,  double presetIntensity,  String? rasterPath)?  $default,) {final _that = this;
switch (_that) {
case _EditState() when $default != null:
return $default(_that.adjustments,_that.geometry,_that.layers,_that.localAdjustments,_that.presetId,_that.presetIntensity,_that.rasterPath);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EditState extends EditState {
  const _EditState({this.adjustments = const Adjustments(), this.geometry = const GeometryState(),  List<OverlayLayer> layers = const <OverlayLayer>[],  List<LocalAdjustment> localAdjustments = const <LocalAdjustment>[], this.presetId, this.presetIntensity = 1, this.rasterPath}): _layers = layers,_localAdjustments = localAdjustments,super._();
  factory _EditState.fromJson(Map<String, dynamic> json) => _$EditStateFromJson(json);

@override@JsonKey() final  Adjustments adjustments;
@override@JsonKey() final  GeometryState geometry;
 final  List<OverlayLayer> _layers;
@override@JsonKey() List<OverlayLayer> get layers {
  if (_layers is EqualUnmodifiableListView) return _layers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_layers);
}

 final  List<LocalAdjustment> _localAdjustments;
@override@JsonKey() List<LocalAdjustment> get localAdjustments {
  if (_localAdjustments is EqualUnmodifiableListView) return _localAdjustments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_localAdjustments);
}

@override final  String? presetId;
@override@JsonKey() final  double presetIntensity;
/// Result of a destructive AI step (background removal, inpainting,
/// upscaling) stored as a new file. Undo simply restores the previous
/// path, so the AI step itself stays non-destructive.
@override final  String? rasterPath;

/// Create a copy of EditState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EditStateCopyWith<_EditState> get copyWith => __$EditStateCopyWithImpl<_EditState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EditStateToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _EditState&&(identical(other.adjustments, adjustments) || other.adjustments == adjustments)&&(identical(other.geometry, geometry) || other.geometry == geometry)&&const DeepCollectionEquality().equals(other.layers, _layers)&&const DeepCollectionEquality().equals(other.localAdjustments, _localAdjustments)&&(identical(other.presetId, presetId) || other.presetId == presetId)&&(identical(other.presetIntensity, presetIntensity) || other.presetIntensity == presetIntensity)&&(identical(other.rasterPath, rasterPath) || other.rasterPath == rasterPath));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,adjustments,geometry,const DeepCollectionEquality().hash(_layers),const DeepCollectionEquality().hash(_localAdjustments),presetId,presetIntensity,rasterPath);
}

@override
String toString() {
    return 'EditState(adjustments: $adjustments, geometry: $geometry, layers: $layers, localAdjustments: $localAdjustments, presetId: $presetId, presetIntensity: $presetIntensity, rasterPath: $rasterPath)';
}


}

/// @nodoc
abstract mixin class _$EditStateCopyWith<$Res> implements $EditStateCopyWith<$Res> {
  factory _$EditStateCopyWith(_EditState value, $Res Function(_EditState) _then) = __$EditStateCopyWithImpl;
@override @useResult
$Res call({
 Adjustments adjustments, GeometryState geometry, List<OverlayLayer> layers, List<LocalAdjustment> localAdjustments, String? presetId, double presetIntensity, String? rasterPath
});


@override $AdjustmentsCopyWith<$Res> get adjustments;@override $GeometryStateCopyWith<$Res> get geometry;

}
/// @nodoc
class __$EditStateCopyWithImpl<$Res>
    implements _$EditStateCopyWith<$Res> {
  __$EditStateCopyWithImpl(this._self, this._then);

  final _EditState _self;
  final $Res Function(_EditState) _then;

/// Create a copy of EditState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? adjustments = null,Object? geometry = null,Object? layers = null,Object? localAdjustments = null,Object? presetId = freezed,Object? presetIntensity = null,Object? rasterPath = freezed,}) {
  return _then(_EditState(
adjustments: null == adjustments ? _self.adjustments : adjustments // ignore: cast_nullable_to_non_nullable
as Adjustments,geometry: null == geometry ? _self.geometry : geometry // ignore: cast_nullable_to_non_nullable
as GeometryState,layers: null == layers ? _self._layers : layers // ignore: cast_nullable_to_non_nullable
as List<OverlayLayer>,localAdjustments: null == localAdjustments ? _self._localAdjustments : localAdjustments // ignore: cast_nullable_to_non_nullable
as List<LocalAdjustment>,presetId: freezed == presetId ? _self.presetId : presetId // ignore: cast_nullable_to_non_nullable
as String?,presetIntensity: null == presetIntensity ? _self.presetIntensity : presetIntensity // ignore: cast_nullable_to_non_nullable
as double,rasterPath: freezed == rasterPath ? _self.rasterPath : rasterPath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of EditState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AdjustmentsCopyWith<$Res> get adjustments {
  
  return $AdjustmentsCopyWith<$Res>(_self.adjustments, (value) {
    return _then(_self.copyWith(adjustments: value));
  });
}/// Create a copy of EditState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeometryStateCopyWith<$Res> get geometry {
  
  return $GeometryStateCopyWith<$Res>(_self.geometry, (value) {
    return _then(_self.copyWith(geometry: value));
  });
}
}

// dart format on
