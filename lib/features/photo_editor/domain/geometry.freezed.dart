// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'geometry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GeometryState {

 double get cropLeft; double get cropTop; double get cropRight; double get cropBottom; int get quarterTurns; double get straightenDegrees; bool get flipHorizontal; bool get flipVertical; double get perspectiveVertical; double get perspectiveHorizontal; double? get aspectRatio;
/// Create a copy of GeometryState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GeometryStateCopyWith<GeometryState> get copyWith => _$GeometryStateCopyWithImpl<GeometryState>(this as GeometryState, _$identity);

  /// Serializes this GeometryState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as GeometryState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GeometryState&&(identical(other.cropLeft, _this.cropLeft) || other.cropLeft == _this.cropLeft)&&(identical(other.cropTop, _this.cropTop) || other.cropTop == _this.cropTop)&&(identical(other.cropRight, _this.cropRight) || other.cropRight == _this.cropRight)&&(identical(other.cropBottom, _this.cropBottom) || other.cropBottom == _this.cropBottom)&&(identical(other.quarterTurns, _this.quarterTurns) || other.quarterTurns == _this.quarterTurns)&&(identical(other.straightenDegrees, _this.straightenDegrees) || other.straightenDegrees == _this.straightenDegrees)&&(identical(other.flipHorizontal, _this.flipHorizontal) || other.flipHorizontal == _this.flipHorizontal)&&(identical(other.flipVertical, _this.flipVertical) || other.flipVertical == _this.flipVertical)&&(identical(other.perspectiveVertical, _this.perspectiveVertical) || other.perspectiveVertical == _this.perspectiveVertical)&&(identical(other.perspectiveHorizontal, _this.perspectiveHorizontal) || other.perspectiveHorizontal == _this.perspectiveHorizontal)&&(identical(other.aspectRatio, _this.aspectRatio) || other.aspectRatio == _this.aspectRatio));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GeometryState;
  return Object.hash(runtimeType,_this.cropLeft,_this.cropTop,_this.cropRight,_this.cropBottom,_this.quarterTurns,_this.straightenDegrees,_this.flipHorizontal,_this.flipVertical,_this.perspectiveVertical,_this.perspectiveHorizontal,_this.aspectRatio);
}

@override
String toString() {
  final _this = this as GeometryState;
  return 'GeometryState(cropLeft: ${_this.cropLeft}, cropTop: ${_this.cropTop}, cropRight: ${_this.cropRight}, cropBottom: ${_this.cropBottom}, quarterTurns: ${_this.quarterTurns}, straightenDegrees: ${_this.straightenDegrees}, flipHorizontal: ${_this.flipHorizontal}, flipVertical: ${_this.flipVertical}, perspectiveVertical: ${_this.perspectiveVertical}, perspectiveHorizontal: ${_this.perspectiveHorizontal}, aspectRatio: ${_this.aspectRatio})';
}


}

/// @nodoc
abstract mixin class $GeometryStateCopyWith<$Res>  {
  factory $GeometryStateCopyWith(GeometryState value, $Res Function(GeometryState) _then) = _$GeometryStateCopyWithImpl;
@useResult
$Res call({
 double cropLeft, double cropTop, double cropRight, double cropBottom, int quarterTurns, double straightenDegrees, bool flipHorizontal, bool flipVertical, double perspectiveVertical, double perspectiveHorizontal, double? aspectRatio
});




}
/// @nodoc
class _$GeometryStateCopyWithImpl<$Res>
    implements $GeometryStateCopyWith<$Res> {
  _$GeometryStateCopyWithImpl(this._self, this._then);

  final GeometryState _self;
  final $Res Function(GeometryState) _then;

/// Create a copy of GeometryState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? cropLeft = null,Object? cropTop = null,Object? cropRight = null,Object? cropBottom = null,Object? quarterTurns = null,Object? straightenDegrees = null,Object? flipHorizontal = null,Object? flipVertical = null,Object? perspectiveVertical = null,Object? perspectiveHorizontal = null,Object? aspectRatio = freezed,}) {
  return _then(GeometryState(
cropLeft: null == cropLeft ? _self.cropLeft : cropLeft // ignore: cast_nullable_to_non_nullable
as double,cropTop: null == cropTop ? _self.cropTop : cropTop // ignore: cast_nullable_to_non_nullable
as double,cropRight: null == cropRight ? _self.cropRight : cropRight // ignore: cast_nullable_to_non_nullable
as double,cropBottom: null == cropBottom ? _self.cropBottom : cropBottom // ignore: cast_nullable_to_non_nullable
as double,quarterTurns: null == quarterTurns ? _self.quarterTurns : quarterTurns // ignore: cast_nullable_to_non_nullable
as int,straightenDegrees: null == straightenDegrees ? _self.straightenDegrees : straightenDegrees // ignore: cast_nullable_to_non_nullable
as double,flipHorizontal: null == flipHorizontal ? _self.flipHorizontal : flipHorizontal // ignore: cast_nullable_to_non_nullable
as bool,flipVertical: null == flipVertical ? _self.flipVertical : flipVertical // ignore: cast_nullable_to_non_nullable
as bool,perspectiveVertical: null == perspectiveVertical ? _self.perspectiveVertical : perspectiveVertical // ignore: cast_nullable_to_non_nullable
as double,perspectiveHorizontal: null == perspectiveHorizontal ? _self.perspectiveHorizontal : perspectiveHorizontal // ignore: cast_nullable_to_non_nullable
as double,aspectRatio: freezed == aspectRatio ? _self.aspectRatio : aspectRatio // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [GeometryState].
extension GeometryStatePatterns on GeometryState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GeometryState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GeometryState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GeometryState value)  $default,){
final _that = this;
switch (_that) {
case _GeometryState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GeometryState value)?  $default,){
final _that = this;
switch (_that) {
case _GeometryState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double cropLeft,  double cropTop,  double cropRight,  double cropBottom,  int quarterTurns,  double straightenDegrees,  bool flipHorizontal,  bool flipVertical,  double perspectiveVertical,  double perspectiveHorizontal,  double? aspectRatio)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GeometryState() when $default != null:
return $default(_that.cropLeft,_that.cropTop,_that.cropRight,_that.cropBottom,_that.quarterTurns,_that.straightenDegrees,_that.flipHorizontal,_that.flipVertical,_that.perspectiveVertical,_that.perspectiveHorizontal,_that.aspectRatio);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double cropLeft,  double cropTop,  double cropRight,  double cropBottom,  int quarterTurns,  double straightenDegrees,  bool flipHorizontal,  bool flipVertical,  double perspectiveVertical,  double perspectiveHorizontal,  double? aspectRatio)  $default,) {final _that = this;
switch (_that) {
case _GeometryState():
return $default(_that.cropLeft,_that.cropTop,_that.cropRight,_that.cropBottom,_that.quarterTurns,_that.straightenDegrees,_that.flipHorizontal,_that.flipVertical,_that.perspectiveVertical,_that.perspectiveHorizontal,_that.aspectRatio);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double cropLeft,  double cropTop,  double cropRight,  double cropBottom,  int quarterTurns,  double straightenDegrees,  bool flipHorizontal,  bool flipVertical,  double perspectiveVertical,  double perspectiveHorizontal,  double? aspectRatio)?  $default,) {final _that = this;
switch (_that) {
case _GeometryState() when $default != null:
return $default(_that.cropLeft,_that.cropTop,_that.cropRight,_that.cropBottom,_that.quarterTurns,_that.straightenDegrees,_that.flipHorizontal,_that.flipVertical,_that.perspectiveVertical,_that.perspectiveHorizontal,_that.aspectRatio);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GeometryState extends GeometryState {
  const _GeometryState({this.cropLeft = 0, this.cropTop = 0, this.cropRight = 1, this.cropBottom = 1, this.quarterTurns = 0, this.straightenDegrees = 0, this.flipHorizontal = false, this.flipVertical = false, this.perspectiveVertical = 0, this.perspectiveHorizontal = 0, this.aspectRatio}): super._();
  factory _GeometryState.fromJson(Map<String, dynamic> json) => _$GeometryStateFromJson(json);

@override@JsonKey() final  double cropLeft;
@override@JsonKey() final  double cropTop;
@override@JsonKey() final  double cropRight;
@override@JsonKey() final  double cropBottom;
@override@JsonKey() final  int quarterTurns;
@override@JsonKey() final  double straightenDegrees;
@override@JsonKey() final  bool flipHorizontal;
@override@JsonKey() final  bool flipVertical;
@override@JsonKey() final  double perspectiveVertical;
@override@JsonKey() final  double perspectiveHorizontal;
@override final  double? aspectRatio;

/// Create a copy of GeometryState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GeometryStateCopyWith<_GeometryState> get copyWith => __$GeometryStateCopyWithImpl<_GeometryState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GeometryStateToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GeometryState&&(identical(other.cropLeft, cropLeft) || other.cropLeft == cropLeft)&&(identical(other.cropTop, cropTop) || other.cropTop == cropTop)&&(identical(other.cropRight, cropRight) || other.cropRight == cropRight)&&(identical(other.cropBottom, cropBottom) || other.cropBottom == cropBottom)&&(identical(other.quarterTurns, quarterTurns) || other.quarterTurns == quarterTurns)&&(identical(other.straightenDegrees, straightenDegrees) || other.straightenDegrees == straightenDegrees)&&(identical(other.flipHorizontal, flipHorizontal) || other.flipHorizontal == flipHorizontal)&&(identical(other.flipVertical, flipVertical) || other.flipVertical == flipVertical)&&(identical(other.perspectiveVertical, perspectiveVertical) || other.perspectiveVertical == perspectiveVertical)&&(identical(other.perspectiveHorizontal, perspectiveHorizontal) || other.perspectiveHorizontal == perspectiveHorizontal)&&(identical(other.aspectRatio, aspectRatio) || other.aspectRatio == aspectRatio));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,cropLeft,cropTop,cropRight,cropBottom,quarterTurns,straightenDegrees,flipHorizontal,flipVertical,perspectiveVertical,perspectiveHorizontal,aspectRatio);
}

@override
String toString() {
    return 'GeometryState(cropLeft: $cropLeft, cropTop: $cropTop, cropRight: $cropRight, cropBottom: $cropBottom, quarterTurns: $quarterTurns, straightenDegrees: $straightenDegrees, flipHorizontal: $flipHorizontal, flipVertical: $flipVertical, perspectiveVertical: $perspectiveVertical, perspectiveHorizontal: $perspectiveHorizontal, aspectRatio: $aspectRatio)';
}


}

/// @nodoc
abstract mixin class _$GeometryStateCopyWith<$Res> implements $GeometryStateCopyWith<$Res> {
  factory _$GeometryStateCopyWith(_GeometryState value, $Res Function(_GeometryState) _then) = __$GeometryStateCopyWithImpl;
@override @useResult
$Res call({
 double cropLeft, double cropTop, double cropRight, double cropBottom, int quarterTurns, double straightenDegrees, bool flipHorizontal, bool flipVertical, double perspectiveVertical, double perspectiveHorizontal, double? aspectRatio
});




}
/// @nodoc
class __$GeometryStateCopyWithImpl<$Res>
    implements _$GeometryStateCopyWith<$Res> {
  __$GeometryStateCopyWithImpl(this._self, this._then);

  final _GeometryState _self;
  final $Res Function(_GeometryState) _then;

/// Create a copy of GeometryState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? cropLeft = null,Object? cropTop = null,Object? cropRight = null,Object? cropBottom = null,Object? quarterTurns = null,Object? straightenDegrees = null,Object? flipHorizontal = null,Object? flipVertical = null,Object? perspectiveVertical = null,Object? perspectiveHorizontal = null,Object? aspectRatio = freezed,}) {
  return _then(_GeometryState(
cropLeft: null == cropLeft ? _self.cropLeft : cropLeft // ignore: cast_nullable_to_non_nullable
as double,cropTop: null == cropTop ? _self.cropTop : cropTop // ignore: cast_nullable_to_non_nullable
as double,cropRight: null == cropRight ? _self.cropRight : cropRight // ignore: cast_nullable_to_non_nullable
as double,cropBottom: null == cropBottom ? _self.cropBottom : cropBottom // ignore: cast_nullable_to_non_nullable
as double,quarterTurns: null == quarterTurns ? _self.quarterTurns : quarterTurns // ignore: cast_nullable_to_non_nullable
as int,straightenDegrees: null == straightenDegrees ? _self.straightenDegrees : straightenDegrees // ignore: cast_nullable_to_non_nullable
as double,flipHorizontal: null == flipHorizontal ? _self.flipHorizontal : flipHorizontal // ignore: cast_nullable_to_non_nullable
as bool,flipVertical: null == flipVertical ? _self.flipVertical : flipVertical // ignore: cast_nullable_to_non_nullable
as bool,perspectiveVertical: null == perspectiveVertical ? _self.perspectiveVertical : perspectiveVertical // ignore: cast_nullable_to_non_nullable
as double,perspectiveHorizontal: null == perspectiveHorizontal ? _self.perspectiveHorizontal : perspectiveHorizontal // ignore: cast_nullable_to_non_nullable
as double,aspectRatio: freezed == aspectRatio ? _self.aspectRatio : aspectRatio // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

// dart format on
