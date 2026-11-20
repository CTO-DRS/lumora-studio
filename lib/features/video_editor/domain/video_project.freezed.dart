// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'video_project.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VideoClip {

 String get id; String get path; int get sourceDurationMs; int get outMs; int get inMs; double get speed; bool get reversed; double get volume; bool get hasAudio; int get sourceWidth; int get sourceHeight;/// Crop rect normalized to the source frame (l, t, r, b).
 List<double> get crop; int get quarterTurns; TransitionKind get transitionOut; int get transitionMs;/// Two-pass FFmpeg vid.stab stabilisation at export.
 bool get stabilize;/// Stabilisation strength 0..1 (maps to vidstab smoothing 5..40).
 double get stabilizeStrength;
/// Create a copy of VideoClip
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VideoClipCopyWith<VideoClip> get copyWith => _$VideoClipCopyWithImpl<VideoClip>(this as VideoClip, _$identity);

  /// Serializes this VideoClip to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as VideoClip;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoClip&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.path, _this.path) || other.path == _this.path)&&(identical(other.sourceDurationMs, _this.sourceDurationMs) || other.sourceDurationMs == _this.sourceDurationMs)&&(identical(other.outMs, _this.outMs) || other.outMs == _this.outMs)&&(identical(other.inMs, _this.inMs) || other.inMs == _this.inMs)&&(identical(other.speed, _this.speed) || other.speed == _this.speed)&&(identical(other.reversed, _this.reversed) || other.reversed == _this.reversed)&&(identical(other.volume, _this.volume) || other.volume == _this.volume)&&(identical(other.hasAudio, _this.hasAudio) || other.hasAudio == _this.hasAudio)&&(identical(other.sourceWidth, _this.sourceWidth) || other.sourceWidth == _this.sourceWidth)&&(identical(other.sourceHeight, _this.sourceHeight) || other.sourceHeight == _this.sourceHeight)&&const DeepCollectionEquality().equals(other.crop, _this.crop)&&(identical(other.quarterTurns, _this.quarterTurns) || other.quarterTurns == _this.quarterTurns)&&(identical(other.transitionOut, _this.transitionOut) || other.transitionOut == _this.transitionOut)&&(identical(other.transitionMs, _this.transitionMs) || other.transitionMs == _this.transitionMs)&&(identical(other.stabilize, _this.stabilize) || other.stabilize == _this.stabilize)&&(identical(other.stabilizeStrength, _this.stabilizeStrength) || other.stabilizeStrength == _this.stabilizeStrength));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as VideoClip;
  return Object.hash(runtimeType,_this.id,_this.path,_this.sourceDurationMs,_this.outMs,_this.inMs,_this.speed,_this.reversed,_this.volume,_this.hasAudio,_this.sourceWidth,_this.sourceHeight,const DeepCollectionEquality().hash(_this.crop),_this.quarterTurns,_this.transitionOut,_this.transitionMs,_this.stabilize,_this.stabilizeStrength);
}

@override
String toString() {
  final _this = this as VideoClip;
  return 'VideoClip(id: ${_this.id}, path: ${_this.path}, sourceDurationMs: ${_this.sourceDurationMs}, outMs: ${_this.outMs}, inMs: ${_this.inMs}, speed: ${_this.speed}, reversed: ${_this.reversed}, volume: ${_this.volume}, hasAudio: ${_this.hasAudio}, sourceWidth: ${_this.sourceWidth}, sourceHeight: ${_this.sourceHeight}, crop: ${_this.crop}, quarterTurns: ${_this.quarterTurns}, transitionOut: ${_this.transitionOut}, transitionMs: ${_this.transitionMs}, stabilize: ${_this.stabilize}, stabilizeStrength: ${_this.stabilizeStrength})';
}


}

/// @nodoc
abstract mixin class $VideoClipCopyWith<$Res>  {
  factory $VideoClipCopyWith(VideoClip value, $Res Function(VideoClip) _then) = _$VideoClipCopyWithImpl;
@useResult
$Res call({
 String id, String path, int sourceDurationMs, int outMs, int inMs, double speed, bool reversed, double volume, bool hasAudio, int sourceWidth, int sourceHeight, List<double> crop, int quarterTurns, TransitionKind transitionOut, int transitionMs, bool stabilize, double stabilizeStrength
});




}
/// @nodoc
class _$VideoClipCopyWithImpl<$Res>
    implements $VideoClipCopyWith<$Res> {
  _$VideoClipCopyWithImpl(this._self, this._then);

  final VideoClip _self;
  final $Res Function(VideoClip) _then;

/// Create a copy of VideoClip
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? path = null,Object? sourceDurationMs = null,Object? outMs = null,Object? inMs = null,Object? speed = null,Object? reversed = null,Object? volume = null,Object? hasAudio = null,Object? sourceWidth = null,Object? sourceHeight = null,Object? crop = null,Object? quarterTurns = null,Object? transitionOut = null,Object? transitionMs = null,Object? stabilize = null,Object? stabilizeStrength = null,}) {
  return _then(VideoClip(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,sourceDurationMs: null == sourceDurationMs ? _self.sourceDurationMs : sourceDurationMs // ignore: cast_nullable_to_non_nullable
as int,outMs: null == outMs ? _self.outMs : outMs // ignore: cast_nullable_to_non_nullable
as int,inMs: null == inMs ? _self.inMs : inMs // ignore: cast_nullable_to_non_nullable
as int,speed: null == speed ? _self.speed : speed // ignore: cast_nullable_to_non_nullable
as double,reversed: null == reversed ? _self.reversed : reversed // ignore: cast_nullable_to_non_nullable
as bool,volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as double,hasAudio: null == hasAudio ? _self.hasAudio : hasAudio // ignore: cast_nullable_to_non_nullable
as bool,sourceWidth: null == sourceWidth ? _self.sourceWidth : sourceWidth // ignore: cast_nullable_to_non_nullable
as int,sourceHeight: null == sourceHeight ? _self.sourceHeight : sourceHeight // ignore: cast_nullable_to_non_nullable
as int,crop: null == crop ? _self.crop : crop // ignore: cast_nullable_to_non_nullable
as List<double>,quarterTurns: null == quarterTurns ? _self.quarterTurns : quarterTurns // ignore: cast_nullable_to_non_nullable
as int,transitionOut: null == transitionOut ? _self.transitionOut : transitionOut // ignore: cast_nullable_to_non_nullable
as TransitionKind,transitionMs: null == transitionMs ? _self.transitionMs : transitionMs // ignore: cast_nullable_to_non_nullable
as int,stabilize: null == stabilize ? _self.stabilize : stabilize // ignore: cast_nullable_to_non_nullable
as bool,stabilizeStrength: null == stabilizeStrength ? _self.stabilizeStrength : stabilizeStrength // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [VideoClip].
extension VideoClipPatterns on VideoClip {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VideoClip value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VideoClip() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VideoClip value)  $default,){
final _that = this;
switch (_that) {
case _VideoClip():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VideoClip value)?  $default,){
final _that = this;
switch (_that) {
case _VideoClip() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String path,  int sourceDurationMs,  int outMs,  int inMs,  double speed,  bool reversed,  double volume,  bool hasAudio,  int sourceWidth,  int sourceHeight,  List<double> crop,  int quarterTurns,  TransitionKind transitionOut,  int transitionMs,  bool stabilize,  double stabilizeStrength)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VideoClip() when $default != null:
return $default(_that.id,_that.path,_that.sourceDurationMs,_that.outMs,_that.inMs,_that.speed,_that.reversed,_that.volume,_that.hasAudio,_that.sourceWidth,_that.sourceHeight,_that.crop,_that.quarterTurns,_that.transitionOut,_that.transitionMs,_that.stabilize,_that.stabilizeStrength);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String path,  int sourceDurationMs,  int outMs,  int inMs,  double speed,  bool reversed,  double volume,  bool hasAudio,  int sourceWidth,  int sourceHeight,  List<double> crop,  int quarterTurns,  TransitionKind transitionOut,  int transitionMs,  bool stabilize,  double stabilizeStrength)  $default,) {final _that = this;
switch (_that) {
case _VideoClip():
return $default(_that.id,_that.path,_that.sourceDurationMs,_that.outMs,_that.inMs,_that.speed,_that.reversed,_that.volume,_that.hasAudio,_that.sourceWidth,_that.sourceHeight,_that.crop,_that.quarterTurns,_that.transitionOut,_that.transitionMs,_that.stabilize,_that.stabilizeStrength);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String path,  int sourceDurationMs,  int outMs,  int inMs,  double speed,  bool reversed,  double volume,  bool hasAudio,  int sourceWidth,  int sourceHeight,  List<double> crop,  int quarterTurns,  TransitionKind transitionOut,  int transitionMs,  bool stabilize,  double stabilizeStrength)?  $default,) {final _that = this;
switch (_that) {
case _VideoClip() when $default != null:
return $default(_that.id,_that.path,_that.sourceDurationMs,_that.outMs,_that.inMs,_that.speed,_that.reversed,_that.volume,_that.hasAudio,_that.sourceWidth,_that.sourceHeight,_that.crop,_that.quarterTurns,_that.transitionOut,_that.transitionMs,_that.stabilize,_that.stabilizeStrength);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VideoClip extends VideoClip {
  const _VideoClip({required this.id, required this.path, required this.sourceDurationMs, required this.outMs, this.inMs = 0, this.speed = 1, this.reversed = false, this.volume = 1, this.hasAudio = true, this.sourceWidth = 0, this.sourceHeight = 0,  List<double> crop = const [0, 0, 1, 1], this.quarterTurns = 0, this.transitionOut = TransitionKind.none, this.transitionMs = 500, this.stabilize = false, this.stabilizeStrength = 0.5}): _crop = crop,super._();
  factory _VideoClip.fromJson(Map<String, dynamic> json) => _$VideoClipFromJson(json);

@override final  String id;
@override final  String path;
@override final  int sourceDurationMs;
@override final  int outMs;
@override@JsonKey() final  int inMs;
@override@JsonKey() final  double speed;
@override@JsonKey() final  bool reversed;
@override@JsonKey() final  double volume;
@override@JsonKey() final  bool hasAudio;
@override@JsonKey() final  int sourceWidth;
@override@JsonKey() final  int sourceHeight;
/// Crop rect normalized to the source frame (l, t, r, b).
 final  List<double> _crop;
/// Crop rect normalized to the source frame (l, t, r, b).
@override@JsonKey() List<double> get crop {
  if (_crop is EqualUnmodifiableListView) return _crop;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_crop);
}

@override@JsonKey() final  int quarterTurns;
@override@JsonKey() final  TransitionKind transitionOut;
@override@JsonKey() final  int transitionMs;
/// Two-pass FFmpeg vid.stab stabilisation at export.
@override@JsonKey() final  bool stabilize;
/// Stabilisation strength 0..1 (maps to vidstab smoothing 5..40).
@override@JsonKey() final  double stabilizeStrength;

/// Create a copy of VideoClip
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VideoClipCopyWith<_VideoClip> get copyWith => __$VideoClipCopyWithImpl<_VideoClip>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VideoClipToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VideoClip&&(identical(other.id, id) || other.id == id)&&(identical(other.path, path) || other.path == path)&&(identical(other.sourceDurationMs, sourceDurationMs) || other.sourceDurationMs == sourceDurationMs)&&(identical(other.outMs, outMs) || other.outMs == outMs)&&(identical(other.inMs, inMs) || other.inMs == inMs)&&(identical(other.speed, speed) || other.speed == speed)&&(identical(other.reversed, reversed) || other.reversed == reversed)&&(identical(other.volume, volume) || other.volume == volume)&&(identical(other.hasAudio, hasAudio) || other.hasAudio == hasAudio)&&(identical(other.sourceWidth, sourceWidth) || other.sourceWidth == sourceWidth)&&(identical(other.sourceHeight, sourceHeight) || other.sourceHeight == sourceHeight)&&const DeepCollectionEquality().equals(other.crop, _crop)&&(identical(other.quarterTurns, quarterTurns) || other.quarterTurns == quarterTurns)&&(identical(other.transitionOut, transitionOut) || other.transitionOut == transitionOut)&&(identical(other.transitionMs, transitionMs) || other.transitionMs == transitionMs)&&(identical(other.stabilize, stabilize) || other.stabilize == stabilize)&&(identical(other.stabilizeStrength, stabilizeStrength) || other.stabilizeStrength == stabilizeStrength));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,path,sourceDurationMs,outMs,inMs,speed,reversed,volume,hasAudio,sourceWidth,sourceHeight,const DeepCollectionEquality().hash(_crop),quarterTurns,transitionOut,transitionMs,stabilize,stabilizeStrength);
}

@override
String toString() {
    return 'VideoClip(id: $id, path: $path, sourceDurationMs: $sourceDurationMs, outMs: $outMs, inMs: $inMs, speed: $speed, reversed: $reversed, volume: $volume, hasAudio: $hasAudio, sourceWidth: $sourceWidth, sourceHeight: $sourceHeight, crop: $crop, quarterTurns: $quarterTurns, transitionOut: $transitionOut, transitionMs: $transitionMs, stabilize: $stabilize, stabilizeStrength: $stabilizeStrength)';
}


}

/// @nodoc
abstract mixin class _$VideoClipCopyWith<$Res> implements $VideoClipCopyWith<$Res> {
  factory _$VideoClipCopyWith(_VideoClip value, $Res Function(_VideoClip) _then) = __$VideoClipCopyWithImpl;
@override @useResult
$Res call({
 String id, String path, int sourceDurationMs, int outMs, int inMs, double speed, bool reversed, double volume, bool hasAudio, int sourceWidth, int sourceHeight, List<double> crop, int quarterTurns, TransitionKind transitionOut, int transitionMs, bool stabilize, double stabilizeStrength
});




}
/// @nodoc
class __$VideoClipCopyWithImpl<$Res>
    implements _$VideoClipCopyWith<$Res> {
  __$VideoClipCopyWithImpl(this._self, this._then);

  final _VideoClip _self;
  final $Res Function(_VideoClip) _then;

/// Create a copy of VideoClip
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? path = null,Object? sourceDurationMs = null,Object? outMs = null,Object? inMs = null,Object? speed = null,Object? reversed = null,Object? volume = null,Object? hasAudio = null,Object? sourceWidth = null,Object? sourceHeight = null,Object? crop = null,Object? quarterTurns = null,Object? transitionOut = null,Object? transitionMs = null,Object? stabilize = null,Object? stabilizeStrength = null,}) {
  return _then(_VideoClip(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,sourceDurationMs: null == sourceDurationMs ? _self.sourceDurationMs : sourceDurationMs // ignore: cast_nullable_to_non_nullable
as int,outMs: null == outMs ? _self.outMs : outMs // ignore: cast_nullable_to_non_nullable
as int,inMs: null == inMs ? _self.inMs : inMs // ignore: cast_nullable_to_non_nullable
as int,speed: null == speed ? _self.speed : speed // ignore: cast_nullable_to_non_nullable
as double,reversed: null == reversed ? _self.reversed : reversed // ignore: cast_nullable_to_non_nullable
as bool,volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as double,hasAudio: null == hasAudio ? _self.hasAudio : hasAudio // ignore: cast_nullable_to_non_nullable
as bool,sourceWidth: null == sourceWidth ? _self.sourceWidth : sourceWidth // ignore: cast_nullable_to_non_nullable
as int,sourceHeight: null == sourceHeight ? _self.sourceHeight : sourceHeight // ignore: cast_nullable_to_non_nullable
as int,crop: null == crop ? _self._crop : crop // ignore: cast_nullable_to_non_nullable
as List<double>,quarterTurns: null == quarterTurns ? _self.quarterTurns : quarterTurns // ignore: cast_nullable_to_non_nullable
as int,transitionOut: null == transitionOut ? _self.transitionOut : transitionOut // ignore: cast_nullable_to_non_nullable
as TransitionKind,transitionMs: null == transitionMs ? _self.transitionMs : transitionMs // ignore: cast_nullable_to_non_nullable
as int,stabilize: null == stabilize ? _self.stabilize : stabilize // ignore: cast_nullable_to_non_nullable
as bool,stabilizeStrength: null == stabilizeStrength ? _self.stabilizeStrength : stabilizeStrength // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}


/// @nodoc
mixin _$VideoText {

 String get id; String get text; int get startMs; int get endMs; double get x; double get y; double get fontSize; int get color; int? get backgroundColor; bool get bold;
/// Create a copy of VideoText
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VideoTextCopyWith<VideoText> get copyWith => _$VideoTextCopyWithImpl<VideoText>(this as VideoText, _$identity);

  /// Serializes this VideoText to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as VideoText;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoText&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.text, _this.text) || other.text == _this.text)&&(identical(other.startMs, _this.startMs) || other.startMs == _this.startMs)&&(identical(other.endMs, _this.endMs) || other.endMs == _this.endMs)&&(identical(other.x, _this.x) || other.x == _this.x)&&(identical(other.y, _this.y) || other.y == _this.y)&&(identical(other.fontSize, _this.fontSize) || other.fontSize == _this.fontSize)&&(identical(other.color, _this.color) || other.color == _this.color)&&(identical(other.backgroundColor, _this.backgroundColor) || other.backgroundColor == _this.backgroundColor)&&(identical(other.bold, _this.bold) || other.bold == _this.bold));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as VideoText;
  return Object.hash(runtimeType,_this.id,_this.text,_this.startMs,_this.endMs,_this.x,_this.y,_this.fontSize,_this.color,_this.backgroundColor,_this.bold);
}

@override
String toString() {
  final _this = this as VideoText;
  return 'VideoText(id: ${_this.id}, text: ${_this.text}, startMs: ${_this.startMs}, endMs: ${_this.endMs}, x: ${_this.x}, y: ${_this.y}, fontSize: ${_this.fontSize}, color: ${_this.color}, backgroundColor: ${_this.backgroundColor}, bold: ${_this.bold})';
}


}

/// @nodoc
abstract mixin class $VideoTextCopyWith<$Res>  {
  factory $VideoTextCopyWith(VideoText value, $Res Function(VideoText) _then) = _$VideoTextCopyWithImpl;
@useResult
$Res call({
 String id, String text, int startMs, int endMs, double x, double y, double fontSize, int color, int? backgroundColor, bool bold
});




}
/// @nodoc
class _$VideoTextCopyWithImpl<$Res>
    implements $VideoTextCopyWith<$Res> {
  _$VideoTextCopyWithImpl(this._self, this._then);

  final VideoText _self;
  final $Res Function(VideoText) _then;

/// Create a copy of VideoText
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? text = null,Object? startMs = null,Object? endMs = null,Object? x = null,Object? y = null,Object? fontSize = null,Object? color = null,Object? backgroundColor = freezed,Object? bold = null,}) {
  return _then(VideoText(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,startMs: null == startMs ? _self.startMs : startMs // ignore: cast_nullable_to_non_nullable
as int,endMs: null == endMs ? _self.endMs : endMs // ignore: cast_nullable_to_non_nullable
as int,x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as double,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as double,fontSize: null == fontSize ? _self.fontSize : fontSize // ignore: cast_nullable_to_non_nullable
as double,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as int,backgroundColor: freezed == backgroundColor ? _self.backgroundColor : backgroundColor // ignore: cast_nullable_to_non_nullable
as int?,bold: null == bold ? _self.bold : bold // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [VideoText].
extension VideoTextPatterns on VideoText {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VideoText value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VideoText() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VideoText value)  $default,){
final _that = this;
switch (_that) {
case _VideoText():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VideoText value)?  $default,){
final _that = this;
switch (_that) {
case _VideoText() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String text,  int startMs,  int endMs,  double x,  double y,  double fontSize,  int color,  int? backgroundColor,  bool bold)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VideoText() when $default != null:
return $default(_that.id,_that.text,_that.startMs,_that.endMs,_that.x,_that.y,_that.fontSize,_that.color,_that.backgroundColor,_that.bold);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String text,  int startMs,  int endMs,  double x,  double y,  double fontSize,  int color,  int? backgroundColor,  bool bold)  $default,) {final _that = this;
switch (_that) {
case _VideoText():
return $default(_that.id,_that.text,_that.startMs,_that.endMs,_that.x,_that.y,_that.fontSize,_that.color,_that.backgroundColor,_that.bold);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String text,  int startMs,  int endMs,  double x,  double y,  double fontSize,  int color,  int? backgroundColor,  bool bold)?  $default,) {final _that = this;
switch (_that) {
case _VideoText() when $default != null:
return $default(_that.id,_that.text,_that.startMs,_that.endMs,_that.x,_that.y,_that.fontSize,_that.color,_that.backgroundColor,_that.bold);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VideoText implements VideoText {
  const _VideoText({required this.id, required this.text, this.startMs = 0, this.endMs = 3000, this.x = 0.5, this.y = 0.8, this.fontSize = 0.07, this.color = 0xFFFFFFFF, this.backgroundColor, this.bold = true});
  factory _VideoText.fromJson(Map<String, dynamic> json) => _$VideoTextFromJson(json);

@override final  String id;
@override final  String text;
@override@JsonKey() final  int startMs;
@override@JsonKey() final  int endMs;
@override@JsonKey() final  double x;
@override@JsonKey() final  double y;
@override@JsonKey() final  double fontSize;
@override@JsonKey() final  int color;
@override final  int? backgroundColor;
@override@JsonKey() final  bool bold;

/// Create a copy of VideoText
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VideoTextCopyWith<_VideoText> get copyWith => __$VideoTextCopyWithImpl<_VideoText>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VideoTextToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VideoText&&(identical(other.id, id) || other.id == id)&&(identical(other.text, text) || other.text == text)&&(identical(other.startMs, startMs) || other.startMs == startMs)&&(identical(other.endMs, endMs) || other.endMs == endMs)&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y)&&(identical(other.fontSize, fontSize) || other.fontSize == fontSize)&&(identical(other.color, color) || other.color == color)&&(identical(other.backgroundColor, backgroundColor) || other.backgroundColor == backgroundColor)&&(identical(other.bold, bold) || other.bold == bold));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,text,startMs,endMs,x,y,fontSize,color,backgroundColor,bold);
}

@override
String toString() {
    return 'VideoText(id: $id, text: $text, startMs: $startMs, endMs: $endMs, x: $x, y: $y, fontSize: $fontSize, color: $color, backgroundColor: $backgroundColor, bold: $bold)';
}


}

/// @nodoc
abstract mixin class _$VideoTextCopyWith<$Res> implements $VideoTextCopyWith<$Res> {
  factory _$VideoTextCopyWith(_VideoText value, $Res Function(_VideoText) _then) = __$VideoTextCopyWithImpl;
@override @useResult
$Res call({
 String id, String text, int startMs, int endMs, double x, double y, double fontSize, int color, int? backgroundColor, bool bold
});




}
/// @nodoc
class __$VideoTextCopyWithImpl<$Res>
    implements _$VideoTextCopyWith<$Res> {
  __$VideoTextCopyWithImpl(this._self, this._then);

  final _VideoText _self;
  final $Res Function(_VideoText) _then;

/// Create a copy of VideoText
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? text = null,Object? startMs = null,Object? endMs = null,Object? x = null,Object? y = null,Object? fontSize = null,Object? color = null,Object? backgroundColor = freezed,Object? bold = null,}) {
  return _then(_VideoText(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,startMs: null == startMs ? _self.startMs : startMs // ignore: cast_nullable_to_non_nullable
as int,endMs: null == endMs ? _self.endMs : endMs // ignore: cast_nullable_to_non_nullable
as int,x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as double,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as double,fontSize: null == fontSize ? _self.fontSize : fontSize // ignore: cast_nullable_to_non_nullable
as double,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as int,backgroundColor: freezed == backgroundColor ? _self.backgroundColor : backgroundColor // ignore: cast_nullable_to_non_nullable
as int?,bold: null == bold ? _self.bold : bold // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$AudioTrack {

 String get path; int get startOffsetMs; double get volume; int get fadeInMs; int get fadeOutMs; bool get loop;
/// Create a copy of AudioTrack
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AudioTrackCopyWith<AudioTrack> get copyWith => _$AudioTrackCopyWithImpl<AudioTrack>(this as AudioTrack, _$identity);

  /// Serializes this AudioTrack to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AudioTrack;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioTrack&&(identical(other.path, _this.path) || other.path == _this.path)&&(identical(other.startOffsetMs, _this.startOffsetMs) || other.startOffsetMs == _this.startOffsetMs)&&(identical(other.volume, _this.volume) || other.volume == _this.volume)&&(identical(other.fadeInMs, _this.fadeInMs) || other.fadeInMs == _this.fadeInMs)&&(identical(other.fadeOutMs, _this.fadeOutMs) || other.fadeOutMs == _this.fadeOutMs)&&(identical(other.loop, _this.loop) || other.loop == _this.loop));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AudioTrack;
  return Object.hash(runtimeType,_this.path,_this.startOffsetMs,_this.volume,_this.fadeInMs,_this.fadeOutMs,_this.loop);
}

@override
String toString() {
  final _this = this as AudioTrack;
  return 'AudioTrack(path: ${_this.path}, startOffsetMs: ${_this.startOffsetMs}, volume: ${_this.volume}, fadeInMs: ${_this.fadeInMs}, fadeOutMs: ${_this.fadeOutMs}, loop: ${_this.loop})';
}


}

/// @nodoc
abstract mixin class $AudioTrackCopyWith<$Res>  {
  factory $AudioTrackCopyWith(AudioTrack value, $Res Function(AudioTrack) _then) = _$AudioTrackCopyWithImpl;
@useResult
$Res call({
 String path, int startOffsetMs, double volume, int fadeInMs, int fadeOutMs, bool loop
});




}
/// @nodoc
class _$AudioTrackCopyWithImpl<$Res>
    implements $AudioTrackCopyWith<$Res> {
  _$AudioTrackCopyWithImpl(this._self, this._then);

  final AudioTrack _self;
  final $Res Function(AudioTrack) _then;

/// Create a copy of AudioTrack
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? path = null,Object? startOffsetMs = null,Object? volume = null,Object? fadeInMs = null,Object? fadeOutMs = null,Object? loop = null,}) {
  return _then(AudioTrack(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,startOffsetMs: null == startOffsetMs ? _self.startOffsetMs : startOffsetMs // ignore: cast_nullable_to_non_nullable
as int,volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as double,fadeInMs: null == fadeInMs ? _self.fadeInMs : fadeInMs // ignore: cast_nullable_to_non_nullable
as int,fadeOutMs: null == fadeOutMs ? _self.fadeOutMs : fadeOutMs // ignore: cast_nullable_to_non_nullable
as int,loop: null == loop ? _self.loop : loop // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AudioTrack].
extension AudioTrackPatterns on AudioTrack {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AudioTrack value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AudioTrack() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AudioTrack value)  $default,){
final _that = this;
switch (_that) {
case _AudioTrack():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AudioTrack value)?  $default,){
final _that = this;
switch (_that) {
case _AudioTrack() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String path,  int startOffsetMs,  double volume,  int fadeInMs,  int fadeOutMs,  bool loop)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AudioTrack() when $default != null:
return $default(_that.path,_that.startOffsetMs,_that.volume,_that.fadeInMs,_that.fadeOutMs,_that.loop);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String path,  int startOffsetMs,  double volume,  int fadeInMs,  int fadeOutMs,  bool loop)  $default,) {final _that = this;
switch (_that) {
case _AudioTrack():
return $default(_that.path,_that.startOffsetMs,_that.volume,_that.fadeInMs,_that.fadeOutMs,_that.loop);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String path,  int startOffsetMs,  double volume,  int fadeInMs,  int fadeOutMs,  bool loop)?  $default,) {final _that = this;
switch (_that) {
case _AudioTrack() when $default != null:
return $default(_that.path,_that.startOffsetMs,_that.volume,_that.fadeInMs,_that.fadeOutMs,_that.loop);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AudioTrack implements AudioTrack {
  const _AudioTrack({required this.path, this.startOffsetMs = 0, this.volume = 0.8, this.fadeInMs = 1000, this.fadeOutMs = 1500, this.loop = true});
  factory _AudioTrack.fromJson(Map<String, dynamic> json) => _$AudioTrackFromJson(json);

@override final  String path;
@override@JsonKey() final  int startOffsetMs;
@override@JsonKey() final  double volume;
@override@JsonKey() final  int fadeInMs;
@override@JsonKey() final  int fadeOutMs;
@override@JsonKey() final  bool loop;

/// Create a copy of AudioTrack
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AudioTrackCopyWith<_AudioTrack> get copyWith => __$AudioTrackCopyWithImpl<_AudioTrack>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AudioTrackToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AudioTrack&&(identical(other.path, path) || other.path == path)&&(identical(other.startOffsetMs, startOffsetMs) || other.startOffsetMs == startOffsetMs)&&(identical(other.volume, volume) || other.volume == volume)&&(identical(other.fadeInMs, fadeInMs) || other.fadeInMs == fadeInMs)&&(identical(other.fadeOutMs, fadeOutMs) || other.fadeOutMs == fadeOutMs)&&(identical(other.loop, loop) || other.loop == loop));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,path,startOffsetMs,volume,fadeInMs,fadeOutMs,loop);
}

@override
String toString() {
    return 'AudioTrack(path: $path, startOffsetMs: $startOffsetMs, volume: $volume, fadeInMs: $fadeInMs, fadeOutMs: $fadeOutMs, loop: $loop)';
}


}

/// @nodoc
abstract mixin class _$AudioTrackCopyWith<$Res> implements $AudioTrackCopyWith<$Res> {
  factory _$AudioTrackCopyWith(_AudioTrack value, $Res Function(_AudioTrack) _then) = __$AudioTrackCopyWithImpl;
@override @useResult
$Res call({
 String path, int startOffsetMs, double volume, int fadeInMs, int fadeOutMs, bool loop
});




}
/// @nodoc
class __$AudioTrackCopyWithImpl<$Res>
    implements _$AudioTrackCopyWith<$Res> {
  __$AudioTrackCopyWithImpl(this._self, this._then);

  final _AudioTrack _self;
  final $Res Function(_AudioTrack) _then;

/// Create a copy of AudioTrack
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = null,Object? startOffsetMs = null,Object? volume = null,Object? fadeInMs = null,Object? fadeOutMs = null,Object? loop = null,}) {
  return _then(_AudioTrack(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,startOffsetMs: null == startOffsetMs ? _self.startOffsetMs : startOffsetMs // ignore: cast_nullable_to_non_nullable
as int,volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as double,fadeInMs: null == fadeInMs ? _self.fadeInMs : fadeInMs // ignore: cast_nullable_to_non_nullable
as int,fadeOutMs: null == fadeOutMs ? _self.fadeOutMs : fadeOutMs // ignore: cast_nullable_to_non_nullable
as int,loop: null == loop ? _self.loop : loop // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$LookKeyframe {

 int get timeMs; double get intensity;
/// Create a copy of LookKeyframe
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LookKeyframeCopyWith<LookKeyframe> get copyWith => _$LookKeyframeCopyWithImpl<LookKeyframe>(this as LookKeyframe, _$identity);

  /// Serializes this LookKeyframe to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LookKeyframe;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LookKeyframe&&(identical(other.timeMs, _this.timeMs) || other.timeMs == _this.timeMs)&&(identical(other.intensity, _this.intensity) || other.intensity == _this.intensity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LookKeyframe;
  return Object.hash(runtimeType,_this.timeMs,_this.intensity);
}

@override
String toString() {
  final _this = this as LookKeyframe;
  return 'LookKeyframe(timeMs: ${_this.timeMs}, intensity: ${_this.intensity})';
}


}

/// @nodoc
abstract mixin class $LookKeyframeCopyWith<$Res>  {
  factory $LookKeyframeCopyWith(LookKeyframe value, $Res Function(LookKeyframe) _then) = _$LookKeyframeCopyWithImpl;
@useResult
$Res call({
 int timeMs, double intensity
});




}
/// @nodoc
class _$LookKeyframeCopyWithImpl<$Res>
    implements $LookKeyframeCopyWith<$Res> {
  _$LookKeyframeCopyWithImpl(this._self, this._then);

  final LookKeyframe _self;
  final $Res Function(LookKeyframe) _then;

/// Create a copy of LookKeyframe
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? timeMs = null,Object? intensity = null,}) {
  return _then(LookKeyframe(
timeMs: null == timeMs ? _self.timeMs : timeMs // ignore: cast_nullable_to_non_nullable
as int,intensity: null == intensity ? _self.intensity : intensity // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [LookKeyframe].
extension LookKeyframePatterns on LookKeyframe {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LookKeyframe value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LookKeyframe() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LookKeyframe value)  $default,){
final _that = this;
switch (_that) {
case _LookKeyframe():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LookKeyframe value)?  $default,){
final _that = this;
switch (_that) {
case _LookKeyframe() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int timeMs,  double intensity)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LookKeyframe() when $default != null:
return $default(_that.timeMs,_that.intensity);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int timeMs,  double intensity)  $default,) {final _that = this;
switch (_that) {
case _LookKeyframe():
return $default(_that.timeMs,_that.intensity);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int timeMs,  double intensity)?  $default,) {final _that = this;
switch (_that) {
case _LookKeyframe() when $default != null:
return $default(_that.timeMs,_that.intensity);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LookKeyframe implements LookKeyframe {
  const _LookKeyframe({required this.timeMs, this.intensity = 1});
  factory _LookKeyframe.fromJson(Map<String, dynamic> json) => _$LookKeyframeFromJson(json);

@override final  int timeMs;
@override@JsonKey() final  double intensity;

/// Create a copy of LookKeyframe
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LookKeyframeCopyWith<_LookKeyframe> get copyWith => __$LookKeyframeCopyWithImpl<_LookKeyframe>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LookKeyframeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LookKeyframe&&(identical(other.timeMs, timeMs) || other.timeMs == timeMs)&&(identical(other.intensity, intensity) || other.intensity == intensity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,timeMs,intensity);
}

@override
String toString() {
    return 'LookKeyframe(timeMs: $timeMs, intensity: $intensity)';
}


}

/// @nodoc
abstract mixin class _$LookKeyframeCopyWith<$Res> implements $LookKeyframeCopyWith<$Res> {
  factory _$LookKeyframeCopyWith(_LookKeyframe value, $Res Function(_LookKeyframe) _then) = __$LookKeyframeCopyWithImpl;
@override @useResult
$Res call({
 int timeMs, double intensity
});




}
/// @nodoc
class __$LookKeyframeCopyWithImpl<$Res>
    implements _$LookKeyframeCopyWith<$Res> {
  __$LookKeyframeCopyWithImpl(this._self, this._then);

  final _LookKeyframe _self;
  final $Res Function(_LookKeyframe) _then;

/// Create a copy of LookKeyframe
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? timeMs = null,Object? intensity = null,}) {
  return _then(_LookKeyframe(
timeMs: null == timeMs ? _self.timeMs : timeMs // ignore: cast_nullable_to_non_nullable
as int,intensity: null == intensity ? _self.intensity : intensity // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}


/// @nodoc
mixin _$VideoProject {

 List<VideoClip> get clips; List<VideoText> get texts; AudioTrack? get music; double get originalVolume;/// Look applied to every frame (same engine as photos).
 Adjustments get look; String? get presetId;/// Overall strength of [look] (0..1) when there are no keyframes.
 double get lookIntensity;/// Look strength over time; linear between keyframes.
 List<LookKeyframe> get lookKeyframes; VideoAspect get aspect; VideoResolution get resolution; int get fps;
/// Create a copy of VideoProject
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VideoProjectCopyWith<VideoProject> get copyWith => _$VideoProjectCopyWithImpl<VideoProject>(this as VideoProject, _$identity);

  /// Serializes this VideoProject to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as VideoProject;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoProject&&const DeepCollectionEquality().equals(other.clips, _this.clips)&&const DeepCollectionEquality().equals(other.texts, _this.texts)&&(identical(other.music, _this.music) || other.music == _this.music)&&(identical(other.originalVolume, _this.originalVolume) || other.originalVolume == _this.originalVolume)&&(identical(other.look, _this.look) || other.look == _this.look)&&(identical(other.presetId, _this.presetId) || other.presetId == _this.presetId)&&(identical(other.lookIntensity, _this.lookIntensity) || other.lookIntensity == _this.lookIntensity)&&const DeepCollectionEquality().equals(other.lookKeyframes, _this.lookKeyframes)&&(identical(other.aspect, _this.aspect) || other.aspect == _this.aspect)&&(identical(other.resolution, _this.resolution) || other.resolution == _this.resolution)&&(identical(other.fps, _this.fps) || other.fps == _this.fps));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as VideoProject;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.clips),const DeepCollectionEquality().hash(_this.texts),_this.music,_this.originalVolume,_this.look,_this.presetId,_this.lookIntensity,const DeepCollectionEquality().hash(_this.lookKeyframes),_this.aspect,_this.resolution,_this.fps);
}

@override
String toString() {
  final _this = this as VideoProject;
  return 'VideoProject(clips: ${_this.clips}, texts: ${_this.texts}, music: ${_this.music}, originalVolume: ${_this.originalVolume}, look: ${_this.look}, presetId: ${_this.presetId}, lookIntensity: ${_this.lookIntensity}, lookKeyframes: ${_this.lookKeyframes}, aspect: ${_this.aspect}, resolution: ${_this.resolution}, fps: ${_this.fps})';
}


}

/// @nodoc
abstract mixin class $VideoProjectCopyWith<$Res>  {
  factory $VideoProjectCopyWith(VideoProject value, $Res Function(VideoProject) _then) = _$VideoProjectCopyWithImpl;
@useResult
$Res call({
 List<VideoClip> clips, List<VideoText> texts, AudioTrack? music, double originalVolume, Adjustments look, String? presetId, double lookIntensity, List<LookKeyframe> lookKeyframes, VideoAspect aspect, VideoResolution resolution, int fps
});


$AudioTrackCopyWith<$Res>? get music;$AdjustmentsCopyWith<$Res> get look;

}
/// @nodoc
class _$VideoProjectCopyWithImpl<$Res>
    implements $VideoProjectCopyWith<$Res> {
  _$VideoProjectCopyWithImpl(this._self, this._then);

  final VideoProject _self;
  final $Res Function(VideoProject) _then;

/// Create a copy of VideoProject
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? clips = null,Object? texts = null,Object? music = freezed,Object? originalVolume = null,Object? look = null,Object? presetId = freezed,Object? lookIntensity = null,Object? lookKeyframes = null,Object? aspect = null,Object? resolution = null,Object? fps = null,}) {
  return _then(VideoProject(
clips: null == clips ? _self.clips : clips // ignore: cast_nullable_to_non_nullable
as List<VideoClip>,texts: null == texts ? _self.texts : texts // ignore: cast_nullable_to_non_nullable
as List<VideoText>,music: freezed == music ? _self.music : music // ignore: cast_nullable_to_non_nullable
as AudioTrack?,originalVolume: null == originalVolume ? _self.originalVolume : originalVolume // ignore: cast_nullable_to_non_nullable
as double,look: null == look ? _self.look : look // ignore: cast_nullable_to_non_nullable
as Adjustments,presetId: freezed == presetId ? _self.presetId : presetId // ignore: cast_nullable_to_non_nullable
as String?,lookIntensity: null == lookIntensity ? _self.lookIntensity : lookIntensity // ignore: cast_nullable_to_non_nullable
as double,lookKeyframes: null == lookKeyframes ? _self.lookKeyframes : lookKeyframes // ignore: cast_nullable_to_non_nullable
as List<LookKeyframe>,aspect: null == aspect ? _self.aspect : aspect // ignore: cast_nullable_to_non_nullable
as VideoAspect,resolution: null == resolution ? _self.resolution : resolution // ignore: cast_nullable_to_non_nullable
as VideoResolution,fps: null == fps ? _self.fps : fps // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of VideoProject
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AudioTrackCopyWith<$Res>? get music {
    if (_self.music == null) {
    return null;
  }

  return $AudioTrackCopyWith<$Res>(_self.music!, (value) {
    return _then(_self.copyWith(music: value));
  });
}/// Create a copy of VideoProject
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AdjustmentsCopyWith<$Res> get look {
  
  return $AdjustmentsCopyWith<$Res>(_self.look, (value) {
    return _then(_self.copyWith(look: value));
  });
}
}


/// Adds pattern-matching-related methods to [VideoProject].
extension VideoProjectPatterns on VideoProject {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VideoProject value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VideoProject() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VideoProject value)  $default,){
final _that = this;
switch (_that) {
case _VideoProject():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VideoProject value)?  $default,){
final _that = this;
switch (_that) {
case _VideoProject() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<VideoClip> clips,  List<VideoText> texts,  AudioTrack? music,  double originalVolume,  Adjustments look,  String? presetId,  double lookIntensity,  List<LookKeyframe> lookKeyframes,  VideoAspect aspect,  VideoResolution resolution,  int fps)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VideoProject() when $default != null:
return $default(_that.clips,_that.texts,_that.music,_that.originalVolume,_that.look,_that.presetId,_that.lookIntensity,_that.lookKeyframes,_that.aspect,_that.resolution,_that.fps);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<VideoClip> clips,  List<VideoText> texts,  AudioTrack? music,  double originalVolume,  Adjustments look,  String? presetId,  double lookIntensity,  List<LookKeyframe> lookKeyframes,  VideoAspect aspect,  VideoResolution resolution,  int fps)  $default,) {final _that = this;
switch (_that) {
case _VideoProject():
return $default(_that.clips,_that.texts,_that.music,_that.originalVolume,_that.look,_that.presetId,_that.lookIntensity,_that.lookKeyframes,_that.aspect,_that.resolution,_that.fps);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<VideoClip> clips,  List<VideoText> texts,  AudioTrack? music,  double originalVolume,  Adjustments look,  String? presetId,  double lookIntensity,  List<LookKeyframe> lookKeyframes,  VideoAspect aspect,  VideoResolution resolution,  int fps)?  $default,) {final _that = this;
switch (_that) {
case _VideoProject() when $default != null:
return $default(_that.clips,_that.texts,_that.music,_that.originalVolume,_that.look,_that.presetId,_that.lookIntensity,_that.lookKeyframes,_that.aspect,_that.resolution,_that.fps);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VideoProject implements VideoProject {
  const _VideoProject({ List<VideoClip> clips = const <VideoClip>[],  List<VideoText> texts = const <VideoText>[], this.music, this.originalVolume = 1, this.look = const Adjustments(), this.presetId, this.lookIntensity = 1,  List<LookKeyframe> lookKeyframes = const <LookKeyframe>[], this.aspect = VideoAspect.landscape, this.resolution = VideoResolution.p1080, this.fps = 30}): _clips = clips,_texts = texts,_lookKeyframes = lookKeyframes;
  factory _VideoProject.fromJson(Map<String, dynamic> json) => _$VideoProjectFromJson(json);

 final  List<VideoClip> _clips;
@override@JsonKey() List<VideoClip> get clips {
  if (_clips is EqualUnmodifiableListView) return _clips;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_clips);
}

 final  List<VideoText> _texts;
@override@JsonKey() List<VideoText> get texts {
  if (_texts is EqualUnmodifiableListView) return _texts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_texts);
}

@override final  AudioTrack? music;
@override@JsonKey() final  double originalVolume;
/// Look applied to every frame (same engine as photos).
@override@JsonKey() final  Adjustments look;
@override final  String? presetId;
/// Overall strength of [look] (0..1) when there are no keyframes.
@override@JsonKey() final  double lookIntensity;
/// Look strength over time; linear between keyframes.
 final  List<LookKeyframe> _lookKeyframes;
/// Look strength over time; linear between keyframes.
@override@JsonKey() List<LookKeyframe> get lookKeyframes {
  if (_lookKeyframes is EqualUnmodifiableListView) return _lookKeyframes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lookKeyframes);
}

@override@JsonKey() final  VideoAspect aspect;
@override@JsonKey() final  VideoResolution resolution;
@override@JsonKey() final  int fps;

/// Create a copy of VideoProject
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VideoProjectCopyWith<_VideoProject> get copyWith => __$VideoProjectCopyWithImpl<_VideoProject>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VideoProjectToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VideoProject&&const DeepCollectionEquality().equals(other.clips, _clips)&&const DeepCollectionEquality().equals(other.texts, _texts)&&(identical(other.music, music) || other.music == music)&&(identical(other.originalVolume, originalVolume) || other.originalVolume == originalVolume)&&(identical(other.look, look) || other.look == look)&&(identical(other.presetId, presetId) || other.presetId == presetId)&&(identical(other.lookIntensity, lookIntensity) || other.lookIntensity == lookIntensity)&&const DeepCollectionEquality().equals(other.lookKeyframes, _lookKeyframes)&&(identical(other.aspect, aspect) || other.aspect == aspect)&&(identical(other.resolution, resolution) || other.resolution == resolution)&&(identical(other.fps, fps) || other.fps == fps));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_clips),const DeepCollectionEquality().hash(_texts),music,originalVolume,look,presetId,lookIntensity,const DeepCollectionEquality().hash(_lookKeyframes),aspect,resolution,fps);
}

@override
String toString() {
    return 'VideoProject(clips: $clips, texts: $texts, music: $music, originalVolume: $originalVolume, look: $look, presetId: $presetId, lookIntensity: $lookIntensity, lookKeyframes: $lookKeyframes, aspect: $aspect, resolution: $resolution, fps: $fps)';
}


}

/// @nodoc
abstract mixin class _$VideoProjectCopyWith<$Res> implements $VideoProjectCopyWith<$Res> {
  factory _$VideoProjectCopyWith(_VideoProject value, $Res Function(_VideoProject) _then) = __$VideoProjectCopyWithImpl;
@override @useResult
$Res call({
 List<VideoClip> clips, List<VideoText> texts, AudioTrack? music, double originalVolume, Adjustments look, String? presetId, double lookIntensity, List<LookKeyframe> lookKeyframes, VideoAspect aspect, VideoResolution resolution, int fps
});


@override $AudioTrackCopyWith<$Res>? get music;@override $AdjustmentsCopyWith<$Res> get look;

}
/// @nodoc
class __$VideoProjectCopyWithImpl<$Res>
    implements _$VideoProjectCopyWith<$Res> {
  __$VideoProjectCopyWithImpl(this._self, this._then);

  final _VideoProject _self;
  final $Res Function(_VideoProject) _then;

/// Create a copy of VideoProject
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? clips = null,Object? texts = null,Object? music = freezed,Object? originalVolume = null,Object? look = null,Object? presetId = freezed,Object? lookIntensity = null,Object? lookKeyframes = null,Object? aspect = null,Object? resolution = null,Object? fps = null,}) {
  return _then(_VideoProject(
clips: null == clips ? _self._clips : clips // ignore: cast_nullable_to_non_nullable
as List<VideoClip>,texts: null == texts ? _self._texts : texts // ignore: cast_nullable_to_non_nullable
as List<VideoText>,music: freezed == music ? _self.music : music // ignore: cast_nullable_to_non_nullable
as AudioTrack?,originalVolume: null == originalVolume ? _self.originalVolume : originalVolume // ignore: cast_nullable_to_non_nullable
as double,look: null == look ? _self.look : look // ignore: cast_nullable_to_non_nullable
as Adjustments,presetId: freezed == presetId ? _self.presetId : presetId // ignore: cast_nullable_to_non_nullable
as String?,lookIntensity: null == lookIntensity ? _self.lookIntensity : lookIntensity // ignore: cast_nullable_to_non_nullable
as double,lookKeyframes: null == lookKeyframes ? _self._lookKeyframes : lookKeyframes // ignore: cast_nullable_to_non_nullable
as List<LookKeyframe>,aspect: null == aspect ? _self.aspect : aspect // ignore: cast_nullable_to_non_nullable
as VideoAspect,resolution: null == resolution ? _self.resolution : resolution // ignore: cast_nullable_to_non_nullable
as VideoResolution,fps: null == fps ? _self.fps : fps // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of VideoProject
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AudioTrackCopyWith<$Res>? get music {
    if (_self.music == null) {
    return null;
  }

  return $AudioTrackCopyWith<$Res>(_self.music!, (value) {
    return _then(_self.copyWith(music: value));
  });
}/// Create a copy of VideoProject
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AdjustmentsCopyWith<$Res> get look {
  
  return $AdjustmentsCopyWith<$Res>(_self.look, (value) {
    return _then(_self.copyWith(look: value));
  });
}
}

// dart format on
