// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'adjustments.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CurvePoint {

 double get x; double get y;
/// Create a copy of CurvePoint
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CurvePointCopyWith<CurvePoint> get copyWith => _$CurvePointCopyWithImpl<CurvePoint>(this as CurvePoint, _$identity);

  /// Serializes this CurvePoint to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CurvePoint;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CurvePoint&&(identical(other.x, _this.x) || other.x == _this.x)&&(identical(other.y, _this.y) || other.y == _this.y));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CurvePoint;
  return Object.hash(runtimeType,_this.x,_this.y);
}

@override
String toString() {
  final _this = this as CurvePoint;
  return 'CurvePoint(x: ${_this.x}, y: ${_this.y})';
}


}

/// @nodoc
abstract mixin class $CurvePointCopyWith<$Res>  {
  factory $CurvePointCopyWith(CurvePoint value, $Res Function(CurvePoint) _then) = _$CurvePointCopyWithImpl;
@useResult
$Res call({
 double x, double y
});




}
/// @nodoc
class _$CurvePointCopyWithImpl<$Res>
    implements $CurvePointCopyWith<$Res> {
  _$CurvePointCopyWithImpl(this._self, this._then);

  final CurvePoint _self;
  final $Res Function(CurvePoint) _then;

/// Create a copy of CurvePoint
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? x = null,Object? y = null,}) {
  return _then(CurvePoint(
null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as double,null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [CurvePoint].
extension CurvePointPatterns on CurvePoint {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CurvePoint value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CurvePoint() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CurvePoint value)  $default,){
final _that = this;
switch (_that) {
case _CurvePoint():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CurvePoint value)?  $default,){
final _that = this;
switch (_that) {
case _CurvePoint() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double x,  double y)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CurvePoint() when $default != null:
return $default(_that.x,_that.y);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double x,  double y)  $default,) {final _that = this;
switch (_that) {
case _CurvePoint():
return $default(_that.x,_that.y);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double x,  double y)?  $default,) {final _that = this;
switch (_that) {
case _CurvePoint() when $default != null:
return $default(_that.x,_that.y);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CurvePoint implements CurvePoint {
  const _CurvePoint(this.x, this.y);
  factory _CurvePoint.fromJson(Map<String, dynamic> json) => _$CurvePointFromJson(json);

@override final  double x;
@override final  double y;

/// Create a copy of CurvePoint
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CurvePointCopyWith<_CurvePoint> get copyWith => __$CurvePointCopyWithImpl<_CurvePoint>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CurvePointToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CurvePoint&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,x,y);
}

@override
String toString() {
    return 'CurvePoint(x: $x, y: $y)';
}


}

/// @nodoc
abstract mixin class _$CurvePointCopyWith<$Res> implements $CurvePointCopyWith<$Res> {
  factory _$CurvePointCopyWith(_CurvePoint value, $Res Function(_CurvePoint) _then) = __$CurvePointCopyWithImpl;
@override @useResult
$Res call({
 double x, double y
});




}
/// @nodoc
class __$CurvePointCopyWithImpl<$Res>
    implements _$CurvePointCopyWith<$Res> {
  __$CurvePointCopyWithImpl(this._self, this._then);

  final _CurvePoint _self;
  final $Res Function(_CurvePoint) _then;

/// Create a copy of CurvePoint
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? x = null,Object? y = null,}) {
  return _then(_CurvePoint(
null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as double,null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}


/// @nodoc
mixin _$CurveSet {

 List<CurvePoint> get master; List<CurvePoint> get red; List<CurvePoint> get green; List<CurvePoint> get blue;
/// Create a copy of CurveSet
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CurveSetCopyWith<CurveSet> get copyWith => _$CurveSetCopyWithImpl<CurveSet>(this as CurveSet, _$identity);

  /// Serializes this CurveSet to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CurveSet;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CurveSet&&const DeepCollectionEquality().equals(other.master, _this.master)&&const DeepCollectionEquality().equals(other.red, _this.red)&&const DeepCollectionEquality().equals(other.green, _this.green)&&const DeepCollectionEquality().equals(other.blue, _this.blue));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CurveSet;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.master),const DeepCollectionEquality().hash(_this.red),const DeepCollectionEquality().hash(_this.green),const DeepCollectionEquality().hash(_this.blue));
}

@override
String toString() {
  final _this = this as CurveSet;
  return 'CurveSet(master: ${_this.master}, red: ${_this.red}, green: ${_this.green}, blue: ${_this.blue})';
}


}

/// @nodoc
abstract mixin class $CurveSetCopyWith<$Res>  {
  factory $CurveSetCopyWith(CurveSet value, $Res Function(CurveSet) _then) = _$CurveSetCopyWithImpl;
@useResult
$Res call({
 List<CurvePoint> master, List<CurvePoint> red, List<CurvePoint> green, List<CurvePoint> blue
});




}
/// @nodoc
class _$CurveSetCopyWithImpl<$Res>
    implements $CurveSetCopyWith<$Res> {
  _$CurveSetCopyWithImpl(this._self, this._then);

  final CurveSet _self;
  final $Res Function(CurveSet) _then;

/// Create a copy of CurveSet
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? master = null,Object? red = null,Object? green = null,Object? blue = null,}) {
  return _then(CurveSet(
master: null == master ? _self.master : master // ignore: cast_nullable_to_non_nullable
as List<CurvePoint>,red: null == red ? _self.red : red // ignore: cast_nullable_to_non_nullable
as List<CurvePoint>,green: null == green ? _self.green : green // ignore: cast_nullable_to_non_nullable
as List<CurvePoint>,blue: null == blue ? _self.blue : blue // ignore: cast_nullable_to_non_nullable
as List<CurvePoint>,
  ));
}

}


/// Adds pattern-matching-related methods to [CurveSet].
extension CurveSetPatterns on CurveSet {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CurveSet value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CurveSet() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CurveSet value)  $default,){
final _that = this;
switch (_that) {
case _CurveSet():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CurveSet value)?  $default,){
final _that = this;
switch (_that) {
case _CurveSet() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<CurvePoint> master,  List<CurvePoint> red,  List<CurvePoint> green,  List<CurvePoint> blue)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CurveSet() when $default != null:
return $default(_that.master,_that.red,_that.green,_that.blue);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<CurvePoint> master,  List<CurvePoint> red,  List<CurvePoint> green,  List<CurvePoint> blue)  $default,) {final _that = this;
switch (_that) {
case _CurveSet():
return $default(_that.master,_that.red,_that.green,_that.blue);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<CurvePoint> master,  List<CurvePoint> red,  List<CurvePoint> green,  List<CurvePoint> blue)?  $default,) {final _that = this;
switch (_that) {
case _CurveSet() when $default != null:
return $default(_that.master,_that.red,_that.green,_that.blue);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CurveSet extends CurveSet {
  const _CurveSet({ List<CurvePoint> master = kIdentityCurve,  List<CurvePoint> red = kIdentityCurve,  List<CurvePoint> green = kIdentityCurve,  List<CurvePoint> blue = kIdentityCurve}): _master = master,_red = red,_green = green,_blue = blue,super._();
  factory _CurveSet.fromJson(Map<String, dynamic> json) => _$CurveSetFromJson(json);

 final  List<CurvePoint> _master;
@override@JsonKey() List<CurvePoint> get master {
  if (_master is EqualUnmodifiableListView) return _master;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_master);
}

 final  List<CurvePoint> _red;
@override@JsonKey() List<CurvePoint> get red {
  if (_red is EqualUnmodifiableListView) return _red;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_red);
}

 final  List<CurvePoint> _green;
@override@JsonKey() List<CurvePoint> get green {
  if (_green is EqualUnmodifiableListView) return _green;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_green);
}

 final  List<CurvePoint> _blue;
@override@JsonKey() List<CurvePoint> get blue {
  if (_blue is EqualUnmodifiableListView) return _blue;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_blue);
}


/// Create a copy of CurveSet
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CurveSetCopyWith<_CurveSet> get copyWith => __$CurveSetCopyWithImpl<_CurveSet>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CurveSetToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CurveSet&&const DeepCollectionEquality().equals(other.master, _master)&&const DeepCollectionEquality().equals(other.red, _red)&&const DeepCollectionEquality().equals(other.green, _green)&&const DeepCollectionEquality().equals(other.blue, _blue));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_master),const DeepCollectionEquality().hash(_red),const DeepCollectionEquality().hash(_green),const DeepCollectionEquality().hash(_blue));
}

@override
String toString() {
    return 'CurveSet(master: $master, red: $red, green: $green, blue: $blue)';
}


}

/// @nodoc
abstract mixin class _$CurveSetCopyWith<$Res> implements $CurveSetCopyWith<$Res> {
  factory _$CurveSetCopyWith(_CurveSet value, $Res Function(_CurveSet) _then) = __$CurveSetCopyWithImpl;
@override @useResult
$Res call({
 List<CurvePoint> master, List<CurvePoint> red, List<CurvePoint> green, List<CurvePoint> blue
});




}
/// @nodoc
class __$CurveSetCopyWithImpl<$Res>
    implements _$CurveSetCopyWith<$Res> {
  __$CurveSetCopyWithImpl(this._self, this._then);

  final _CurveSet _self;
  final $Res Function(_CurveSet) _then;

/// Create a copy of CurveSet
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? master = null,Object? red = null,Object? green = null,Object? blue = null,}) {
  return _then(_CurveSet(
master: null == master ? _self._master : master // ignore: cast_nullable_to_non_nullable
as List<CurvePoint>,red: null == red ? _self._red : red // ignore: cast_nullable_to_non_nullable
as List<CurvePoint>,green: null == green ? _self._green : green // ignore: cast_nullable_to_non_nullable
as List<CurvePoint>,blue: null == blue ? _self._blue : blue // ignore: cast_nullable_to_non_nullable
as List<CurvePoint>,
  ));
}


}


/// @nodoc
mixin _$HslAdjustments {

 List<double> get hue; List<double> get saturation; List<double> get luminance;
/// Create a copy of HslAdjustments
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HslAdjustmentsCopyWith<HslAdjustments> get copyWith => _$HslAdjustmentsCopyWithImpl<HslAdjustments>(this as HslAdjustments, _$identity);

  /// Serializes this HslAdjustments to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as HslAdjustments;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HslAdjustments&&const DeepCollectionEquality().equals(other.hue, _this.hue)&&const DeepCollectionEquality().equals(other.saturation, _this.saturation)&&const DeepCollectionEquality().equals(other.luminance, _this.luminance));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as HslAdjustments;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.hue),const DeepCollectionEquality().hash(_this.saturation),const DeepCollectionEquality().hash(_this.luminance));
}

@override
String toString() {
  final _this = this as HslAdjustments;
  return 'HslAdjustments(hue: ${_this.hue}, saturation: ${_this.saturation}, luminance: ${_this.luminance})';
}


}

/// @nodoc
abstract mixin class $HslAdjustmentsCopyWith<$Res>  {
  factory $HslAdjustmentsCopyWith(HslAdjustments value, $Res Function(HslAdjustments) _then) = _$HslAdjustmentsCopyWithImpl;
@useResult
$Res call({
 List<double> hue, List<double> saturation, List<double> luminance
});




}
/// @nodoc
class _$HslAdjustmentsCopyWithImpl<$Res>
    implements $HslAdjustmentsCopyWith<$Res> {
  _$HslAdjustmentsCopyWithImpl(this._self, this._then);

  final HslAdjustments _self;
  final $Res Function(HslAdjustments) _then;

/// Create a copy of HslAdjustments
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hue = null,Object? saturation = null,Object? luminance = null,}) {
  return _then(HslAdjustments(
hue: null == hue ? _self.hue : hue // ignore: cast_nullable_to_non_nullable
as List<double>,saturation: null == saturation ? _self.saturation : saturation // ignore: cast_nullable_to_non_nullable
as List<double>,luminance: null == luminance ? _self.luminance : luminance // ignore: cast_nullable_to_non_nullable
as List<double>,
  ));
}

}


/// Adds pattern-matching-related methods to [HslAdjustments].
extension HslAdjustmentsPatterns on HslAdjustments {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HslAdjustments value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HslAdjustments() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HslAdjustments value)  $default,){
final _that = this;
switch (_that) {
case _HslAdjustments():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HslAdjustments value)?  $default,){
final _that = this;
switch (_that) {
case _HslAdjustments() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<double> hue,  List<double> saturation,  List<double> luminance)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HslAdjustments() when $default != null:
return $default(_that.hue,_that.saturation,_that.luminance);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<double> hue,  List<double> saturation,  List<double> luminance)  $default,) {final _that = this;
switch (_that) {
case _HslAdjustments():
return $default(_that.hue,_that.saturation,_that.luminance);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<double> hue,  List<double> saturation,  List<double> luminance)?  $default,) {final _that = this;
switch (_that) {
case _HslAdjustments() when $default != null:
return $default(_that.hue,_that.saturation,_that.luminance);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _HslAdjustments extends HslAdjustments {
  const _HslAdjustments({ List<double> hue = kZeroBands,  List<double> saturation = kZeroBands,  List<double> luminance = kZeroBands}): _hue = hue,_saturation = saturation,_luminance = luminance,super._();
  factory _HslAdjustments.fromJson(Map<String, dynamic> json) => _$HslAdjustmentsFromJson(json);

 final  List<double> _hue;
@override@JsonKey() List<double> get hue {
  if (_hue is EqualUnmodifiableListView) return _hue;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_hue);
}

 final  List<double> _saturation;
@override@JsonKey() List<double> get saturation {
  if (_saturation is EqualUnmodifiableListView) return _saturation;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_saturation);
}

 final  List<double> _luminance;
@override@JsonKey() List<double> get luminance {
  if (_luminance is EqualUnmodifiableListView) return _luminance;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_luminance);
}


/// Create a copy of HslAdjustments
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HslAdjustmentsCopyWith<_HslAdjustments> get copyWith => __$HslAdjustmentsCopyWithImpl<_HslAdjustments>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HslAdjustmentsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _HslAdjustments&&const DeepCollectionEquality().equals(other.hue, _hue)&&const DeepCollectionEquality().equals(other.saturation, _saturation)&&const DeepCollectionEquality().equals(other.luminance, _luminance));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_hue),const DeepCollectionEquality().hash(_saturation),const DeepCollectionEquality().hash(_luminance));
}

@override
String toString() {
    return 'HslAdjustments(hue: $hue, saturation: $saturation, luminance: $luminance)';
}


}

/// @nodoc
abstract mixin class _$HslAdjustmentsCopyWith<$Res> implements $HslAdjustmentsCopyWith<$Res> {
  factory _$HslAdjustmentsCopyWith(_HslAdjustments value, $Res Function(_HslAdjustments) _then) = __$HslAdjustmentsCopyWithImpl;
@override @useResult
$Res call({
 List<double> hue, List<double> saturation, List<double> luminance
});




}
/// @nodoc
class __$HslAdjustmentsCopyWithImpl<$Res>
    implements _$HslAdjustmentsCopyWith<$Res> {
  __$HslAdjustmentsCopyWithImpl(this._self, this._then);

  final _HslAdjustments _self;
  final $Res Function(_HslAdjustments) _then;

/// Create a copy of HslAdjustments
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hue = null,Object? saturation = null,Object? luminance = null,}) {
  return _then(_HslAdjustments(
hue: null == hue ? _self._hue : hue // ignore: cast_nullable_to_non_nullable
as List<double>,saturation: null == saturation ? _self._saturation : saturation // ignore: cast_nullable_to_non_nullable
as List<double>,luminance: null == luminance ? _self._luminance : luminance // ignore: cast_nullable_to_non_nullable
as List<double>,
  ));
}


}


/// @nodoc
mixin _$SplitTone {

 double get shadowHue; double get shadowSaturation; double get highlightHue; double get highlightSaturation; double get balance;
/// Create a copy of SplitTone
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SplitToneCopyWith<SplitTone> get copyWith => _$SplitToneCopyWithImpl<SplitTone>(this as SplitTone, _$identity);

  /// Serializes this SplitTone to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SplitTone;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SplitTone&&(identical(other.shadowHue, _this.shadowHue) || other.shadowHue == _this.shadowHue)&&(identical(other.shadowSaturation, _this.shadowSaturation) || other.shadowSaturation == _this.shadowSaturation)&&(identical(other.highlightHue, _this.highlightHue) || other.highlightHue == _this.highlightHue)&&(identical(other.highlightSaturation, _this.highlightSaturation) || other.highlightSaturation == _this.highlightSaturation)&&(identical(other.balance, _this.balance) || other.balance == _this.balance));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SplitTone;
  return Object.hash(runtimeType,_this.shadowHue,_this.shadowSaturation,_this.highlightHue,_this.highlightSaturation,_this.balance);
}

@override
String toString() {
  final _this = this as SplitTone;
  return 'SplitTone(shadowHue: ${_this.shadowHue}, shadowSaturation: ${_this.shadowSaturation}, highlightHue: ${_this.highlightHue}, highlightSaturation: ${_this.highlightSaturation}, balance: ${_this.balance})';
}


}

/// @nodoc
abstract mixin class $SplitToneCopyWith<$Res>  {
  factory $SplitToneCopyWith(SplitTone value, $Res Function(SplitTone) _then) = _$SplitToneCopyWithImpl;
@useResult
$Res call({
 double shadowHue, double shadowSaturation, double highlightHue, double highlightSaturation, double balance
});




}
/// @nodoc
class _$SplitToneCopyWithImpl<$Res>
    implements $SplitToneCopyWith<$Res> {
  _$SplitToneCopyWithImpl(this._self, this._then);

  final SplitTone _self;
  final $Res Function(SplitTone) _then;

/// Create a copy of SplitTone
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? shadowHue = null,Object? shadowSaturation = null,Object? highlightHue = null,Object? highlightSaturation = null,Object? balance = null,}) {
  return _then(SplitTone(
shadowHue: null == shadowHue ? _self.shadowHue : shadowHue // ignore: cast_nullable_to_non_nullable
as double,shadowSaturation: null == shadowSaturation ? _self.shadowSaturation : shadowSaturation // ignore: cast_nullable_to_non_nullable
as double,highlightHue: null == highlightHue ? _self.highlightHue : highlightHue // ignore: cast_nullable_to_non_nullable
as double,highlightSaturation: null == highlightSaturation ? _self.highlightSaturation : highlightSaturation // ignore: cast_nullable_to_non_nullable
as double,balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [SplitTone].
extension SplitTonePatterns on SplitTone {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SplitTone value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SplitTone() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SplitTone value)  $default,){
final _that = this;
switch (_that) {
case _SplitTone():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SplitTone value)?  $default,){
final _that = this;
switch (_that) {
case _SplitTone() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double shadowHue,  double shadowSaturation,  double highlightHue,  double highlightSaturation,  double balance)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SplitTone() when $default != null:
return $default(_that.shadowHue,_that.shadowSaturation,_that.highlightHue,_that.highlightSaturation,_that.balance);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double shadowHue,  double shadowSaturation,  double highlightHue,  double highlightSaturation,  double balance)  $default,) {final _that = this;
switch (_that) {
case _SplitTone():
return $default(_that.shadowHue,_that.shadowSaturation,_that.highlightHue,_that.highlightSaturation,_that.balance);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double shadowHue,  double shadowSaturation,  double highlightHue,  double highlightSaturation,  double balance)?  $default,) {final _that = this;
switch (_that) {
case _SplitTone() when $default != null:
return $default(_that.shadowHue,_that.shadowSaturation,_that.highlightHue,_that.highlightSaturation,_that.balance);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SplitTone implements SplitTone {
  const _SplitTone({this.shadowHue = 0.58, this.shadowSaturation = 0, this.highlightHue = 0.08, this.highlightSaturation = 0, this.balance = 0});
  factory _SplitTone.fromJson(Map<String, dynamic> json) => _$SplitToneFromJson(json);

@override@JsonKey() final  double shadowHue;
@override@JsonKey() final  double shadowSaturation;
@override@JsonKey() final  double highlightHue;
@override@JsonKey() final  double highlightSaturation;
@override@JsonKey() final  double balance;

/// Create a copy of SplitTone
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SplitToneCopyWith<_SplitTone> get copyWith => __$SplitToneCopyWithImpl<_SplitTone>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SplitToneToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SplitTone&&(identical(other.shadowHue, shadowHue) || other.shadowHue == shadowHue)&&(identical(other.shadowSaturation, shadowSaturation) || other.shadowSaturation == shadowSaturation)&&(identical(other.highlightHue, highlightHue) || other.highlightHue == highlightHue)&&(identical(other.highlightSaturation, highlightSaturation) || other.highlightSaturation == highlightSaturation)&&(identical(other.balance, balance) || other.balance == balance));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,shadowHue,shadowSaturation,highlightHue,highlightSaturation,balance);
}

@override
String toString() {
    return 'SplitTone(shadowHue: $shadowHue, shadowSaturation: $shadowSaturation, highlightHue: $highlightHue, highlightSaturation: $highlightSaturation, balance: $balance)';
}


}

/// @nodoc
abstract mixin class _$SplitToneCopyWith<$Res> implements $SplitToneCopyWith<$Res> {
  factory _$SplitToneCopyWith(_SplitTone value, $Res Function(_SplitTone) _then) = __$SplitToneCopyWithImpl;
@override @useResult
$Res call({
 double shadowHue, double shadowSaturation, double highlightHue, double highlightSaturation, double balance
});




}
/// @nodoc
class __$SplitToneCopyWithImpl<$Res>
    implements _$SplitToneCopyWith<$Res> {
  __$SplitToneCopyWithImpl(this._self, this._then);

  final _SplitTone _self;
  final $Res Function(_SplitTone) _then;

/// Create a copy of SplitTone
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? shadowHue = null,Object? shadowSaturation = null,Object? highlightHue = null,Object? highlightSaturation = null,Object? balance = null,}) {
  return _then(_SplitTone(
shadowHue: null == shadowHue ? _self.shadowHue : shadowHue // ignore: cast_nullable_to_non_nullable
as double,shadowSaturation: null == shadowSaturation ? _self.shadowSaturation : shadowSaturation // ignore: cast_nullable_to_non_nullable
as double,highlightHue: null == highlightHue ? _self.highlightHue : highlightHue // ignore: cast_nullable_to_non_nullable
as double,highlightSaturation: null == highlightSaturation ? _self.highlightSaturation : highlightSaturation // ignore: cast_nullable_to_non_nullable
as double,balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}


/// @nodoc
mixin _$Duotone {

 double get strength; int get shadowColor; int get highlightColor;
/// Create a copy of Duotone
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DuotoneCopyWith<Duotone> get copyWith => _$DuotoneCopyWithImpl<Duotone>(this as Duotone, _$identity);

  /// Serializes this Duotone to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Duotone;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Duotone&&(identical(other.strength, _this.strength) || other.strength == _this.strength)&&(identical(other.shadowColor, _this.shadowColor) || other.shadowColor == _this.shadowColor)&&(identical(other.highlightColor, _this.highlightColor) || other.highlightColor == _this.highlightColor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Duotone;
  return Object.hash(runtimeType,_this.strength,_this.shadowColor,_this.highlightColor);
}

@override
String toString() {
  final _this = this as Duotone;
  return 'Duotone(strength: ${_this.strength}, shadowColor: ${_this.shadowColor}, highlightColor: ${_this.highlightColor})';
}


}

/// @nodoc
abstract mixin class $DuotoneCopyWith<$Res>  {
  factory $DuotoneCopyWith(Duotone value, $Res Function(Duotone) _then) = _$DuotoneCopyWithImpl;
@useResult
$Res call({
 double strength, int shadowColor, int highlightColor
});




}
/// @nodoc
class _$DuotoneCopyWithImpl<$Res>
    implements $DuotoneCopyWith<$Res> {
  _$DuotoneCopyWithImpl(this._self, this._then);

  final Duotone _self;
  final $Res Function(Duotone) _then;

/// Create a copy of Duotone
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? strength = null,Object? shadowColor = null,Object? highlightColor = null,}) {
  return _then(Duotone(
strength: null == strength ? _self.strength : strength // ignore: cast_nullable_to_non_nullable
as double,shadowColor: null == shadowColor ? _self.shadowColor : shadowColor // ignore: cast_nullable_to_non_nullable
as int,highlightColor: null == highlightColor ? _self.highlightColor : highlightColor // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Duotone].
extension DuotonePatterns on Duotone {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Duotone value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Duotone() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Duotone value)  $default,){
final _that = this;
switch (_that) {
case _Duotone():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Duotone value)?  $default,){
final _that = this;
switch (_that) {
case _Duotone() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double strength,  int shadowColor,  int highlightColor)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Duotone() when $default != null:
return $default(_that.strength,_that.shadowColor,_that.highlightColor);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double strength,  int shadowColor,  int highlightColor)  $default,) {final _that = this;
switch (_that) {
case _Duotone():
return $default(_that.strength,_that.shadowColor,_that.highlightColor);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double strength,  int shadowColor,  int highlightColor)?  $default,) {final _that = this;
switch (_that) {
case _Duotone() when $default != null:
return $default(_that.strength,_that.shadowColor,_that.highlightColor);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Duotone implements Duotone {
  const _Duotone({this.strength = 0, this.shadowColor = 0xFF1B1035, this.highlightColor = 0xFFFFC46B});
  factory _Duotone.fromJson(Map<String, dynamic> json) => _$DuotoneFromJson(json);

@override@JsonKey() final  double strength;
@override@JsonKey() final  int shadowColor;
@override@JsonKey() final  int highlightColor;

/// Create a copy of Duotone
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DuotoneCopyWith<_Duotone> get copyWith => __$DuotoneCopyWithImpl<_Duotone>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DuotoneToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Duotone&&(identical(other.strength, strength) || other.strength == strength)&&(identical(other.shadowColor, shadowColor) || other.shadowColor == shadowColor)&&(identical(other.highlightColor, highlightColor) || other.highlightColor == highlightColor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,strength,shadowColor,highlightColor);
}

@override
String toString() {
    return 'Duotone(strength: $strength, shadowColor: $shadowColor, highlightColor: $highlightColor)';
}


}

/// @nodoc
abstract mixin class _$DuotoneCopyWith<$Res> implements $DuotoneCopyWith<$Res> {
  factory _$DuotoneCopyWith(_Duotone value, $Res Function(_Duotone) _then) = __$DuotoneCopyWithImpl;
@override @useResult
$Res call({
 double strength, int shadowColor, int highlightColor
});




}
/// @nodoc
class __$DuotoneCopyWithImpl<$Res>
    implements _$DuotoneCopyWith<$Res> {
  __$DuotoneCopyWithImpl(this._self, this._then);

  final _Duotone _self;
  final $Res Function(_Duotone) _then;

/// Create a copy of Duotone
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? strength = null,Object? shadowColor = null,Object? highlightColor = null,}) {
  return _then(_Duotone(
strength: null == strength ? _self.strength : strength // ignore: cast_nullable_to_non_nullable
as double,shadowColor: null == shadowColor ? _self.shadowColor : shadowColor // ignore: cast_nullable_to_non_nullable
as int,highlightColor: null == highlightColor ? _self.highlightColor : highlightColor // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$Adjustments {

 double get exposure; double get contrast; double get highlights; double get shadows; double get whites; double get blacks; double get temperature; double get tint; double get vibrance; double get saturation; HslAdjustments get hsl; SplitTone get splitTone; CurveSet get curves; double get fade; double get sharpen; double get clarity; double get structure; double get dehaze; double get blur; double get vignette; double get vignetteMidpoint; double get vignetteRoundness; double get vignetteFeather; double get grain; double get grainSize; double get chromaticAberration; double get glitch; Duotone get duotone; String? get lutId; double get lutIntensity;
/// Create a copy of Adjustments
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AdjustmentsCopyWith<Adjustments> get copyWith => _$AdjustmentsCopyWithImpl<Adjustments>(this as Adjustments, _$identity);

  /// Serializes this Adjustments to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Adjustments;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Adjustments&&(identical(other.exposure, _this.exposure) || other.exposure == _this.exposure)&&(identical(other.contrast, _this.contrast) || other.contrast == _this.contrast)&&(identical(other.highlights, _this.highlights) || other.highlights == _this.highlights)&&(identical(other.shadows, _this.shadows) || other.shadows == _this.shadows)&&(identical(other.whites, _this.whites) || other.whites == _this.whites)&&(identical(other.blacks, _this.blacks) || other.blacks == _this.blacks)&&(identical(other.temperature, _this.temperature) || other.temperature == _this.temperature)&&(identical(other.tint, _this.tint) || other.tint == _this.tint)&&(identical(other.vibrance, _this.vibrance) || other.vibrance == _this.vibrance)&&(identical(other.saturation, _this.saturation) || other.saturation == _this.saturation)&&(identical(other.hsl, _this.hsl) || other.hsl == _this.hsl)&&(identical(other.splitTone, _this.splitTone) || other.splitTone == _this.splitTone)&&(identical(other.curves, _this.curves) || other.curves == _this.curves)&&(identical(other.fade, _this.fade) || other.fade == _this.fade)&&(identical(other.sharpen, _this.sharpen) || other.sharpen == _this.sharpen)&&(identical(other.clarity, _this.clarity) || other.clarity == _this.clarity)&&(identical(other.structure, _this.structure) || other.structure == _this.structure)&&(identical(other.dehaze, _this.dehaze) || other.dehaze == _this.dehaze)&&(identical(other.blur, _this.blur) || other.blur == _this.blur)&&(identical(other.vignette, _this.vignette) || other.vignette == _this.vignette)&&(identical(other.vignetteMidpoint, _this.vignetteMidpoint) || other.vignetteMidpoint == _this.vignetteMidpoint)&&(identical(other.vignetteRoundness, _this.vignetteRoundness) || other.vignetteRoundness == _this.vignetteRoundness)&&(identical(other.vignetteFeather, _this.vignetteFeather) || other.vignetteFeather == _this.vignetteFeather)&&(identical(other.grain, _this.grain) || other.grain == _this.grain)&&(identical(other.grainSize, _this.grainSize) || other.grainSize == _this.grainSize)&&(identical(other.chromaticAberration, _this.chromaticAberration) || other.chromaticAberration == _this.chromaticAberration)&&(identical(other.glitch, _this.glitch) || other.glitch == _this.glitch)&&(identical(other.duotone, _this.duotone) || other.duotone == _this.duotone)&&(identical(other.lutId, _this.lutId) || other.lutId == _this.lutId)&&(identical(other.lutIntensity, _this.lutIntensity) || other.lutIntensity == _this.lutIntensity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Adjustments;
  return Object.hashAll([runtimeType,_this.exposure,_this.contrast,_this.highlights,_this.shadows,_this.whites,_this.blacks,_this.temperature,_this.tint,_this.vibrance,_this.saturation,_this.hsl,_this.splitTone,_this.curves,_this.fade,_this.sharpen,_this.clarity,_this.structure,_this.dehaze,_this.blur,_this.vignette,_this.vignetteMidpoint,_this.vignetteRoundness,_this.vignetteFeather,_this.grain,_this.grainSize,_this.chromaticAberration,_this.glitch,_this.duotone,_this.lutId,_this.lutIntensity]);
}

@override
String toString() {
  final _this = this as Adjustments;
  return 'Adjustments(exposure: ${_this.exposure}, contrast: ${_this.contrast}, highlights: ${_this.highlights}, shadows: ${_this.shadows}, whites: ${_this.whites}, blacks: ${_this.blacks}, temperature: ${_this.temperature}, tint: ${_this.tint}, vibrance: ${_this.vibrance}, saturation: ${_this.saturation}, hsl: ${_this.hsl}, splitTone: ${_this.splitTone}, curves: ${_this.curves}, fade: ${_this.fade}, sharpen: ${_this.sharpen}, clarity: ${_this.clarity}, structure: ${_this.structure}, dehaze: ${_this.dehaze}, blur: ${_this.blur}, vignette: ${_this.vignette}, vignetteMidpoint: ${_this.vignetteMidpoint}, vignetteRoundness: ${_this.vignetteRoundness}, vignetteFeather: ${_this.vignetteFeather}, grain: ${_this.grain}, grainSize: ${_this.grainSize}, chromaticAberration: ${_this.chromaticAberration}, glitch: ${_this.glitch}, duotone: ${_this.duotone}, lutId: ${_this.lutId}, lutIntensity: ${_this.lutIntensity})';
}


}

/// @nodoc
abstract mixin class $AdjustmentsCopyWith<$Res>  {
  factory $AdjustmentsCopyWith(Adjustments value, $Res Function(Adjustments) _then) = _$AdjustmentsCopyWithImpl;
@useResult
$Res call({
 double exposure, double contrast, double highlights, double shadows, double whites, double blacks, double temperature, double tint, double vibrance, double saturation, HslAdjustments hsl, SplitTone splitTone, CurveSet curves, double fade, double sharpen, double clarity, double structure, double dehaze, double blur, double vignette, double vignetteMidpoint, double vignetteRoundness, double vignetteFeather, double grain, double grainSize, double chromaticAberration, double glitch, Duotone duotone, String? lutId, double lutIntensity
});


$HslAdjustmentsCopyWith<$Res> get hsl;$SplitToneCopyWith<$Res> get splitTone;$CurveSetCopyWith<$Res> get curves;$DuotoneCopyWith<$Res> get duotone;

}
/// @nodoc
class _$AdjustmentsCopyWithImpl<$Res>
    implements $AdjustmentsCopyWith<$Res> {
  _$AdjustmentsCopyWithImpl(this._self, this._then);

  final Adjustments _self;
  final $Res Function(Adjustments) _then;

/// Create a copy of Adjustments
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? exposure = null,Object? contrast = null,Object? highlights = null,Object? shadows = null,Object? whites = null,Object? blacks = null,Object? temperature = null,Object? tint = null,Object? vibrance = null,Object? saturation = null,Object? hsl = null,Object? splitTone = null,Object? curves = null,Object? fade = null,Object? sharpen = null,Object? clarity = null,Object? structure = null,Object? dehaze = null,Object? blur = null,Object? vignette = null,Object? vignetteMidpoint = null,Object? vignetteRoundness = null,Object? vignetteFeather = null,Object? grain = null,Object? grainSize = null,Object? chromaticAberration = null,Object? glitch = null,Object? duotone = null,Object? lutId = freezed,Object? lutIntensity = null,}) {
  return _then(Adjustments(
exposure: null == exposure ? _self.exposure : exposure // ignore: cast_nullable_to_non_nullable
as double,contrast: null == contrast ? _self.contrast : contrast // ignore: cast_nullable_to_non_nullable
as double,highlights: null == highlights ? _self.highlights : highlights // ignore: cast_nullable_to_non_nullable
as double,shadows: null == shadows ? _self.shadows : shadows // ignore: cast_nullable_to_non_nullable
as double,whites: null == whites ? _self.whites : whites // ignore: cast_nullable_to_non_nullable
as double,blacks: null == blacks ? _self.blacks : blacks // ignore: cast_nullable_to_non_nullable
as double,temperature: null == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double,tint: null == tint ? _self.tint : tint // ignore: cast_nullable_to_non_nullable
as double,vibrance: null == vibrance ? _self.vibrance : vibrance // ignore: cast_nullable_to_non_nullable
as double,saturation: null == saturation ? _self.saturation : saturation // ignore: cast_nullable_to_non_nullable
as double,hsl: null == hsl ? _self.hsl : hsl // ignore: cast_nullable_to_non_nullable
as HslAdjustments,splitTone: null == splitTone ? _self.splitTone : splitTone // ignore: cast_nullable_to_non_nullable
as SplitTone,curves: null == curves ? _self.curves : curves // ignore: cast_nullable_to_non_nullable
as CurveSet,fade: null == fade ? _self.fade : fade // ignore: cast_nullable_to_non_nullable
as double,sharpen: null == sharpen ? _self.sharpen : sharpen // ignore: cast_nullable_to_non_nullable
as double,clarity: null == clarity ? _self.clarity : clarity // ignore: cast_nullable_to_non_nullable
as double,structure: null == structure ? _self.structure : structure // ignore: cast_nullable_to_non_nullable
as double,dehaze: null == dehaze ? _self.dehaze : dehaze // ignore: cast_nullable_to_non_nullable
as double,blur: null == blur ? _self.blur : blur // ignore: cast_nullable_to_non_nullable
as double,vignette: null == vignette ? _self.vignette : vignette // ignore: cast_nullable_to_non_nullable
as double,vignetteMidpoint: null == vignetteMidpoint ? _self.vignetteMidpoint : vignetteMidpoint // ignore: cast_nullable_to_non_nullable
as double,vignetteRoundness: null == vignetteRoundness ? _self.vignetteRoundness : vignetteRoundness // ignore: cast_nullable_to_non_nullable
as double,vignetteFeather: null == vignetteFeather ? _self.vignetteFeather : vignetteFeather // ignore: cast_nullable_to_non_nullable
as double,grain: null == grain ? _self.grain : grain // ignore: cast_nullable_to_non_nullable
as double,grainSize: null == grainSize ? _self.grainSize : grainSize // ignore: cast_nullable_to_non_nullable
as double,chromaticAberration: null == chromaticAberration ? _self.chromaticAberration : chromaticAberration // ignore: cast_nullable_to_non_nullable
as double,glitch: null == glitch ? _self.glitch : glitch // ignore: cast_nullable_to_non_nullable
as double,duotone: null == duotone ? _self.duotone : duotone // ignore: cast_nullable_to_non_nullable
as Duotone,lutId: freezed == lutId ? _self.lutId : lutId // ignore: cast_nullable_to_non_nullable
as String?,lutIntensity: null == lutIntensity ? _self.lutIntensity : lutIntensity // ignore: cast_nullable_to_non_nullable
as double,
  ));
}
/// Create a copy of Adjustments
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$HslAdjustmentsCopyWith<$Res> get hsl {
  
  return $HslAdjustmentsCopyWith<$Res>(_self.hsl, (value) {
    return _then(_self.copyWith(hsl: value));
  });
}/// Create a copy of Adjustments
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SplitToneCopyWith<$Res> get splitTone {
  
  return $SplitToneCopyWith<$Res>(_self.splitTone, (value) {
    return _then(_self.copyWith(splitTone: value));
  });
}/// Create a copy of Adjustments
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CurveSetCopyWith<$Res> get curves {
  
  return $CurveSetCopyWith<$Res>(_self.curves, (value) {
    return _then(_self.copyWith(curves: value));
  });
}/// Create a copy of Adjustments
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DuotoneCopyWith<$Res> get duotone {
  
  return $DuotoneCopyWith<$Res>(_self.duotone, (value) {
    return _then(_self.copyWith(duotone: value));
  });
}
}


/// Adds pattern-matching-related methods to [Adjustments].
extension AdjustmentsPatterns on Adjustments {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Adjustments value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Adjustments() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Adjustments value)  $default,){
final _that = this;
switch (_that) {
case _Adjustments():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Adjustments value)?  $default,){
final _that = this;
switch (_that) {
case _Adjustments() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double exposure,  double contrast,  double highlights,  double shadows,  double whites,  double blacks,  double temperature,  double tint,  double vibrance,  double saturation,  HslAdjustments hsl,  SplitTone splitTone,  CurveSet curves,  double fade,  double sharpen,  double clarity,  double structure,  double dehaze,  double blur,  double vignette,  double vignetteMidpoint,  double vignetteRoundness,  double vignetteFeather,  double grain,  double grainSize,  double chromaticAberration,  double glitch,  Duotone duotone,  String? lutId,  double lutIntensity)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Adjustments() when $default != null:
return $default(_that.exposure,_that.contrast,_that.highlights,_that.shadows,_that.whites,_that.blacks,_that.temperature,_that.tint,_that.vibrance,_that.saturation,_that.hsl,_that.splitTone,_that.curves,_that.fade,_that.sharpen,_that.clarity,_that.structure,_that.dehaze,_that.blur,_that.vignette,_that.vignetteMidpoint,_that.vignetteRoundness,_that.vignetteFeather,_that.grain,_that.grainSize,_that.chromaticAberration,_that.glitch,_that.duotone,_that.lutId,_that.lutIntensity);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double exposure,  double contrast,  double highlights,  double shadows,  double whites,  double blacks,  double temperature,  double tint,  double vibrance,  double saturation,  HslAdjustments hsl,  SplitTone splitTone,  CurveSet curves,  double fade,  double sharpen,  double clarity,  double structure,  double dehaze,  double blur,  double vignette,  double vignetteMidpoint,  double vignetteRoundness,  double vignetteFeather,  double grain,  double grainSize,  double chromaticAberration,  double glitch,  Duotone duotone,  String? lutId,  double lutIntensity)  $default,) {final _that = this;
switch (_that) {
case _Adjustments():
return $default(_that.exposure,_that.contrast,_that.highlights,_that.shadows,_that.whites,_that.blacks,_that.temperature,_that.tint,_that.vibrance,_that.saturation,_that.hsl,_that.splitTone,_that.curves,_that.fade,_that.sharpen,_that.clarity,_that.structure,_that.dehaze,_that.blur,_that.vignette,_that.vignetteMidpoint,_that.vignetteRoundness,_that.vignetteFeather,_that.grain,_that.grainSize,_that.chromaticAberration,_that.glitch,_that.duotone,_that.lutId,_that.lutIntensity);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double exposure,  double contrast,  double highlights,  double shadows,  double whites,  double blacks,  double temperature,  double tint,  double vibrance,  double saturation,  HslAdjustments hsl,  SplitTone splitTone,  CurveSet curves,  double fade,  double sharpen,  double clarity,  double structure,  double dehaze,  double blur,  double vignette,  double vignetteMidpoint,  double vignetteRoundness,  double vignetteFeather,  double grain,  double grainSize,  double chromaticAberration,  double glitch,  Duotone duotone,  String? lutId,  double lutIntensity)?  $default,) {final _that = this;
switch (_that) {
case _Adjustments() when $default != null:
return $default(_that.exposure,_that.contrast,_that.highlights,_that.shadows,_that.whites,_that.blacks,_that.temperature,_that.tint,_that.vibrance,_that.saturation,_that.hsl,_that.splitTone,_that.curves,_that.fade,_that.sharpen,_that.clarity,_that.structure,_that.dehaze,_that.blur,_that.vignette,_that.vignetteMidpoint,_that.vignetteRoundness,_that.vignetteFeather,_that.grain,_that.grainSize,_that.chromaticAberration,_that.glitch,_that.duotone,_that.lutId,_that.lutIntensity);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Adjustments extends Adjustments {
  const _Adjustments({this.exposure = 0, this.contrast = 0, this.highlights = 0, this.shadows = 0, this.whites = 0, this.blacks = 0, this.temperature = 0, this.tint = 0, this.vibrance = 0, this.saturation = 0, this.hsl = const HslAdjustments(), this.splitTone = const SplitTone(), this.curves = const CurveSet(), this.fade = 0, this.sharpen = 0, this.clarity = 0, this.structure = 0, this.dehaze = 0, this.blur = 0, this.vignette = 0, this.vignetteMidpoint = 0.5, this.vignetteRoundness = 0, this.vignetteFeather = 0.5, this.grain = 0, this.grainSize = 0.5, this.chromaticAberration = 0, this.glitch = 0, this.duotone = const Duotone(), this.lutId, this.lutIntensity = 1}): super._();
  factory _Adjustments.fromJson(Map<String, dynamic> json) => _$AdjustmentsFromJson(json);

@override@JsonKey() final  double exposure;
@override@JsonKey() final  double contrast;
@override@JsonKey() final  double highlights;
@override@JsonKey() final  double shadows;
@override@JsonKey() final  double whites;
@override@JsonKey() final  double blacks;
@override@JsonKey() final  double temperature;
@override@JsonKey() final  double tint;
@override@JsonKey() final  double vibrance;
@override@JsonKey() final  double saturation;
@override@JsonKey() final  HslAdjustments hsl;
@override@JsonKey() final  SplitTone splitTone;
@override@JsonKey() final  CurveSet curves;
@override@JsonKey() final  double fade;
@override@JsonKey() final  double sharpen;
@override@JsonKey() final  double clarity;
@override@JsonKey() final  double structure;
@override@JsonKey() final  double dehaze;
@override@JsonKey() final  double blur;
@override@JsonKey() final  double vignette;
@override@JsonKey() final  double vignetteMidpoint;
@override@JsonKey() final  double vignetteRoundness;
@override@JsonKey() final  double vignetteFeather;
@override@JsonKey() final  double grain;
@override@JsonKey() final  double grainSize;
@override@JsonKey() final  double chromaticAberration;
@override@JsonKey() final  double glitch;
@override@JsonKey() final  Duotone duotone;
@override final  String? lutId;
@override@JsonKey() final  double lutIntensity;

/// Create a copy of Adjustments
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AdjustmentsCopyWith<_Adjustments> get copyWith => __$AdjustmentsCopyWithImpl<_Adjustments>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AdjustmentsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Adjustments&&(identical(other.exposure, exposure) || other.exposure == exposure)&&(identical(other.contrast, contrast) || other.contrast == contrast)&&(identical(other.highlights, highlights) || other.highlights == highlights)&&(identical(other.shadows, shadows) || other.shadows == shadows)&&(identical(other.whites, whites) || other.whites == whites)&&(identical(other.blacks, blacks) || other.blacks == blacks)&&(identical(other.temperature, temperature) || other.temperature == temperature)&&(identical(other.tint, tint) || other.tint == tint)&&(identical(other.vibrance, vibrance) || other.vibrance == vibrance)&&(identical(other.saturation, saturation) || other.saturation == saturation)&&(identical(other.hsl, hsl) || other.hsl == hsl)&&(identical(other.splitTone, splitTone) || other.splitTone == splitTone)&&(identical(other.curves, curves) || other.curves == curves)&&(identical(other.fade, fade) || other.fade == fade)&&(identical(other.sharpen, sharpen) || other.sharpen == sharpen)&&(identical(other.clarity, clarity) || other.clarity == clarity)&&(identical(other.structure, structure) || other.structure == structure)&&(identical(other.dehaze, dehaze) || other.dehaze == dehaze)&&(identical(other.blur, blur) || other.blur == blur)&&(identical(other.vignette, vignette) || other.vignette == vignette)&&(identical(other.vignetteMidpoint, vignetteMidpoint) || other.vignetteMidpoint == vignetteMidpoint)&&(identical(other.vignetteRoundness, vignetteRoundness) || other.vignetteRoundness == vignetteRoundness)&&(identical(other.vignetteFeather, vignetteFeather) || other.vignetteFeather == vignetteFeather)&&(identical(other.grain, grain) || other.grain == grain)&&(identical(other.grainSize, grainSize) || other.grainSize == grainSize)&&(identical(other.chromaticAberration, chromaticAberration) || other.chromaticAberration == chromaticAberration)&&(identical(other.glitch, glitch) || other.glitch == glitch)&&(identical(other.duotone, duotone) || other.duotone == duotone)&&(identical(other.lutId, lutId) || other.lutId == lutId)&&(identical(other.lutIntensity, lutIntensity) || other.lutIntensity == lutIntensity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,exposure,contrast,highlights,shadows,whites,blacks,temperature,tint,vibrance,saturation,hsl,splitTone,curves,fade,sharpen,clarity,structure,dehaze,blur,vignette,vignetteMidpoint,vignetteRoundness,vignetteFeather,grain,grainSize,chromaticAberration,glitch,duotone,lutId,lutIntensity]);
}

@override
String toString() {
    return 'Adjustments(exposure: $exposure, contrast: $contrast, highlights: $highlights, shadows: $shadows, whites: $whites, blacks: $blacks, temperature: $temperature, tint: $tint, vibrance: $vibrance, saturation: $saturation, hsl: $hsl, splitTone: $splitTone, curves: $curves, fade: $fade, sharpen: $sharpen, clarity: $clarity, structure: $structure, dehaze: $dehaze, blur: $blur, vignette: $vignette, vignetteMidpoint: $vignetteMidpoint, vignetteRoundness: $vignetteRoundness, vignetteFeather: $vignetteFeather, grain: $grain, grainSize: $grainSize, chromaticAberration: $chromaticAberration, glitch: $glitch, duotone: $duotone, lutId: $lutId, lutIntensity: $lutIntensity)';
}


}

/// @nodoc
abstract mixin class _$AdjustmentsCopyWith<$Res> implements $AdjustmentsCopyWith<$Res> {
  factory _$AdjustmentsCopyWith(_Adjustments value, $Res Function(_Adjustments) _then) = __$AdjustmentsCopyWithImpl;
@override @useResult
$Res call({
 double exposure, double contrast, double highlights, double shadows, double whites, double blacks, double temperature, double tint, double vibrance, double saturation, HslAdjustments hsl, SplitTone splitTone, CurveSet curves, double fade, double sharpen, double clarity, double structure, double dehaze, double blur, double vignette, double vignetteMidpoint, double vignetteRoundness, double vignetteFeather, double grain, double grainSize, double chromaticAberration, double glitch, Duotone duotone, String? lutId, double lutIntensity
});


@override $HslAdjustmentsCopyWith<$Res> get hsl;@override $SplitToneCopyWith<$Res> get splitTone;@override $CurveSetCopyWith<$Res> get curves;@override $DuotoneCopyWith<$Res> get duotone;

}
/// @nodoc
class __$AdjustmentsCopyWithImpl<$Res>
    implements _$AdjustmentsCopyWith<$Res> {
  __$AdjustmentsCopyWithImpl(this._self, this._then);

  final _Adjustments _self;
  final $Res Function(_Adjustments) _then;

/// Create a copy of Adjustments
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? exposure = null,Object? contrast = null,Object? highlights = null,Object? shadows = null,Object? whites = null,Object? blacks = null,Object? temperature = null,Object? tint = null,Object? vibrance = null,Object? saturation = null,Object? hsl = null,Object? splitTone = null,Object? curves = null,Object? fade = null,Object? sharpen = null,Object? clarity = null,Object? structure = null,Object? dehaze = null,Object? blur = null,Object? vignette = null,Object? vignetteMidpoint = null,Object? vignetteRoundness = null,Object? vignetteFeather = null,Object? grain = null,Object? grainSize = null,Object? chromaticAberration = null,Object? glitch = null,Object? duotone = null,Object? lutId = freezed,Object? lutIntensity = null,}) {
  return _then(_Adjustments(
exposure: null == exposure ? _self.exposure : exposure // ignore: cast_nullable_to_non_nullable
as double,contrast: null == contrast ? _self.contrast : contrast // ignore: cast_nullable_to_non_nullable
as double,highlights: null == highlights ? _self.highlights : highlights // ignore: cast_nullable_to_non_nullable
as double,shadows: null == shadows ? _self.shadows : shadows // ignore: cast_nullable_to_non_nullable
as double,whites: null == whites ? _self.whites : whites // ignore: cast_nullable_to_non_nullable
as double,blacks: null == blacks ? _self.blacks : blacks // ignore: cast_nullable_to_non_nullable
as double,temperature: null == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double,tint: null == tint ? _self.tint : tint // ignore: cast_nullable_to_non_nullable
as double,vibrance: null == vibrance ? _self.vibrance : vibrance // ignore: cast_nullable_to_non_nullable
as double,saturation: null == saturation ? _self.saturation : saturation // ignore: cast_nullable_to_non_nullable
as double,hsl: null == hsl ? _self.hsl : hsl // ignore: cast_nullable_to_non_nullable
as HslAdjustments,splitTone: null == splitTone ? _self.splitTone : splitTone // ignore: cast_nullable_to_non_nullable
as SplitTone,curves: null == curves ? _self.curves : curves // ignore: cast_nullable_to_non_nullable
as CurveSet,fade: null == fade ? _self.fade : fade // ignore: cast_nullable_to_non_nullable
as double,sharpen: null == sharpen ? _self.sharpen : sharpen // ignore: cast_nullable_to_non_nullable
as double,clarity: null == clarity ? _self.clarity : clarity // ignore: cast_nullable_to_non_nullable
as double,structure: null == structure ? _self.structure : structure // ignore: cast_nullable_to_non_nullable
as double,dehaze: null == dehaze ? _self.dehaze : dehaze // ignore: cast_nullable_to_non_nullable
as double,blur: null == blur ? _self.blur : blur // ignore: cast_nullable_to_non_nullable
as double,vignette: null == vignette ? _self.vignette : vignette // ignore: cast_nullable_to_non_nullable
as double,vignetteMidpoint: null == vignetteMidpoint ? _self.vignetteMidpoint : vignetteMidpoint // ignore: cast_nullable_to_non_nullable
as double,vignetteRoundness: null == vignetteRoundness ? _self.vignetteRoundness : vignetteRoundness // ignore: cast_nullable_to_non_nullable
as double,vignetteFeather: null == vignetteFeather ? _self.vignetteFeather : vignetteFeather // ignore: cast_nullable_to_non_nullable
as double,grain: null == grain ? _self.grain : grain // ignore: cast_nullable_to_non_nullable
as double,grainSize: null == grainSize ? _self.grainSize : grainSize // ignore: cast_nullable_to_non_nullable
as double,chromaticAberration: null == chromaticAberration ? _self.chromaticAberration : chromaticAberration // ignore: cast_nullable_to_non_nullable
as double,glitch: null == glitch ? _self.glitch : glitch // ignore: cast_nullable_to_non_nullable
as double,duotone: null == duotone ? _self.duotone : duotone // ignore: cast_nullable_to_non_nullable
as Duotone,lutId: freezed == lutId ? _self.lutId : lutId // ignore: cast_nullable_to_non_nullable
as String?,lutIntensity: null == lutIntensity ? _self.lutIntensity : lutIntensity // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

/// Create a copy of Adjustments
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$HslAdjustmentsCopyWith<$Res> get hsl {
  
  return $HslAdjustmentsCopyWith<$Res>(_self.hsl, (value) {
    return _then(_self.copyWith(hsl: value));
  });
}/// Create a copy of Adjustments
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SplitToneCopyWith<$Res> get splitTone {
  
  return $SplitToneCopyWith<$Res>(_self.splitTone, (value) {
    return _then(_self.copyWith(splitTone: value));
  });
}/// Create a copy of Adjustments
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CurveSetCopyWith<$Res> get curves {
  
  return $CurveSetCopyWith<$Res>(_self.curves, (value) {
    return _then(_self.copyWith(curves: value));
  });
}/// Create a copy of Adjustments
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DuotoneCopyWith<$Res> get duotone {
  
  return $DuotoneCopyWith<$Res>(_self.duotone, (value) {
    return _then(_self.copyWith(duotone: value));
  });
}
}

// dart format on
