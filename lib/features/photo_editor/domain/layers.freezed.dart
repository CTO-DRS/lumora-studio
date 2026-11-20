// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'layers.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Stroke {

 List<double> get points; int get color;/// Width relative to the shorter image side.
 double get width; double get opacity; bool get eraser;/// Softness 0..1, used by mask brushes.
 double get softness;
/// Create a copy of Stroke
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StrokeCopyWith<Stroke> get copyWith => _$StrokeCopyWithImpl<Stroke>(this as Stroke, _$identity);

  /// Serializes this Stroke to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Stroke;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Stroke&&const DeepCollectionEquality().equals(other.points, _this.points)&&(identical(other.color, _this.color) || other.color == _this.color)&&(identical(other.width, _this.width) || other.width == _this.width)&&(identical(other.opacity, _this.opacity) || other.opacity == _this.opacity)&&(identical(other.eraser, _this.eraser) || other.eraser == _this.eraser)&&(identical(other.softness, _this.softness) || other.softness == _this.softness));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Stroke;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.points),_this.color,_this.width,_this.opacity,_this.eraser,_this.softness);
}

@override
String toString() {
  final _this = this as Stroke;
  return 'Stroke(points: ${_this.points}, color: ${_this.color}, width: ${_this.width}, opacity: ${_this.opacity}, eraser: ${_this.eraser}, softness: ${_this.softness})';
}


}

/// @nodoc
abstract mixin class $StrokeCopyWith<$Res>  {
  factory $StrokeCopyWith(Stroke value, $Res Function(Stroke) _then) = _$StrokeCopyWithImpl;
@useResult
$Res call({
 List<double> points, int color, double width, double opacity, bool eraser, double softness
});




}
/// @nodoc
class _$StrokeCopyWithImpl<$Res>
    implements $StrokeCopyWith<$Res> {
  _$StrokeCopyWithImpl(this._self, this._then);

  final Stroke _self;
  final $Res Function(Stroke) _then;

/// Create a copy of Stroke
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? points = null,Object? color = null,Object? width = null,Object? opacity = null,Object? eraser = null,Object? softness = null,}) {
  return _then(Stroke(
points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as List<double>,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as int,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double,opacity: null == opacity ? _self.opacity : opacity // ignore: cast_nullable_to_non_nullable
as double,eraser: null == eraser ? _self.eraser : eraser // ignore: cast_nullable_to_non_nullable
as bool,softness: null == softness ? _self.softness : softness // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [Stroke].
extension StrokePatterns on Stroke {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Stroke value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Stroke() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Stroke value)  $default,){
final _that = this;
switch (_that) {
case _Stroke():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Stroke value)?  $default,){
final _that = this;
switch (_that) {
case _Stroke() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<double> points,  int color,  double width,  double opacity,  bool eraser,  double softness)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Stroke() when $default != null:
return $default(_that.points,_that.color,_that.width,_that.opacity,_that.eraser,_that.softness);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<double> points,  int color,  double width,  double opacity,  bool eraser,  double softness)  $default,) {final _that = this;
switch (_that) {
case _Stroke():
return $default(_that.points,_that.color,_that.width,_that.opacity,_that.eraser,_that.softness);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<double> points,  int color,  double width,  double opacity,  bool eraser,  double softness)?  $default,) {final _that = this;
switch (_that) {
case _Stroke() when $default != null:
return $default(_that.points,_that.color,_that.width,_that.opacity,_that.eraser,_that.softness);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Stroke implements Stroke {
  const _Stroke({required  List<double> points, this.color = 0xFFFFFFFF, this.width = 0.01, this.opacity = 1, this.eraser = false, this.softness = 0}): _points = points;
  factory _Stroke.fromJson(Map<String, dynamic> json) => _$StrokeFromJson(json);

 final  List<double> _points;
@override List<double> get points {
  if (_points is EqualUnmodifiableListView) return _points;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_points);
}

@override@JsonKey() final  int color;
/// Width relative to the shorter image side.
@override@JsonKey() final  double width;
@override@JsonKey() final  double opacity;
@override@JsonKey() final  bool eraser;
/// Softness 0..1, used by mask brushes.
@override@JsonKey() final  double softness;

/// Create a copy of Stroke
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StrokeCopyWith<_Stroke> get copyWith => __$StrokeCopyWithImpl<_Stroke>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StrokeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Stroke&&const DeepCollectionEquality().equals(other.points, _points)&&(identical(other.color, color) || other.color == color)&&(identical(other.width, width) || other.width == width)&&(identical(other.opacity, opacity) || other.opacity == opacity)&&(identical(other.eraser, eraser) || other.eraser == eraser)&&(identical(other.softness, softness) || other.softness == softness));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_points),color,width,opacity,eraser,softness);
}

@override
String toString() {
    return 'Stroke(points: $points, color: $color, width: $width, opacity: $opacity, eraser: $eraser, softness: $softness)';
}


}

/// @nodoc
abstract mixin class _$StrokeCopyWith<$Res> implements $StrokeCopyWith<$Res> {
  factory _$StrokeCopyWith(_Stroke value, $Res Function(_Stroke) _then) = __$StrokeCopyWithImpl;
@override @useResult
$Res call({
 List<double> points, int color, double width, double opacity, bool eraser, double softness
});




}
/// @nodoc
class __$StrokeCopyWithImpl<$Res>
    implements _$StrokeCopyWith<$Res> {
  __$StrokeCopyWithImpl(this._self, this._then);

  final _Stroke _self;
  final $Res Function(_Stroke) _then;

/// Create a copy of Stroke
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? points = null,Object? color = null,Object? width = null,Object? opacity = null,Object? eraser = null,Object? softness = null,}) {
  return _then(_Stroke(
points: null == points ? _self._points : points // ignore: cast_nullable_to_non_nullable
as List<double>,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as int,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double,opacity: null == opacity ? _self.opacity : opacity // ignore: cast_nullable_to_non_nullable
as double,eraser: null == eraser ? _self.eraser : eraser // ignore: cast_nullable_to_non_nullable
as bool,softness: null == softness ? _self.softness : softness // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

OverlayLayer _$OverlayLayerFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'text':
          return TextLayer.fromJson(
            json
          );
                case 'sticker':
          return StickerLayer.fromJson(
            json
          );
                case 'drawing':
          return DrawingLayer.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'OverlayLayer',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$OverlayLayer {

 String get id; double get opacity;
/// Create a copy of OverlayLayer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OverlayLayerCopyWith<OverlayLayer> get copyWith => _$OverlayLayerCopyWithImpl<OverlayLayer>(this as OverlayLayer, _$identity);

  /// Serializes this OverlayLayer to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as OverlayLayer;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OverlayLayer&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.opacity, _this.opacity) || other.opacity == _this.opacity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as OverlayLayer;
  return Object.hash(runtimeType,_this.id,_this.opacity);
}

@override
String toString() {
  final _this = this as OverlayLayer;
  return 'OverlayLayer(id: ${_this.id}, opacity: ${_this.opacity})';
}


}

/// @nodoc
abstract mixin class $OverlayLayerCopyWith<$Res>  {
  factory $OverlayLayerCopyWith(OverlayLayer value, $Res Function(OverlayLayer) _then) = _$OverlayLayerCopyWithImpl;
@useResult
$Res call({
 String id, double opacity
});




}
/// @nodoc
class _$OverlayLayerCopyWithImpl<$Res>
    implements $OverlayLayerCopyWith<$Res> {
  _$OverlayLayerCopyWithImpl(this._self, this._then);

  final OverlayLayer _self;
  final $Res Function(OverlayLayer) _then;

/// Create a copy of OverlayLayer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? opacity = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,opacity: null == opacity ? _self.opacity : opacity // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [OverlayLayer].
extension OverlayLayerPatterns on OverlayLayer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( TextLayer value)?  text,TResult Function( StickerLayer value)?  sticker,TResult Function( DrawingLayer value)?  drawing,required TResult orElse(),}){
final _that = this;
switch (_that) {
case TextLayer() when text != null:
return text(_that);case StickerLayer() when sticker != null:
return sticker(_that);case DrawingLayer() when drawing != null:
return drawing(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( TextLayer value)  text,required TResult Function( StickerLayer value)  sticker,required TResult Function( DrawingLayer value)  drawing,}){
final _that = this;
switch (_that) {
case TextLayer():
return text(_that);case StickerLayer():
return sticker(_that);case DrawingLayer():
return drawing(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( TextLayer value)?  text,TResult? Function( StickerLayer value)?  sticker,TResult? Function( DrawingLayer value)?  drawing,}){
final _that = this;
switch (_that) {
case TextLayer() when text != null:
return text(_that);case StickerLayer() when sticker != null:
return sticker(_that);case DrawingLayer() when drawing != null:
return drawing(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String id,  String text,  double x,  double y,  double scale,  double rotation,  double opacity,  int color,  int? backgroundColor,  double fontSize,  bool bold,  bool italic,  TextAlignment align,  bool shadow,  String? fontFamily)?  text,TResult Function( String id,  String glyph,  String? imagePath,  double x,  double y,  double scale,  double rotation,  double opacity,  double size)?  sticker,TResult Function( String id,  List<Stroke> strokes,  double opacity)?  drawing,required TResult orElse(),}) {final _that = this;
switch (_that) {
case TextLayer() when text != null:
return text(_that.id,_that.text,_that.x,_that.y,_that.scale,_that.rotation,_that.opacity,_that.color,_that.backgroundColor,_that.fontSize,_that.bold,_that.italic,_that.align,_that.shadow,_that.fontFamily);case StickerLayer() when sticker != null:
return sticker(_that.id,_that.glyph,_that.imagePath,_that.x,_that.y,_that.scale,_that.rotation,_that.opacity,_that.size);case DrawingLayer() when drawing != null:
return drawing(_that.id,_that.strokes,_that.opacity);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String id,  String text,  double x,  double y,  double scale,  double rotation,  double opacity,  int color,  int? backgroundColor,  double fontSize,  bool bold,  bool italic,  TextAlignment align,  bool shadow,  String? fontFamily)  text,required TResult Function( String id,  String glyph,  String? imagePath,  double x,  double y,  double scale,  double rotation,  double opacity,  double size)  sticker,required TResult Function( String id,  List<Stroke> strokes,  double opacity)  drawing,}) {final _that = this;
switch (_that) {
case TextLayer():
return text(_that.id,_that.text,_that.x,_that.y,_that.scale,_that.rotation,_that.opacity,_that.color,_that.backgroundColor,_that.fontSize,_that.bold,_that.italic,_that.align,_that.shadow,_that.fontFamily);case StickerLayer():
return sticker(_that.id,_that.glyph,_that.imagePath,_that.x,_that.y,_that.scale,_that.rotation,_that.opacity,_that.size);case DrawingLayer():
return drawing(_that.id,_that.strokes,_that.opacity);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String id,  String text,  double x,  double y,  double scale,  double rotation,  double opacity,  int color,  int? backgroundColor,  double fontSize,  bool bold,  bool italic,  TextAlignment align,  bool shadow,  String? fontFamily)?  text,TResult? Function( String id,  String glyph,  String? imagePath,  double x,  double y,  double scale,  double rotation,  double opacity,  double size)?  sticker,TResult? Function( String id,  List<Stroke> strokes,  double opacity)?  drawing,}) {final _that = this;
switch (_that) {
case TextLayer() when text != null:
return text(_that.id,_that.text,_that.x,_that.y,_that.scale,_that.rotation,_that.opacity,_that.color,_that.backgroundColor,_that.fontSize,_that.bold,_that.italic,_that.align,_that.shadow,_that.fontFamily);case StickerLayer() when sticker != null:
return sticker(_that.id,_that.glyph,_that.imagePath,_that.x,_that.y,_that.scale,_that.rotation,_that.opacity,_that.size);case DrawingLayer() when drawing != null:
return drawing(_that.id,_that.strokes,_that.opacity);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class TextLayer implements OverlayLayer {
  const TextLayer({required this.id, required this.text, this.x = 0.5, this.y = 0.5, this.scale = 1, this.rotation = 0, this.opacity = 1, this.color = 0xFFFFFFFF, this.backgroundColor, this.fontSize = 0.07, this.bold = false, this.italic = false, this.align = TextAlignment.center, this.shadow = true, this.fontFamily,  String? $type}): $type = $type ?? 'text';
  factory TextLayer.fromJson(Map<String, dynamic> json) => _$TextLayerFromJson(json);

@override final  String id;
 final  String text;
@JsonKey() final  double x;
@JsonKey() final  double y;
@JsonKey() final  double scale;
@JsonKey() final  double rotation;
@override@JsonKey() final  double opacity;
@JsonKey() final  int color;
 final  int? backgroundColor;
/// Font size relative to the shorter image side.
@JsonKey() final  double fontSize;
@JsonKey() final  bool bold;
@JsonKey() final  bool italic;
@JsonKey() final  TextAlignment align;
@JsonKey() final  bool shadow;
 final  String? fontFamily;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of OverlayLayer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TextLayerCopyWith<TextLayer> get copyWith => _$TextLayerCopyWithImpl<TextLayer>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TextLayerToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TextLayer&&(identical(other.id, id) || other.id == id)&&(identical(other.text, text) || other.text == text)&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y)&&(identical(other.scale, scale) || other.scale == scale)&&(identical(other.rotation, rotation) || other.rotation == rotation)&&(identical(other.opacity, opacity) || other.opacity == opacity)&&(identical(other.color, color) || other.color == color)&&(identical(other.backgroundColor, backgroundColor) || other.backgroundColor == backgroundColor)&&(identical(other.fontSize, fontSize) || other.fontSize == fontSize)&&(identical(other.bold, bold) || other.bold == bold)&&(identical(other.italic, italic) || other.italic == italic)&&(identical(other.align, align) || other.align == align)&&(identical(other.shadow, shadow) || other.shadow == shadow)&&(identical(other.fontFamily, fontFamily) || other.fontFamily == fontFamily));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,text,x,y,scale,rotation,opacity,color,backgroundColor,fontSize,bold,italic,align,shadow,fontFamily);
}

@override
String toString() {
    return 'OverlayLayer.text(id: $id, text: $text, x: $x, y: $y, scale: $scale, rotation: $rotation, opacity: $opacity, color: $color, backgroundColor: $backgroundColor, fontSize: $fontSize, bold: $bold, italic: $italic, align: $align, shadow: $shadow, fontFamily: $fontFamily)';
}


}

/// @nodoc
abstract mixin class $TextLayerCopyWith<$Res> implements $OverlayLayerCopyWith<$Res> {
  factory $TextLayerCopyWith(TextLayer value, $Res Function(TextLayer) _then) = _$TextLayerCopyWithImpl;
@override @useResult
$Res call({
 String id, String text, double x, double y, double scale, double rotation, double opacity, int color, int? backgroundColor, double fontSize, bool bold, bool italic, TextAlignment align, bool shadow, String? fontFamily
});




}
/// @nodoc
class _$TextLayerCopyWithImpl<$Res>
    implements $TextLayerCopyWith<$Res> {
  _$TextLayerCopyWithImpl(this._self, this._then);

  final TextLayer _self;
  final $Res Function(TextLayer) _then;

/// Create a copy of OverlayLayer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? text = null,Object? x = null,Object? y = null,Object? scale = null,Object? rotation = null,Object? opacity = null,Object? color = null,Object? backgroundColor = freezed,Object? fontSize = null,Object? bold = null,Object? italic = null,Object? align = null,Object? shadow = null,Object? fontFamily = freezed,}) {
  return _then(TextLayer(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as double,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as double,scale: null == scale ? _self.scale : scale // ignore: cast_nullable_to_non_nullable
as double,rotation: null == rotation ? _self.rotation : rotation // ignore: cast_nullable_to_non_nullable
as double,opacity: null == opacity ? _self.opacity : opacity // ignore: cast_nullable_to_non_nullable
as double,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as int,backgroundColor: freezed == backgroundColor ? _self.backgroundColor : backgroundColor // ignore: cast_nullable_to_non_nullable
as int?,fontSize: null == fontSize ? _self.fontSize : fontSize // ignore: cast_nullable_to_non_nullable
as double,bold: null == bold ? _self.bold : bold // ignore: cast_nullable_to_non_nullable
as bool,italic: null == italic ? _self.italic : italic // ignore: cast_nullable_to_non_nullable
as bool,align: null == align ? _self.align : align // ignore: cast_nullable_to_non_nullable
as TextAlignment,shadow: null == shadow ? _self.shadow : shadow // ignore: cast_nullable_to_non_nullable
as bool,fontFamily: freezed == fontFamily ? _self.fontFamily : fontFamily // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class StickerLayer implements OverlayLayer {
  const StickerLayer({required this.id, this.glyph = '✨', this.imagePath, this.x = 0.5, this.y = 0.5, this.scale = 1, this.rotation = 0, this.opacity = 1, this.size = 0.2,  String? $type}): $type = $type ?? 'sticker';
  factory StickerLayer.fromJson(Map<String, dynamic> json) => _$StickerLayerFromJson(json);

@override final  String id;
/// Emoji / glyph sticker. Ignored when [imagePath] is set.
@JsonKey() final  String glyph;
 final  String? imagePath;
@JsonKey() final  double x;
@JsonKey() final  double y;
@JsonKey() final  double scale;
@JsonKey() final  double rotation;
@override@JsonKey() final  double opacity;
/// Size relative to the shorter image side.
@JsonKey() final  double size;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of OverlayLayer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StickerLayerCopyWith<StickerLayer> get copyWith => _$StickerLayerCopyWithImpl<StickerLayer>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StickerLayerToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is StickerLayer&&(identical(other.id, id) || other.id == id)&&(identical(other.glyph, glyph) || other.glyph == glyph)&&(identical(other.imagePath, imagePath) || other.imagePath == imagePath)&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y)&&(identical(other.scale, scale) || other.scale == scale)&&(identical(other.rotation, rotation) || other.rotation == rotation)&&(identical(other.opacity, opacity) || other.opacity == opacity)&&(identical(other.size, size) || other.size == size));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,glyph,imagePath,x,y,scale,rotation,opacity,size);
}

@override
String toString() {
    return 'OverlayLayer.sticker(id: $id, glyph: $glyph, imagePath: $imagePath, x: $x, y: $y, scale: $scale, rotation: $rotation, opacity: $opacity, size: $size)';
}


}

/// @nodoc
abstract mixin class $StickerLayerCopyWith<$Res> implements $OverlayLayerCopyWith<$Res> {
  factory $StickerLayerCopyWith(StickerLayer value, $Res Function(StickerLayer) _then) = _$StickerLayerCopyWithImpl;
@override @useResult
$Res call({
 String id, String glyph, String? imagePath, double x, double y, double scale, double rotation, double opacity, double size
});




}
/// @nodoc
class _$StickerLayerCopyWithImpl<$Res>
    implements $StickerLayerCopyWith<$Res> {
  _$StickerLayerCopyWithImpl(this._self, this._then);

  final StickerLayer _self;
  final $Res Function(StickerLayer) _then;

/// Create a copy of OverlayLayer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? glyph = null,Object? imagePath = freezed,Object? x = null,Object? y = null,Object? scale = null,Object? rotation = null,Object? opacity = null,Object? size = null,}) {
  return _then(StickerLayer(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,glyph: null == glyph ? _self.glyph : glyph // ignore: cast_nullable_to_non_nullable
as String,imagePath: freezed == imagePath ? _self.imagePath : imagePath // ignore: cast_nullable_to_non_nullable
as String?,x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as double,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as double,scale: null == scale ? _self.scale : scale // ignore: cast_nullable_to_non_nullable
as double,rotation: null == rotation ? _self.rotation : rotation // ignore: cast_nullable_to_non_nullable
as double,opacity: null == opacity ? _self.opacity : opacity // ignore: cast_nullable_to_non_nullable
as double,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc
@JsonSerializable()

class DrawingLayer implements OverlayLayer {
  const DrawingLayer({required this.id,  List<Stroke> strokes = const <Stroke>[], this.opacity = 1,  String? $type}): _strokes = strokes,$type = $type ?? 'drawing';
  factory DrawingLayer.fromJson(Map<String, dynamic> json) => _$DrawingLayerFromJson(json);

@override final  String id;
 final  List<Stroke> _strokes;
@JsonKey() List<Stroke> get strokes {
  if (_strokes is EqualUnmodifiableListView) return _strokes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_strokes);
}

@override@JsonKey() final  double opacity;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of OverlayLayer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DrawingLayerCopyWith<DrawingLayer> get copyWith => _$DrawingLayerCopyWithImpl<DrawingLayer>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DrawingLayerToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is DrawingLayer&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other.strokes, _strokes)&&(identical(other.opacity, opacity) || other.opacity == opacity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,const DeepCollectionEquality().hash(_strokes),opacity);
}

@override
String toString() {
    return 'OverlayLayer.drawing(id: $id, strokes: $strokes, opacity: $opacity)';
}


}

/// @nodoc
abstract mixin class $DrawingLayerCopyWith<$Res> implements $OverlayLayerCopyWith<$Res> {
  factory $DrawingLayerCopyWith(DrawingLayer value, $Res Function(DrawingLayer) _then) = _$DrawingLayerCopyWithImpl;
@override @useResult
$Res call({
 String id, List<Stroke> strokes, double opacity
});




}
/// @nodoc
class _$DrawingLayerCopyWithImpl<$Res>
    implements $DrawingLayerCopyWith<$Res> {
  _$DrawingLayerCopyWithImpl(this._self, this._then);

  final DrawingLayer _self;
  final $Res Function(DrawingLayer) _then;

/// Create a copy of OverlayLayer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? strokes = null,Object? opacity = null,}) {
  return _then(DrawingLayer(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,strokes: null == strokes ? _self._strokes : strokes // ignore: cast_nullable_to_non_nullable
as List<Stroke>,opacity: null == opacity ? _self.opacity : opacity // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}


/// @nodoc
mixin _$LocalAdjustment {

 String get id; MaskKind get kind; Adjustments get adjustments;/// linear: x0, y0, x1, y1 – radial: cx, cy, rx, ry (normalized).
 List<double> get geometry; double get rotation; double get feather; bool get invert; double get amount; List<Stroke> get strokes;/// Grayscale mask PNG for [MaskKind.subject].
 String? get maskPath; bool get enabled;
/// Create a copy of LocalAdjustment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LocalAdjustmentCopyWith<LocalAdjustment> get copyWith => _$LocalAdjustmentCopyWithImpl<LocalAdjustment>(this as LocalAdjustment, _$identity);

  /// Serializes this LocalAdjustment to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LocalAdjustment;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LocalAdjustment&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.adjustments, _this.adjustments) || other.adjustments == _this.adjustments)&&const DeepCollectionEquality().equals(other.geometry, _this.geometry)&&(identical(other.rotation, _this.rotation) || other.rotation == _this.rotation)&&(identical(other.feather, _this.feather) || other.feather == _this.feather)&&(identical(other.invert, _this.invert) || other.invert == _this.invert)&&(identical(other.amount, _this.amount) || other.amount == _this.amount)&&const DeepCollectionEquality().equals(other.strokes, _this.strokes)&&(identical(other.maskPath, _this.maskPath) || other.maskPath == _this.maskPath)&&(identical(other.enabled, _this.enabled) || other.enabled == _this.enabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LocalAdjustment;
  return Object.hash(runtimeType,_this.id,_this.kind,_this.adjustments,const DeepCollectionEquality().hash(_this.geometry),_this.rotation,_this.feather,_this.invert,_this.amount,const DeepCollectionEquality().hash(_this.strokes),_this.maskPath,_this.enabled);
}

@override
String toString() {
  final _this = this as LocalAdjustment;
  return 'LocalAdjustment(id: ${_this.id}, kind: ${_this.kind}, adjustments: ${_this.adjustments}, geometry: ${_this.geometry}, rotation: ${_this.rotation}, feather: ${_this.feather}, invert: ${_this.invert}, amount: ${_this.amount}, strokes: ${_this.strokes}, maskPath: ${_this.maskPath}, enabled: ${_this.enabled})';
}


}

/// @nodoc
abstract mixin class $LocalAdjustmentCopyWith<$Res>  {
  factory $LocalAdjustmentCopyWith(LocalAdjustment value, $Res Function(LocalAdjustment) _then) = _$LocalAdjustmentCopyWithImpl;
@useResult
$Res call({
 String id, MaskKind kind, Adjustments adjustments, List<double> geometry, double rotation, double feather, bool invert, double amount, List<Stroke> strokes, String? maskPath, bool enabled
});


$AdjustmentsCopyWith<$Res> get adjustments;

}
/// @nodoc
class _$LocalAdjustmentCopyWithImpl<$Res>
    implements $LocalAdjustmentCopyWith<$Res> {
  _$LocalAdjustmentCopyWithImpl(this._self, this._then);

  final LocalAdjustment _self;
  final $Res Function(LocalAdjustment) _then;

/// Create a copy of LocalAdjustment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? kind = null,Object? adjustments = null,Object? geometry = null,Object? rotation = null,Object? feather = null,Object? invert = null,Object? amount = null,Object? strokes = null,Object? maskPath = freezed,Object? enabled = null,}) {
  return _then(LocalAdjustment(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as MaskKind,adjustments: null == adjustments ? _self.adjustments : adjustments // ignore: cast_nullable_to_non_nullable
as Adjustments,geometry: null == geometry ? _self.geometry : geometry // ignore: cast_nullable_to_non_nullable
as List<double>,rotation: null == rotation ? _self.rotation : rotation // ignore: cast_nullable_to_non_nullable
as double,feather: null == feather ? _self.feather : feather // ignore: cast_nullable_to_non_nullable
as double,invert: null == invert ? _self.invert : invert // ignore: cast_nullable_to_non_nullable
as bool,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,strokes: null == strokes ? _self.strokes : strokes // ignore: cast_nullable_to_non_nullable
as List<Stroke>,maskPath: freezed == maskPath ? _self.maskPath : maskPath // ignore: cast_nullable_to_non_nullable
as String?,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of LocalAdjustment
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AdjustmentsCopyWith<$Res> get adjustments {
  
  return $AdjustmentsCopyWith<$Res>(_self.adjustments, (value) {
    return _then(_self.copyWith(adjustments: value));
  });
}
}


/// Adds pattern-matching-related methods to [LocalAdjustment].
extension LocalAdjustmentPatterns on LocalAdjustment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LocalAdjustment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LocalAdjustment() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LocalAdjustment value)  $default,){
final _that = this;
switch (_that) {
case _LocalAdjustment():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LocalAdjustment value)?  $default,){
final _that = this;
switch (_that) {
case _LocalAdjustment() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  MaskKind kind,  Adjustments adjustments,  List<double> geometry,  double rotation,  double feather,  bool invert,  double amount,  List<Stroke> strokes,  String? maskPath,  bool enabled)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LocalAdjustment() when $default != null:
return $default(_that.id,_that.kind,_that.adjustments,_that.geometry,_that.rotation,_that.feather,_that.invert,_that.amount,_that.strokes,_that.maskPath,_that.enabled);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  MaskKind kind,  Adjustments adjustments,  List<double> geometry,  double rotation,  double feather,  bool invert,  double amount,  List<Stroke> strokes,  String? maskPath,  bool enabled)  $default,) {final _that = this;
switch (_that) {
case _LocalAdjustment():
return $default(_that.id,_that.kind,_that.adjustments,_that.geometry,_that.rotation,_that.feather,_that.invert,_that.amount,_that.strokes,_that.maskPath,_that.enabled);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  MaskKind kind,  Adjustments adjustments,  List<double> geometry,  double rotation,  double feather,  bool invert,  double amount,  List<Stroke> strokes,  String? maskPath,  bool enabled)?  $default,) {final _that = this;
switch (_that) {
case _LocalAdjustment() when $default != null:
return $default(_that.id,_that.kind,_that.adjustments,_that.geometry,_that.rotation,_that.feather,_that.invert,_that.amount,_that.strokes,_that.maskPath,_that.enabled);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LocalAdjustment implements LocalAdjustment {
  const _LocalAdjustment({required this.id, required this.kind, this.adjustments = const Adjustments(),  List<double> geometry = const [0.5, 0.3, 0.5, 0.7], this.rotation = 0, this.feather = 0.35, this.invert = false, this.amount = 1,  List<Stroke> strokes = const <Stroke>[], this.maskPath, this.enabled = true}): _geometry = geometry,_strokes = strokes;
  factory _LocalAdjustment.fromJson(Map<String, dynamic> json) => _$LocalAdjustmentFromJson(json);

@override final  String id;
@override final  MaskKind kind;
@override@JsonKey() final  Adjustments adjustments;
/// linear: x0, y0, x1, y1 – radial: cx, cy, rx, ry (normalized).
 final  List<double> _geometry;
/// linear: x0, y0, x1, y1 – radial: cx, cy, rx, ry (normalized).
@override@JsonKey() List<double> get geometry {
  if (_geometry is EqualUnmodifiableListView) return _geometry;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_geometry);
}

@override@JsonKey() final  double rotation;
@override@JsonKey() final  double feather;
@override@JsonKey() final  bool invert;
@override@JsonKey() final  double amount;
 final  List<Stroke> _strokes;
@override@JsonKey() List<Stroke> get strokes {
  if (_strokes is EqualUnmodifiableListView) return _strokes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_strokes);
}

/// Grayscale mask PNG for [MaskKind.subject].
@override final  String? maskPath;
@override@JsonKey() final  bool enabled;

/// Create a copy of LocalAdjustment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LocalAdjustmentCopyWith<_LocalAdjustment> get copyWith => __$LocalAdjustmentCopyWithImpl<_LocalAdjustment>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LocalAdjustmentToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LocalAdjustment&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.adjustments, adjustments) || other.adjustments == adjustments)&&const DeepCollectionEquality().equals(other.geometry, _geometry)&&(identical(other.rotation, rotation) || other.rotation == rotation)&&(identical(other.feather, feather) || other.feather == feather)&&(identical(other.invert, invert) || other.invert == invert)&&(identical(other.amount, amount) || other.amount == amount)&&const DeepCollectionEquality().equals(other.strokes, _strokes)&&(identical(other.maskPath, maskPath) || other.maskPath == maskPath)&&(identical(other.enabled, enabled) || other.enabled == enabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,kind,adjustments,const DeepCollectionEquality().hash(_geometry),rotation,feather,invert,amount,const DeepCollectionEquality().hash(_strokes),maskPath,enabled);
}

@override
String toString() {
    return 'LocalAdjustment(id: $id, kind: $kind, adjustments: $adjustments, geometry: $geometry, rotation: $rotation, feather: $feather, invert: $invert, amount: $amount, strokes: $strokes, maskPath: $maskPath, enabled: $enabled)';
}


}

/// @nodoc
abstract mixin class _$LocalAdjustmentCopyWith<$Res> implements $LocalAdjustmentCopyWith<$Res> {
  factory _$LocalAdjustmentCopyWith(_LocalAdjustment value, $Res Function(_LocalAdjustment) _then) = __$LocalAdjustmentCopyWithImpl;
@override @useResult
$Res call({
 String id, MaskKind kind, Adjustments adjustments, List<double> geometry, double rotation, double feather, bool invert, double amount, List<Stroke> strokes, String? maskPath, bool enabled
});


@override $AdjustmentsCopyWith<$Res> get adjustments;

}
/// @nodoc
class __$LocalAdjustmentCopyWithImpl<$Res>
    implements _$LocalAdjustmentCopyWith<$Res> {
  __$LocalAdjustmentCopyWithImpl(this._self, this._then);

  final _LocalAdjustment _self;
  final $Res Function(_LocalAdjustment) _then;

/// Create a copy of LocalAdjustment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? kind = null,Object? adjustments = null,Object? geometry = null,Object? rotation = null,Object? feather = null,Object? invert = null,Object? amount = null,Object? strokes = null,Object? maskPath = freezed,Object? enabled = null,}) {
  return _then(_LocalAdjustment(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as MaskKind,adjustments: null == adjustments ? _self.adjustments : adjustments // ignore: cast_nullable_to_non_nullable
as Adjustments,geometry: null == geometry ? _self._geometry : geometry // ignore: cast_nullable_to_non_nullable
as List<double>,rotation: null == rotation ? _self.rotation : rotation // ignore: cast_nullable_to_non_nullable
as double,feather: null == feather ? _self.feather : feather // ignore: cast_nullable_to_non_nullable
as double,invert: null == invert ? _self.invert : invert // ignore: cast_nullable_to_non_nullable
as bool,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,strokes: null == strokes ? _self._strokes : strokes // ignore: cast_nullable_to_non_nullable
as List<Stroke>,maskPath: freezed == maskPath ? _self.maskPath : maskPath // ignore: cast_nullable_to_non_nullable
as String?,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of LocalAdjustment
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AdjustmentsCopyWith<$Res> get adjustments {
  
  return $AdjustmentsCopyWith<$Res>(_self.adjustments, (value) {
    return _then(_self.copyWith(adjustments: value));
  });
}
}

// dart format on
