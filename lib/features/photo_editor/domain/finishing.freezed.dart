// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'finishing.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FrameSettings {

 FrameStyle get style;/// Border thickness relative to the photo's shorter side.
 double get width; int get color; FrameFill get fill;/// Corner radius of the photo inside the frame, relative to its shorter side.
 double get cornerRadius;/// Target aspect ratio (w / h) for [FrameStyle.fitAspect].
 double get aspect;
/// Create a copy of FrameSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FrameSettingsCopyWith<FrameSettings> get copyWith => _$FrameSettingsCopyWithImpl<FrameSettings>(this as FrameSettings, _$identity);

  /// Serializes this FrameSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as FrameSettings;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FrameSettings&&(identical(other.style, _this.style) || other.style == _this.style)&&(identical(other.width, _this.width) || other.width == _this.width)&&(identical(other.color, _this.color) || other.color == _this.color)&&(identical(other.fill, _this.fill) || other.fill == _this.fill)&&(identical(other.cornerRadius, _this.cornerRadius) || other.cornerRadius == _this.cornerRadius)&&(identical(other.aspect, _this.aspect) || other.aspect == _this.aspect));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as FrameSettings;
  return Object.hash(runtimeType,_this.style,_this.width,_this.color,_this.fill,_this.cornerRadius,_this.aspect);
}

@override
String toString() {
  final _this = this as FrameSettings;
  return 'FrameSettings(style: ${_this.style}, width: ${_this.width}, color: ${_this.color}, fill: ${_this.fill}, cornerRadius: ${_this.cornerRadius}, aspect: ${_this.aspect})';
}


}

/// @nodoc
abstract mixin class $FrameSettingsCopyWith<$Res>  {
  factory $FrameSettingsCopyWith(FrameSettings value, $Res Function(FrameSettings) _then) = _$FrameSettingsCopyWithImpl;
@useResult
$Res call({
 FrameStyle style, double width, int color, FrameFill fill, double cornerRadius, double aspect
});




}
/// @nodoc
class _$FrameSettingsCopyWithImpl<$Res>
    implements $FrameSettingsCopyWith<$Res> {
  _$FrameSettingsCopyWithImpl(this._self, this._then);

  final FrameSettings _self;
  final $Res Function(FrameSettings) _then;

/// Create a copy of FrameSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? style = null,Object? width = null,Object? color = null,Object? fill = null,Object? cornerRadius = null,Object? aspect = null,}) {
  return _then(FrameSettings(
style: null == style ? _self.style : style // ignore: cast_nullable_to_non_nullable
as FrameStyle,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as int,fill: null == fill ? _self.fill : fill // ignore: cast_nullable_to_non_nullable
as FrameFill,cornerRadius: null == cornerRadius ? _self.cornerRadius : cornerRadius // ignore: cast_nullable_to_non_nullable
as double,aspect: null == aspect ? _self.aspect : aspect // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [FrameSettings].
extension FrameSettingsPatterns on FrameSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FrameSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FrameSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FrameSettings value)  $default,){
final _that = this;
switch (_that) {
case _FrameSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FrameSettings value)?  $default,){
final _that = this;
switch (_that) {
case _FrameSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( FrameStyle style,  double width,  int color,  FrameFill fill,  double cornerRadius,  double aspect)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FrameSettings() when $default != null:
return $default(_that.style,_that.width,_that.color,_that.fill,_that.cornerRadius,_that.aspect);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( FrameStyle style,  double width,  int color,  FrameFill fill,  double cornerRadius,  double aspect)  $default,) {final _that = this;
switch (_that) {
case _FrameSettings():
return $default(_that.style,_that.width,_that.color,_that.fill,_that.cornerRadius,_that.aspect);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( FrameStyle style,  double width,  int color,  FrameFill fill,  double cornerRadius,  double aspect)?  $default,) {final _that = this;
switch (_that) {
case _FrameSettings() when $default != null:
return $default(_that.style,_that.width,_that.color,_that.fill,_that.cornerRadius,_that.aspect);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FrameSettings extends FrameSettings {
  const _FrameSettings({this.style = FrameStyle.none, this.width = 0.04, this.color = 0xFFFFFFFF, this.fill = FrameFill.color, this.cornerRadius = 0, this.aspect = 1}): super._();
  factory _FrameSettings.fromJson(Map<String, dynamic> json) => _$FrameSettingsFromJson(json);

@override@JsonKey() final  FrameStyle style;
/// Border thickness relative to the photo's shorter side.
@override@JsonKey() final  double width;
@override@JsonKey() final  int color;
@override@JsonKey() final  FrameFill fill;
/// Corner radius of the photo inside the frame, relative to its shorter side.
@override@JsonKey() final  double cornerRadius;
/// Target aspect ratio (w / h) for [FrameStyle.fitAspect].
@override@JsonKey() final  double aspect;

/// Create a copy of FrameSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FrameSettingsCopyWith<_FrameSettings> get copyWith => __$FrameSettingsCopyWithImpl<_FrameSettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FrameSettingsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FrameSettings&&(identical(other.style, style) || other.style == style)&&(identical(other.width, width) || other.width == width)&&(identical(other.color, color) || other.color == color)&&(identical(other.fill, fill) || other.fill == fill)&&(identical(other.cornerRadius, cornerRadius) || other.cornerRadius == cornerRadius)&&(identical(other.aspect, aspect) || other.aspect == aspect));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,style,width,color,fill,cornerRadius,aspect);
}

@override
String toString() {
    return 'FrameSettings(style: $style, width: $width, color: $color, fill: $fill, cornerRadius: $cornerRadius, aspect: $aspect)';
}


}

/// @nodoc
abstract mixin class _$FrameSettingsCopyWith<$Res> implements $FrameSettingsCopyWith<$Res> {
  factory _$FrameSettingsCopyWith(_FrameSettings value, $Res Function(_FrameSettings) _then) = __$FrameSettingsCopyWithImpl;
@override @useResult
$Res call({
 FrameStyle style, double width, int color, FrameFill fill, double cornerRadius, double aspect
});




}
/// @nodoc
class __$FrameSettingsCopyWithImpl<$Res>
    implements _$FrameSettingsCopyWith<$Res> {
  __$FrameSettingsCopyWithImpl(this._self, this._then);

  final _FrameSettings _self;
  final $Res Function(_FrameSettings) _then;

/// Create a copy of FrameSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? style = null,Object? width = null,Object? color = null,Object? fill = null,Object? cornerRadius = null,Object? aspect = null,}) {
  return _then(_FrameSettings(
style: null == style ? _self.style : style // ignore: cast_nullable_to_non_nullable
as FrameStyle,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as int,fill: null == fill ? _self.fill : fill // ignore: cast_nullable_to_non_nullable
as FrameFill,cornerRadius: null == cornerRadius ? _self.cornerRadius : cornerRadius // ignore: cast_nullable_to_non_nullable
as double,aspect: null == aspect ? _self.aspect : aspect // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}


/// @nodoc
mixin _$WatermarkSettings {

 String get text;/// Optional logo image (PNG with transparency works best).
 String? get logoPath; WatermarkAnchor get anchor;/// Text size / logo height relative to the shorter side of the image.
 double get size; double get opacity; int get color;/// Distance from the edges relative to the shorter side.
 double get margin; bool get shadow;
/// Create a copy of WatermarkSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WatermarkSettingsCopyWith<WatermarkSettings> get copyWith => _$WatermarkSettingsCopyWithImpl<WatermarkSettings>(this as WatermarkSettings, _$identity);

  /// Serializes this WatermarkSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as WatermarkSettings;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WatermarkSettings&&(identical(other.text, _this.text) || other.text == _this.text)&&(identical(other.logoPath, _this.logoPath) || other.logoPath == _this.logoPath)&&(identical(other.anchor, _this.anchor) || other.anchor == _this.anchor)&&(identical(other.size, _this.size) || other.size == _this.size)&&(identical(other.opacity, _this.opacity) || other.opacity == _this.opacity)&&(identical(other.color, _this.color) || other.color == _this.color)&&(identical(other.margin, _this.margin) || other.margin == _this.margin)&&(identical(other.shadow, _this.shadow) || other.shadow == _this.shadow));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as WatermarkSettings;
  return Object.hash(runtimeType,_this.text,_this.logoPath,_this.anchor,_this.size,_this.opacity,_this.color,_this.margin,_this.shadow);
}

@override
String toString() {
  final _this = this as WatermarkSettings;
  return 'WatermarkSettings(text: ${_this.text}, logoPath: ${_this.logoPath}, anchor: ${_this.anchor}, size: ${_this.size}, opacity: ${_this.opacity}, color: ${_this.color}, margin: ${_this.margin}, shadow: ${_this.shadow})';
}


}

/// @nodoc
abstract mixin class $WatermarkSettingsCopyWith<$Res>  {
  factory $WatermarkSettingsCopyWith(WatermarkSettings value, $Res Function(WatermarkSettings) _then) = _$WatermarkSettingsCopyWithImpl;
@useResult
$Res call({
 String text, String? logoPath, WatermarkAnchor anchor, double size, double opacity, int color, double margin, bool shadow
});




}
/// @nodoc
class _$WatermarkSettingsCopyWithImpl<$Res>
    implements $WatermarkSettingsCopyWith<$Res> {
  _$WatermarkSettingsCopyWithImpl(this._self, this._then);

  final WatermarkSettings _self;
  final $Res Function(WatermarkSettings) _then;

/// Create a copy of WatermarkSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? text = null,Object? logoPath = freezed,Object? anchor = null,Object? size = null,Object? opacity = null,Object? color = null,Object? margin = null,Object? shadow = null,}) {
  return _then(WatermarkSettings(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,logoPath: freezed == logoPath ? _self.logoPath : logoPath // ignore: cast_nullable_to_non_nullable
as String?,anchor: null == anchor ? _self.anchor : anchor // ignore: cast_nullable_to_non_nullable
as WatermarkAnchor,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as double,opacity: null == opacity ? _self.opacity : opacity // ignore: cast_nullable_to_non_nullable
as double,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as int,margin: null == margin ? _self.margin : margin // ignore: cast_nullable_to_non_nullable
as double,shadow: null == shadow ? _self.shadow : shadow // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [WatermarkSettings].
extension WatermarkSettingsPatterns on WatermarkSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WatermarkSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WatermarkSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WatermarkSettings value)  $default,){
final _that = this;
switch (_that) {
case _WatermarkSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WatermarkSettings value)?  $default,){
final _that = this;
switch (_that) {
case _WatermarkSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String text,  String? logoPath,  WatermarkAnchor anchor,  double size,  double opacity,  int color,  double margin,  bool shadow)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WatermarkSettings() when $default != null:
return $default(_that.text,_that.logoPath,_that.anchor,_that.size,_that.opacity,_that.color,_that.margin,_that.shadow);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String text,  String? logoPath,  WatermarkAnchor anchor,  double size,  double opacity,  int color,  double margin,  bool shadow)  $default,) {final _that = this;
switch (_that) {
case _WatermarkSettings():
return $default(_that.text,_that.logoPath,_that.anchor,_that.size,_that.opacity,_that.color,_that.margin,_that.shadow);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String text,  String? logoPath,  WatermarkAnchor anchor,  double size,  double opacity,  int color,  double margin,  bool shadow)?  $default,) {final _that = this;
switch (_that) {
case _WatermarkSettings() when $default != null:
return $default(_that.text,_that.logoPath,_that.anchor,_that.size,_that.opacity,_that.color,_that.margin,_that.shadow);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WatermarkSettings extends WatermarkSettings {
  const _WatermarkSettings({this.text = '', this.logoPath, this.anchor = WatermarkAnchor.bottomRight, this.size = 0.045, this.opacity = 0.75, this.color = 0xFFFFFFFF, this.margin = 0.03, this.shadow = true}): super._();
  factory _WatermarkSettings.fromJson(Map<String, dynamic> json) => _$WatermarkSettingsFromJson(json);

@override@JsonKey() final  String text;
/// Optional logo image (PNG with transparency works best).
@override final  String? logoPath;
@override@JsonKey() final  WatermarkAnchor anchor;
/// Text size / logo height relative to the shorter side of the image.
@override@JsonKey() final  double size;
@override@JsonKey() final  double opacity;
@override@JsonKey() final  int color;
/// Distance from the edges relative to the shorter side.
@override@JsonKey() final  double margin;
@override@JsonKey() final  bool shadow;

/// Create a copy of WatermarkSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WatermarkSettingsCopyWith<_WatermarkSettings> get copyWith => __$WatermarkSettingsCopyWithImpl<_WatermarkSettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WatermarkSettingsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WatermarkSettings&&(identical(other.text, text) || other.text == text)&&(identical(other.logoPath, logoPath) || other.logoPath == logoPath)&&(identical(other.anchor, anchor) || other.anchor == anchor)&&(identical(other.size, size) || other.size == size)&&(identical(other.opacity, opacity) || other.opacity == opacity)&&(identical(other.color, color) || other.color == color)&&(identical(other.margin, margin) || other.margin == margin)&&(identical(other.shadow, shadow) || other.shadow == shadow));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,text,logoPath,anchor,size,opacity,color,margin,shadow);
}

@override
String toString() {
    return 'WatermarkSettings(text: $text, logoPath: $logoPath, anchor: $anchor, size: $size, opacity: $opacity, color: $color, margin: $margin, shadow: $shadow)';
}


}

/// @nodoc
abstract mixin class _$WatermarkSettingsCopyWith<$Res> implements $WatermarkSettingsCopyWith<$Res> {
  factory _$WatermarkSettingsCopyWith(_WatermarkSettings value, $Res Function(_WatermarkSettings) _then) = __$WatermarkSettingsCopyWithImpl;
@override @useResult
$Res call({
 String text, String? logoPath, WatermarkAnchor anchor, double size, double opacity, int color, double margin, bool shadow
});




}
/// @nodoc
class __$WatermarkSettingsCopyWithImpl<$Res>
    implements _$WatermarkSettingsCopyWith<$Res> {
  __$WatermarkSettingsCopyWithImpl(this._self, this._then);

  final _WatermarkSettings _self;
  final $Res Function(_WatermarkSettings) _then;

/// Create a copy of WatermarkSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? text = null,Object? logoPath = freezed,Object? anchor = null,Object? size = null,Object? opacity = null,Object? color = null,Object? margin = null,Object? shadow = null,}) {
  return _then(_WatermarkSettings(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,logoPath: freezed == logoPath ? _self.logoPath : logoPath // ignore: cast_nullable_to_non_nullable
as String?,anchor: null == anchor ? _self.anchor : anchor // ignore: cast_nullable_to_non_nullable
as WatermarkAnchor,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as double,opacity: null == opacity ? _self.opacity : opacity // ignore: cast_nullable_to_non_nullable
as double,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as int,margin: null == margin ? _self.margin : margin // ignore: cast_nullable_to_non_nullable
as double,shadow: null == shadow ? _self.shadow : shadow // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
