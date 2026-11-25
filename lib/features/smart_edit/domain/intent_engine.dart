import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/smart_edit/domain/edit_ops.dart';
import 'package:lumora/features/smart_edit/domain/text_normalizer.dart';

/// Turns a typed (or dictated) instruction into a [SmartEditPlan].
///
/// [RuleIntentEngine] is deterministic, instant and works offline in
/// Arabic and English. An on-device language model can implement the same
/// interface later and emit the same plan JSON (see docs/SMART_EDIT.md);
/// the editor does not need to change.
abstract class EditIntentEngine {
  SmartEditPlan parse(String text);
}

// ---------------------------------------------------------------------------
// Lexicon

enum _K {
  inc,
  dec,
  slight,
  strong,
  remove,
  param,
  look,
  action,
  background,
  person,
  object,
  blemish,
  blur,
  depth,
  cut,
  subject,
  skin,
  eyes,
  teeth,
  sky,
  replace,
  sunsetSky,
  clearSky,
  stormSky,
  filter,
  rotate,
  rotateWeak,
  left,
  right,
  vertical,
  relight,
  filler,
}

class _E {
  const _E(this.kind, {this.param, this.look, this.action, this.dir = 1, this.exact = false});

  final _K kind;
  final AdjustmentParam? param;
  final String? look;
  final SmartAction? action;

  /// Implicit direction of a parameter word ("darker" = -1).
  final int dir;

  /// Only an exact token match counts (short or ambiguous words).
  final bool exact;
}

_E _p(AdjustmentParam p, [int dir = 1]) => _E(_K.param, param: p, dir: dir);
_E _look(String id) => _E(_K.look, look: id);
_E _act(SmartAction a) => _E(_K.action, action: a);

/// Multi-word phrases, replaced by a canonical token before tokenising
/// (so "black and white" is not split at "and").
const Map<String, String> _phrasesRaw = {
  // looks
  'black and white': '@mono',
  'black n white': '@mono',
  'black white': '@mono',
  'b and w': '@mono',
  'b/w': '@mono',
  'b&w': '@mono',
  'ابيض واسود': '@mono',
  'ابيض و اسود': '@mono',
  'اسود وابيض': '@mono',
  'اسود و ابيض': '@mono',
  'الابيض والاسود': '@mono',
  'بالابيض والاسود': '@mono',
  'teal and orange': '@teal',
  'orange and teal': '@teal',
  'golden hour': '@golden',
  'الساعه الذهبيه': '@golden',
  'film noir': '@noir',
  'old film': '@expired',
  'فيلم قديم': '@expired',
  'night city': '@night',
  // actions
  'start over': '@reset',
  'clear all': '@reset',
  'undo all': '@reset',
  'اعاده ضبط': '@reset',
  'اعد ضبط': '@reset',
  'من جديد': '@reset',
  'الغ كل': '@reset',
  'portrait mode': '@depth',
  'وضع البورتريه': '@depth',
  'وضع البورتريت': '@depth',
  'lens blur': '@depth',
  'depth of field': '@depth',
  'عمق الميدان': '@depth',
  'cut out': '@cut',
  'get rid of': '@remove',
  'take out': '@remove',
  'super resolution': '@upscale',
  'lip colour': '@lips',
  'lip color': '@lips',
  'lipstick': '@lips',
  'tint my lips': '@lips',
  'color my lips': '@lips',
  'colour my lips': '@lips',
  'red lips': '@lips',
  'احمر الشفاه': '@lips',
  'لون الشفاه': '@lips',
  'لون شفاهي': '@lips',
  'لون الشفايف': '@lips',
  'شفاه حمراء': '@lips',
  'enhance brows': '@brows',
  'enhance eyebrows': '@brows',
  'define brows': '@brows',
  'define my eyebrows': '@brows',
  'darken brows': '@brows',
  'darken eyebrows': '@brows',
  'thicken brows': '@brows',
  'حسن الحواجب': '@brows',
  'تحسين الحواجب': '@brows',
  'قوي الحواجب': '@brows',
  'ظلل الحواجب': '@brows',
  'غمق الحواجب': '@brows',
  'اغمق الحواجب': '@brows',
  'low light': '@lowlight',
  'night photo': '@lowlight',
  'night shot': '@lowlight',
  'night picture': '@lowlight',
  'dark photo': '@lowlight',
  'dark picture': '@lowlight',
  'dark image': '@lowlight',
  'fix this dark photo': '@lowlight',
  'fix the dark photo': '@lowlight',
  'fix dark photo': '@lowlight',
  'denoise': '@lowlight',
  'de noise': '@lowlight',
  'reduce noise': '@lowlight',
  'reduce the noise': '@lowlight',
  'remove noise': '@lowlight',
  'remove the noise': '@lowlight',
  'noise reduction': '@lowlight',
  'less noise': '@lowlight',
  'قلل الضجيج': '@lowlight',
  'ازل الضجيج': '@lowlight',
  'تقليل الضجيج': '@lowlight',
  'ازاله الضجيج': '@lowlight',
  'حسن الصوره الليليه': '@lowlight',
  'تحسين الصوره الليليه': '@lowlight',
  'صوره ليليه': '@lowlight',
  'اضاءه خافته': '@lowlight',
  'صوره مظلمه': '@lowlight',
  'اصلح الصوره المظلمه': '@lowlight',
  'انقذ الصوره المظلمه': '@lowlight',
  'تقليل التشويش': '@lowlight',
  'ازل التشويش': '@lowlight',
  'قلل التشويش': '@lowlight',
  'خلفيه شفافه': '@nobg',
  'transparent background': '@nobg',
  'no background': '@nobg',
  'بدون خلفيه': '@nobg',
  'بلا خلفيه': '@nobg',
  'المناطق المضيئه': '@highlights',
  'المناطق الساطعه': '@highlights',
  'المناطق المظلمه': '@shadows',
  'المناطق الداكنه': '@shadows',
  'تعتيم الحواف': '@vignette',
  'اطراف داكنه': '@vignette',
  'dark edges': '@vignette',
  'darken edges': '@vignette',
  // modifiers
  'a bit': '@slight',
  'a little': '@slight',
  'a touch': '@slight',
  'a tad': '@slight',
  'بشكل بسيط': '@slight',
  'بشكل خفيف': '@slight',
  'شوي شوي': '@slight',
  'شويه شويه': '@slight',
  'a lot': '@strong',
  'way more': '@strong',
  'بشكل كبير': '@strong',
  'بشكل واضح': '@strong',
  'tone down': '@dec',
  // dialect (v1.3.x pass)
  'على السريع': '@auto',
  'ع السريع': '@auto',
};

final Map<String, _E> _lexiconRaw = {
  // canonical phrase tokens
  '@mono': _look('mono'),
  '@teal': _look('teal_orange'),
  '@golden': _look('golden_hour'),
  '@noir': _look('noir'),
  '@expired': _look('expired'),
  '@night': _look('night_city'),
  '@reset': _act(SmartAction.reset),
  '@depth': const _E(_K.depth),
  '@cut': const _E(_K.cut),
  '@remove': const _E(_K.remove),
  '@upscale': _act(SmartAction.upscale),
  '@lowlight': _act(SmartAction.lowLightRescue),
  '@lips': _act(SmartAction.lipColour),
  '@brows': _act(SmartAction.browEnhance),
  '@nobg': _act(SmartAction.removeBackground),
  '@highlights': _p(AdjustmentParam.highlights),
  '@shadows': _p(AdjustmentParam.shadows),
  '@vignette': _p(AdjustmentParam.vignette),
  '@slight': const _E(_K.slight),
  '@strong': const _E(_K.strong),
  '@dec': const _E(_K.dec),
  '@auto': _act(SmartAction.autoEnhance),

  // ---- direction
  'زد': const _E(_K.inc),
  'زيد': const _E(_K.inc),
  'زود': const _E(_K.inc),
  'زياده': const _E(_K.inc),
  'ارفع': const _E(_K.inc),
  'رفع': const _E(_K.inc),
  'اكثر': const _E(_K.inc),
  'اكتر': const _E(_K.inc),
  'اعلي': const _E(_K.inc),
  'اضف': const _E(_K.inc),
  'ضيف': const _E(_K.inc),
  'اضافه': const _E(_K.inc),
  'قوي': const _E(_K.inc),
  'more': const _E(_K.inc),
  'increas': const _E(_K.inc),
  'boost': const _E(_K.inc),
  'rais': const _E(_K.inc),
  'add': const _E(_K.inc, exact: true),
  'higher': const _E(_K.inc),
  'up': const _E(_K.inc, exact: true),
  'extra': const _E(_K.inc),
  'stronger': const _E(_K.inc),
  'lift': const _E(_K.inc),
  'recover': const _E(_K.dec),
  'deepen': const _E(_K.dec),
  'crush': const _E(_K.dec),
  'tame': const _E(_K.dec),
  'enhance': const _E(_K.inc, exact: true), // "enhance contrast"; alone → auto (see below)
  'قلل': const _E(_K.dec),
  'تقليل': const _E(_K.dec),
  'اخفض': const _E(_K.dec),
  'خفض': const _E(_K.dec),
  'انقص': const _E(_K.dec),
  'نقص': const _E(_K.dec),
  'خفف': const _E(_K.dec),
  'اقل': const _E(_K.dec),
  'اضعف': const _E(_K.dec),
  'less': const _E(_K.dec),
  'decreas': const _E(_K.dec),
  'reduc': const _E(_K.dec),
  'lower': const _E(_K.dec),
  'down': const _E(_K.dec, exact: true),
  'weaker': const _E(_K.dec),
  'fewer': const _E(_K.dec),

  // ---- intensity
  'قليلا': const _E(_K.slight),
  'قليل': const _E(_K.slight),
  'شوي': const _E(_K.slight),
  'بسيط': const _E(_K.slight),
  'خفيف': const _E(_K.slight),
  'طفيف': const _E(_K.slight),
  'لمسه': const _E(_K.slight),
  'slight': const _E(_K.slight),
  'bit': const _E(_K.slight, exact: true),
  'little': const _E(_K.slight),
  'touch': const _E(_K.slight),
  'tad': const _E(_K.slight, exact: true),
  'subtl': const _E(_K.slight),
  'mild': const _E(_K.slight),
  'gentl': const _E(_K.slight),
  'كثيرا': const _E(_K.strong),
  'كثير': const _E(_K.strong),
  'كتير': const _E(_K.strong),
  'جدا': const _E(_K.strong),
  'بقوه': const _E(_K.strong),
  'very': const _E(_K.strong),
  'much': const _E(_K.strong),
  'lot': const _E(_K.strong, exact: true),
  'lots': const _E(_K.strong, exact: true),
  'really': const _E(_K.strong),
  'strong': const _E(_K.strong),
  'extrem': const _E(_K.strong),
  'heavi': const _E(_K.strong),
  'super': const _E(_K.strong, exact: true),

  // ---- dialect intensity (v1.3.x pass: Gulf, Egyptian, Levantine,
  // Maghrebi). Feminine forms are caught by the Arabic prefix matcher.
  'وايد': const _E(_K.strong), // Gulf
  'حيل': const _E(_K.strong, exact: true), // Gulf
  'كلش': const _E(_K.strong, exact: true), // Gulf/Iraqi
  'اوي': const _E(_K.strong), // Egyptian
  'خالص': const _E(_K.strong), // Egyptian
  'مره': const _E(_K.strong, exact: true), // Levantine
  'بزاف': const _E(_K.strong), // Maghrebi
  'برشا': const _E(_K.strong, exact: true), // Tunisian
  'شويه': const _E(_K.slight), // Egyptian/Levantine/Maghrebi
  // ---- removal verbs
  'ازل': const _E(_K.remove),
  'ازاله': const _E(_K.remove),
  'احذف': const _E(_K.remove),
  'حذف': const _E(_K.remove),
  'شيل': const _E(_K.remove),
  'امسح': const _E(_K.remove),
  'مسح': const _E(_K.remove),
  'تخلص': const _E(_K.remove),
  'اخف': const _E(_K.remove, exact: true),
  'اخفي': const _E(_K.remove),
  'الغ': const _E(_K.remove),
  'الغاء': const _E(_K.remove),
  'بدون': const _E(_K.remove),
  'بلا': const _E(_K.remove),
  'remov': const _E(_K.remove),
  'delet': const _E(_K.remove),
  'eras': const _E(_K.remove),
  'without': const _E(_K.remove),
  'no': const _E(_K.remove, exact: true),
  'hide': const _E(_K.remove),
  'cancel': const _E(_K.remove),
  'drop': const _E(_K.remove),

  // ---- light
  'سطوع': _p(AdjustmentParam.exposure),
  'ساطع': _p(AdjustmentParam.exposure),
  'اسطع': _p(AdjustmentParam.exposure),
  'اضاءه': _p(AdjustmentParam.exposure),
  'اضاء': _p(AdjustmentParam.exposure),
  'اناره': _p(AdjustmentParam.exposure),
  'انار': _p(AdjustmentParam.exposure),
  'نور': _p(AdjustmentParam.exposure),
  'ضوء': _p(AdjustmentParam.exposure),
  'تعريض': _p(AdjustmentParam.exposure),
  'افتح': _p(AdjustmentParam.exposure),
  'فاتح': _p(AdjustmentParam.exposure),
  'مشرق': _p(AdjustmentParam.exposure),
  'اغمق': _p(AdjustmentParam.exposure, -1),
  // "brighten/whiten" steer other sliders ("brighten the shadows") and name
  // the face-aware tools when eyes/teeth are present ("بيض الاسنان").
  'اضيء': _p(AdjustmentParam.exposure),
  'اضئ': _p(AdjustmentParam.exposure),
  'اضوء': _p(AdjustmentParam.exposure),
  'اضو': _p(AdjustmentParam.exposure),
  'بيض': _p(AdjustmentParam.whites),
  'ابيض': _p(AdjustmentParam.whites),
  'brighten': _p(AdjustmentParam.exposure),
  'whiten': _p(AdjustmentParam.whites),
  'غامق': _p(AdjustmentParam.exposure, -1),
  'داكن': _p(AdjustmentParam.exposure, -1),
  'اظلم': _p(AdjustmentParam.exposure, -1),
  'مظلم': _p(AdjustmentParam.exposure, -1),
  'ظلام': _p(AdjustmentParam.exposure, -1),
  'معتم': _p(AdjustmentParam.exposure, -1),
  'عتم': _p(AdjustmentParam.exposure, -1),
  'bright': _p(AdjustmentParam.exposure),
  'exposur': _p(AdjustmentParam.exposure),
  'expos': _p(AdjustmentParam.exposure),
  'light': _p(AdjustmentParam.exposure),
  'dark': _p(AdjustmentParam.exposure, -1),
  'dim': const _E(_K.param, param: AdjustmentParam.exposure, dir: -1, exact: true),
  'dimmer': _p(AdjustmentParam.exposure, -1),
  'تباين': _p(AdjustmentParam.contrast),
  'كونتراست': _p(AdjustmentParam.contrast),
  'contrast': _p(AdjustmentParam.contrast),
  'punch': _p(AdjustmentParam.contrast),
  'flat': _p(AdjustmentParam.contrast, -1),
  'highlight': _p(AdjustmentParam.highlights),
  'هايلايت': _p(AdjustmentParam.highlights),
  'اضاءات': _p(AdjustmentParam.highlights),
  'ظل': const _E(_K.param, param: AdjustmentParam.shadows, exact: true),
  'ظلال': _p(AdjustmentParam.shadows),
  'shadow': _p(AdjustmentParam.shadows),
  'whites': _p(AdjustmentParam.whites),
  'البياض': _p(AdjustmentParam.whites),
  'blacks': _p(AdjustmentParam.blacks),
  'السواد': _p(AdjustmentParam.blacks),

  // ---- colour
  'تشبع': _p(AdjustmentParam.saturation),
  'الوان': _p(AdjustmentParam.saturation),
  'لون': _p(AdjustmentParam.saturation),
  'ملون': _p(AdjustmentParam.saturation),
  'saturat': _p(AdjustmentParam.saturation),
  'desaturat': _p(AdjustmentParam.saturation, -1),
  'colour': _p(AdjustmentParam.saturation),
  'color': _p(AdjustmentParam.saturation),
  'حيويه': _p(AdjustmentParam.vibrance),
  'حيوي': _p(AdjustmentParam.vibrance),
  'زاهي': _p(AdjustmentParam.vibrance),
  'vibran': _p(AdjustmentParam.vibrance),
  'vivid': _p(AdjustmentParam.vibrance),
  'pop': const _E(_K.param, param: AdjustmentParam.vibrance, exact: true),
  'دفء': _p(AdjustmentParam.temperature),
  'دفي': _p(AdjustmentParam.temperature),
  'دافي': _p(AdjustmentParam.temperature),
  'ادفا': _p(AdjustmentParam.temperature),
  'دفا': _p(AdjustmentParam.temperature),
  'حراره': _p(AdjustmentParam.temperature),
  'warm': _p(AdjustmentParam.temperature),
  'temperatur': _p(AdjustmentParam.temperature),
  'temp': const _E(_K.param, param: AdjustmentParam.temperature, exact: true),
  'cool': _p(AdjustmentParam.temperature, -1),
  'cold': _p(AdjustmentParam.temperature, -1),
  'chill': _p(AdjustmentParam.temperature, -1),
  'بارد': _p(AdjustmentParam.temperature, -1),
  'ابرد': _p(AdjustmentParam.temperature, -1),
  'برود': _p(AdjustmentParam.temperature, -1),
  'برد': _p(AdjustmentParam.temperature, -1),
  'tint': _p(AdjustmentParam.tint),
  'magenta': _p(AdjustmentParam.tint),
  'صبغه': _p(AdjustmentParam.tint),
  'fade': _p(AdjustmentParam.fade),
  'faded': _p(AdjustmentParam.fade),
  'matte': _p(AdjustmentParam.fade),
  'باهت': _p(AdjustmentParam.fade),
  'بهتان': _p(AdjustmentParam.fade),
  'مطفي': _p(AdjustmentParam.fade),

  // ---- detail
  'sharp': _p(AdjustmentParam.sharpen),
  'crisp': _p(AdjustmentParam.sharpen),
  'حده': _p(AdjustmentParam.sharpen),
  'حاد': _p(AdjustmentParam.sharpen),
  'شارب': _p(AdjustmentParam.sharpen),
  'clarity': _p(AdjustmentParam.clarity),
  'وضوح': _p(AdjustmentParam.clarity),
  'اوضح': _p(AdjustmentParam.clarity),
  'واضح': _p(AdjustmentParam.clarity),
  'soft': _p(AdjustmentParam.clarity, -1),
  'نعومه': _p(AdjustmentParam.clarity, -1),
  'انعم': _p(AdjustmentParam.clarity, -1),
  'ناعم': _p(AdjustmentParam.clarity, -1),
  'detail': _p(AdjustmentParam.structure),
  'structur': _p(AdjustmentParam.structure),
  'textur': _p(AdjustmentParam.structure),
  'تفاصيل': _p(AdjustmentParam.structure),
  'تفصيل': _p(AdjustmentParam.structure),
  'ملمس': _p(AdjustmentParam.structure),
  'dehaz': _p(AdjustmentParam.dehaze),
  'haze': _p(AdjustmentParam.dehaze, -1),
  'hazy': _p(AdjustmentParam.dehaze, -1),
  'fog': _p(AdjustmentParam.dehaze, -1),
  'mist': _p(AdjustmentParam.dehaze, -1),
  'ضباب': _p(AdjustmentParam.dehaze, -1),
  'غبار': _p(AdjustmentParam.dehaze, -1),
  'blur': const _E(_K.blur),
  'ضبابي': const _E(_K.blur),
  'تمويه': const _E(_K.blur),
  'موه': const _E(_K.blur),
  'طمس': const _E(_K.blur),
  'اطمس': const _E(_K.blur),
  'غبش': const _E(_K.blur),
  'vignett': _p(AdjustmentParam.vignette),
  'فينيت': _p(AdjustmentParam.vignette),
  'تظليل': _p(AdjustmentParam.vignette),
  'حواف': _p(AdjustmentParam.vignette),
  'اطراف': _p(AdjustmentParam.vignette),
  'edge': _p(AdjustmentParam.vignette),
  'corner': _p(AdjustmentParam.vignette),
  'grain': _p(AdjustmentParam.grain),
  'حبيبات': _p(AdjustmentParam.grain),
  'حبيبي': _p(AdjustmentParam.grain),
  'glitch': _p(AdjustmentParam.glitch),
  'غليتش': _p(AdjustmentParam.glitch),

  // ---- looks
  'monochrom': _look('mono'),
  'mono': _look('mono'),
  'grayscal': _look('mono'),
  'greyscal': _look('mono'),
  'gray': _look('mono'),
  'grey': _look('mono'),
  'bw': const _E(_K.look, look: 'mono', exact: true),
  'رمادي': _look('mono'),
  'احادي': _look('mono'),
  'noir': _look('noir'),
  'نوار': _look('noir'),
  'cinemat': _look('blockbuster'),
  'movie': _look('blockbuster'),
  'hollywood': _look('blockbuster'),
  'سينمائي': _look('blockbuster'),
  'سينما': _look('blockbuster'),
  'هوليود': _look('blockbuster'),
  'teal': _look('teal_orange'),
  'تركواز': _look('teal_orange'),
  'film': _look('portra'),
  'analog': _look('portra'),
  'kodak': _look('portra'),
  'portra': _look('portra'),
  'فيلم': _look('portra'),
  'انالوج': _look('portra'),
  'vintag': _look('seventies'),
  'retro': _look('seventies'),
  'nostalg': _look('faded_memory'),
  'old': const _E(_K.look, look: 'seventies', exact: true),
  'قديم': _look('seventies'),
  'ريترو': _look('seventies'),
  'كلاسيك': _look('seventies'),
  'عتيق': _look('sepia'),
  'زمان': _look('seventies'),
  'سبعينات': _look('seventies'),
  '70s': _look('seventies'),
  'seventies': _look('seventies'),
  'polaroid': _look('polaroid_fade'),
  'بولارويد': _look('polaroid_fade'),
  'sepia': _look('sepia'),
  'سيبيا': _look('sepia'),
  'sunset': _look('golden_hour'),
  'غروب': _look('golden_hour'),
  'ذهبي': _look('golden_hour'),
  'moody': _look('moody'),
  'dramat': _look('moody'),
  'درامي': _look('moody'),
  'دراما': _look('moody'),
  'كئيب': _look('moody'),
  'dreamy': _look('dreamy'),
  'حالم': _look('dreamy'),
  'airy': _look('airy'),
  'هوائي': _look('airy'),
  'hdr': _look('hdr_natural'),
  'cyberpunk': _look('cyberpunk'),
  'neon': _look('cyberpunk'),
  'نيون': _look('cyberpunk'),
  'سايبر': _look('cyberpunk'),
  'vhs': _look('vhs'),
  'food': _look('food_fresh'),
  'طعام': _look('food_fresh'),
  'اكل': _look('food_fresh'),
  'landscap': _look('vivid_landscape'),
  'nature': _look('vivid_landscape'),
  'طبيعه': _look('vivid_landscape'),
  'منظر': _look('vivid_landscape'),
  'night': _look('night_city'),
  'ليل': _look('night_city'),
  'desert': _look('desert_gold'),
  'صحراء': _look('desert_gold'),
  'صحراوي': _look('desert_gold'),
  'document': _look('clean_paper'),
  'مستند': _look('clean_paper'),
  'وثيقه': _look('clean_paper'),
  'studio': _look('studio'),
  'استوديو': _look('studio'),

  // ---- nouns for actions
  'خلفيه': const _E(_K.background),
  'background': const _E(_K.background),
  'backdrop': const _E(_K.background),
  'bg': const _E(_K.background, exact: true),
  'شخص': const _E(_K.person),
  'اشخاص': const _E(_K.person),
  'ناس': const _E(_K.person),
  'رجل': const _E(_K.person),
  'امراه': const _E(_K.person),
  'سائح': const _E(_K.person),
  'سياح': const _E(_K.person),
  'perso': const _E(_K.person),
  'people': const _E(_K.person),
  'man': const _E(_K.person, exact: true),
  'woman': const _E(_K.person),
  'guy': const _E(_K.person, exact: true),
  'girl': const _E(_K.person),
  'boy': const _E(_K.person, exact: true),
  'someone': const _E(_K.person),
  'tourist': const _E(_K.person),
  'photobomb': const _E(_K.person),
  'object': const _E(_K.object),
  'thing': const _E(_K.object),
  'this': const _E(_K.object, exact: true),
  'item': const _E(_K.object),
  'عنصر': const _E(_K.object),
  'جسم': const _E(_K.object),
  'شي': const _E(_K.object, exact: true),
  'شيء': const _E(_K.object),
  'هذا': const _E(_K.object),
  'هذه': const _E(_K.object),
  'blemish': const _E(_K.blemish),
  'spot': const _E(_K.blemish),
  'pimpl': const _E(_K.blemish),
  'acne': const _E(_K.blemish),
  'dust': const _E(_K.blemish),
  'scratch': const _E(_K.blemish),
  'حبوب': const _E(_K.blemish),
  'حبه': const _E(_K.blemish),
  'بقع': const _E(_K.blemish),
  'شوائب': const _E(_K.blemish),
  'عيوب': const _E(_K.blemish),
  'خدوش': const _E(_K.blemish),
  'depth': const _E(_K.depth),
  'bokeh': const _E(_K.depth),
  'عمق': const _E(_K.depth),
  'بوكيه': const _E(_K.depth),
  'cutout': const _E(_K.cut),
  'cut': const _E(_K.cut, exact: true),
  'isolat': const _E(_K.cut),
  'sticker': const _E(_K.cut),
  'قص': const _E(_K.cut, exact: true),
  'اقتطع': const _E(_K.cut),
  'اعزل': const _E(_K.cut),
  'عزل': const _E(_K.cut),
  'ملصق': const _E(_K.cut),
  'ستيكر': const _E(_K.cut),
  'subject': const _E(_K.subject),
  'موضوع': const _E(_K.subject),
  'skin': const _E(_K.skin),
  'face': const _E(_K.skin),
  'retouch': const _E(_K.skin),
  'smooth': const _E(_K.skin),
  'beaut': const _E(_K.skin),
  'بشره': const _E(_K.skin),
  'وجه': const _E(_K.skin),
  'رتوش': const _E(_K.skin),
  'تنعيم': const _E(_K.skin),
  'جمل': const _E(_K.skin, exact: true),
  'تجميل': const _E(_K.skin),
  // face-aware retouch (v1.4 "Faces")
  'eyes': const _E(_K.eyes),
  'eye': const _E(_K.eyes),
  'teeth': const _E(_K.teeth),
  'tooth': const _E(_K.teeth),
  'عيون': const _E(_K.eyes),
  'عينين': const _E(_K.eyes),
  'عين': const _E(_K.eyes),
  'اعين': const _E(_K.eyes),
  'اسنان': const _E(_K.teeth),
  'سنانه': const _E(_K.teeth),
  'ضروس': const _E(_K.teeth),
  // sky & scene (v1.4 "Sky & scene")
  'sky': const _E(_K.sky),
  'سماء': const _E(_K.sky),
  'سما': const _E(_K.sky),
  'replace': const _E(_K.replace),
  'swap': const _E(_K.replace),
  'استبدل': const _E(_K.replace),
  'بدل': const _E(_K.replace),
  'orange': const _E(_K.sunsetSky),
  'برتقالي': const _E(_K.sunsetSky),
  'برتقاليه': const _E(_K.sunsetSky),
  'صافيه': const _E(_K.clearSky),
  'صافي': const _E(_K.clearSky),
  'clear': const _E(_K.clearSky),
  'cloud': const _E(_K.stormSky),
  'stormy': const _E(_K.stormSky),
  'overcast': const _E(_K.stormSky),
  'غيوم': const _E(_K.stormSky),
  'عاصفه': const _E(_K.stormSky),
  'عاصف': const _E(_K.stormSky),
  'filter': const _E(_K.filter),
  'preset': const _E(_K.filter),
  'look': const _E(_K.filter, exact: true),
  'فلتر': const _E(_K.filter),
  'تاثير': const _E(_K.filter),
  'نمط': const _E(_K.filter),
  'relight': const _E(_K.relight),
  'spotlight': const _E(_K.relight),
  'سبوت': const _E(_K.relight),

  // ---- standalone actions
  'upscal': _act(SmartAction.upscale),
  'enlarg': _act(SmartAction.upscale),
  'resolution': _act(SmartAction.upscale),
  'hd': const _E(_K.action, action: SmartAction.upscale, exact: true),
  '4k': const _E(_K.action, action: SmartAction.upscale, exact: true),
  'تكبير': _act(SmartAction.upscale),
  'كبر': _act(SmartAction.upscale),
  'دقه': _act(SmartAction.upscale),
  'جوده': _act(SmartAction.upscale),
  'quality': _act(SmartAction.upscale),
  'auto': _act(SmartAction.autoEnhance),
  'improv': _act(SmartAction.autoEnhance),
  'fix': const _E(_K.action, action: SmartAction.autoEnhance, exact: true),
  'better': _act(SmartAction.autoEnhance),
  'straighten': _act(SmartAction.autoStraighten),
  'level': _act(SmartAction.autoStraighten),
  'align': _act(SmartAction.autoStraighten),
  'horizon': _act(SmartAction.autoStraighten),
  'tilt': _act(SmartAction.autoStraighten),
  'تسويه': _act(SmartAction.autoStraighten),
  'سوي': _act(SmartAction.autoStraighten),
  'افق': _act(SmartAction.autoStraighten),
  'ميل': _act(SmartAction.autoStraighten),
  'مستقيم': _act(SmartAction.autoStraighten),
  'معايره': _act(SmartAction.autoStraighten),
  'تحسين': _act(SmartAction.autoEnhance),
  'حسن': _act(SmartAction.autoEnhance),
  'تلقائي': _act(SmartAction.autoEnhance),
  'اصلح': _act(SmartAction.autoEnhance),
  'افضل': _act(SmartAction.autoEnhance),
  'احلي': _act(SmartAction.autoEnhance),
  'احسن': _act(SmartAction.autoEnhance),
  'magic': _act(SmartAction.autoEnhance),
  'reset': _act(SmartAction.reset),
  'revert': _act(SmartAction.reset),
  'original': _act(SmartAction.reset),
  'الاصل': _act(SmartAction.reset),
  'undo': _act(SmartAction.undo),
  'تراجع': _act(SmartAction.undo),
  'select': _act(SmartAction.selectObject),
  'حدد': _act(SmartAction.selectObject),
  'تحديد': _act(SmartAction.selectObject),
  'اختر': _act(SmartAction.selectObject),
  'heal': _act(SmartAction.heal),
  'عالج': _act(SmartAction.heal),
  // dialect "make it nice" → auto enhance
  'زين': _act(SmartAction.autoEnhance), // Gulf
  'حلو': _act(SmartAction.autoEnhance), // Egyptian
  'منيح': _act(SmartAction.autoEnhance), // Levantine
  'مليح': _act(SmartAction.autoEnhance), // Moroccan
  'باهي': _act(SmartAction.autoEnhance), // Tunisian
  'دير': _act(SmartAction.autoEnhance), // Maghrebi ("ديرها زوينة")
  'rotat': const _E(_K.rotate),
  'دور': const _E(_K.rotate),
  'تدوير': const _E(_K.rotate),
  'لف': const _E(_K.rotate),
  'turn': const _E(_K.rotateWeak),
  'left': const _E(_K.left),
  'يسار': const _E(_K.left),
  'counterclockwis': const _E(_K.left),
  'anticlockwis': const _E(_K.left),
  'right': const _E(_K.right),
  'يمين': const _E(_K.right),
  'clockwis': const _E(_K.right),
  'flip': _act(SmartAction.flipHorizontal),
  'mirror': _act(SmartAction.flipHorizontal),
  'اعكس': _act(SmartAction.flipHorizontal),
  'عكس': _act(SmartAction.flipHorizontal),
  'اقلب': _act(SmartAction.flipHorizontal),
  'مرايه': _act(SmartAction.flipHorizontal),
  'vertical': const _E(_K.vertical),
  'upside': const _E(_K.vertical),
  'عمودي': const _E(_K.vertical),
  'راسي': const _E(_K.vertical),

  // ---- fillers (understood, carry no meaning)
  'make': const _E(_K.filler),
  'it': const _E(_K.filler, exact: true),
  'the': const _E(_K.filler, exact: true),
  'a': const _E(_K.filler, exact: true),
  'an': const _E(_K.filler, exact: true),
  'to': const _E(_K.filler, exact: true),
  'of': const _E(_K.filler, exact: true),
  'by': const _E(_K.filler, exact: true),
  'set': const _E(_K.filler, exact: true),
  'please': const _E(_K.filler),
  'photo': const _E(_K.filler),
  'image': const _E(_K.filler),
  'picture': const _E(_K.filler),
  'pic': const _E(_K.filler, exact: true),
  'apply': const _E(_K.filler),
  'give': const _E(_K.filler),
  'style': const _E(_K.filter),
  'اجعل': const _E(_K.filler),
  'خلي': const _E(_K.filler),
  'خل': const _E(_K.filler, exact: true),
  'صوره': const _E(_K.filler),
  'طبق': const _E(_K.filler),
  'اعط': const _E(_K.filler),
  'من': const _E(_K.filler, exact: true),
  'في': const _E(_K.filler, exact: true),
  'علي': const _E(_K.filler, exact: true),
  'الي': const _E(_K.filler, exact: true),
  'لو': const _E(_K.filler, exact: true),
  'فضلك': const _E(_K.filler),
  'سمحت': const _E(_K.filler),
  'درجه': const _E(_K.filler),
  'بنسبه': const _E(_K.filler),
  'نسبه': const _E(_K.filler),
  'شكل': const _E(_K.filler),
  'ستايل': const _E(_K.filler),
  'مظهر': const _E(_K.filler),
  'طابع': const _E(_K.filler),
  'زينه': const _E(_K.filler),
  'زوينه': const _E(_K.filler), // Maghrebi ("ديرها زوينه")
  'percent': const _E(_K.filler),
  'degrees': const _E(_K.filler),
  'درجات': const _E(_K.filler),
};

/// Lexicon and phrases with keys normalised exactly like the input text.
final Map<String, _E> _lexicon = {for (final e in _lexiconRaw.entries) normalizeCommandText(e.key): e.value};
final Map<String, String> _phrases = {for (final e in _phrasesRaw.entries) normalizeCommandText(e.key): e.value};
final List<String> _phrasesByLength = _phrases.keys.toList()..sort((a, b) => b.length.compareTo(a.length));

/// Matches [token] against the lexicon without stripping Arabic prefixes.
_E? _directMatch(String token) {
  final exact = _lexicon[token];
  if (exact != null) return exact;
  _E? best;
  var bestLen = 0;
  for (final e in _lexicon.entries) {
    if (e.value.exact || e.key.length <= 2 || e.key.length <= bestLen) continue;
    if (token.startsWith(e.key)) {
      best = e.value;
      bestLen = e.key.length;
    }
  }
  return best;
}

/// Light adjectives/verbs (not the nouns "brightness"/"السطوع") that can
/// steer another slider: "brighten the shadows", "اغمق السماء".
bool _isLightVerb(String token) {
  final t = token.startsWith('ال') ? token.substring(2) : token;
  const nouns = ['brightness', 'exposure', 'light', 'lighting', 'سطوع', 'اضاءه', 'اناره', 'ضوء', 'تعريض', 'نور'];
  return !nouns.contains(t);
}

/// Verbs that open an instruction even though they carry no edit meaning.
const List<String> _starterVerbs = ['اجعل', 'خلي', 'طبق', 'اعط', 'حول'];

/// Words that start a new instruction when glued to a leading "و"/"ف"
/// ("زد السطوع وقلل التشبع", "نعم البشره واضي العيون"). Slider names count
/// too: "والتشبع" opens its own clause and inherits the previous direction.
const Set<_K> _clauseStarters = {
  _K.inc,
  _K.dec,
  _K.remove,
  _K.action,
  _K.rotate,
  _K.cut,
  _K.blur,
  _K.param,
  _K.replace,
};

/// Default step of one "more"/"less" for each slider (slider units).
const Map<AdjustmentParam, double> _step = {
  AdjustmentParam.exposure: 0.35,
  AdjustmentParam.contrast: 0.2,
  AdjustmentParam.highlights: 0.25,
  AdjustmentParam.shadows: 0.25,
  AdjustmentParam.whites: 0.2,
  AdjustmentParam.blacks: 0.2,
  AdjustmentParam.temperature: 0.2,
  AdjustmentParam.tint: 0.15,
  AdjustmentParam.vibrance: 0.25,
  AdjustmentParam.saturation: 0.2,
  AdjustmentParam.fade: 0.2,
  AdjustmentParam.sharpen: 0.3,
  AdjustmentParam.clarity: 0.25,
  AdjustmentParam.structure: 0.25,
  AdjustmentParam.dehaze: 0.25,
  AdjustmentParam.blur: 0.3,
  AdjustmentParam.vignette: 0.3,
  AdjustmentParam.grain: 0.25,
  AdjustmentParam.glitch: 0.3,
};

/// Sliders where "more" means a *negative* value (a stronger dark vignette).
const Map<AdjustmentParam, int> _polarity = {AdjustmentParam.vignette: -1};

class _Match {
  const _Match(this.entry, this.token);
  final _E entry;
  final String token;
}

_E? _lookup(String token) {
  _E? best;
  var bestLen = 0;
  for (final stem in tokenStems(token)) {
    final exact = _lexicon[stem];
    if (exact != null && stem.length > bestLen) {
      best = exact;
      bestLen = stem.length;
    }
    for (final e in _lexicon.entries) {
      final kw = e.key;
      if (kw.length <= bestLen || e.value.exact || kw.length <= 2) continue;
      if (stem.startsWith(kw)) {
        best = e.value;
        bestLen = kw.length;
      }
    }
  }
  return best;
}

final RegExp _number = RegExp(r'^([+-]?)(\d+(?:\.\d+)?)(%?)$');

// ---------------------------------------------------------------------------
// Engine

/// Deterministic Arabic/English intent engine.
class RuleIntentEngine implements EditIntentEngine {
  const RuleIntentEngine();

  @override
  SmartEditPlan parse(String text) {
    var s = ' ${normalizeCommandText(text)} ';
    // Longest phrases first.
    for (final ph in _phrasesByLength) {
      s = s.replaceAll(' $ph ', ' ${_phrases[ph]} ');
      // Arabic phrases may carry a leading conjunction ("وابيض واسود").
      s = s.replaceAll(' و$ph ', ' ${_phrases[ph]} ');
    }
    final clauses = _splitClauses(s.trim().split(' ').where((t) => t.isNotEmpty).toList());

    final ops = <EditOp>[];
    final unknown = <String>[];
    _ClauseResult? previous;
    for (final c in clauses) {
      final r = _parseClause(c, previous);
      if (r.ops.isEmpty) {
        if (r.unknownTokens.isNotEmpty) unknown.add(c.join(' '));
      } else {
        ops.addAll(r.ops);
      }
      previous = r;
    }
    return SmartEditPlan(ops: _merge(ops), unrecognized: unknown);
  }

  List<List<String>> _splitClauses(List<String> tokens) {
    final out = <List<String>>[];
    var cur = <String>[];
    void flush() {
      if (cur.isNotEmpty) out.add(cur);
      cur = <String>[];
    }

    for (final t in tokens) {
      if (const {
        ',',
        ';',
        '.',
        '!',
        '?',
        'and',
        'then',
        'also',
        'plus',
        'ثم',
        'بعدين',
        'وبعدين',
        'ايضا',
        'كمان',
        'و',
      }.contains(t)) {
        flush();
        continue;
      }
      if ((t.startsWith('و') || t.startsWith('ف')) && t.length > 2) {
        final rest = t.substring(1);
        final e = _lookup(rest);
        final whole = _directMatch(t);
        final starter = (e != null && _clauseStarters.contains(e.kind)) || _starterVerbs.any(rest.startsWith);
        if (whole == null && starter && cur.isNotEmpty) {
          flush();
          cur.add(rest);
          continue;
        }
      }
      cur.add(t);
    }
    flush();
    return out;
  }

  _ClauseResult _parseClause(List<String> tokens, _ClauseResult? previous) {
    final matches = <_Match>[];
    final unknown = <String>[];
    final numbers = <(double, bool, bool)>[]; // value, signed, percent
    for (final t in tokens) {
      final n = _number.firstMatch(t);
      if (n != null) {
        final v = double.parse(n[2]!) * (n[1] == '-' ? -1 : 1);
        numbers.add((v, n[1]!.isNotEmpty, n[3]!.isNotEmpty));
        continue;
      }
      final e = _lookup(t);
      if (e == null) {
        unknown.add(t);
      } else {
        matches.add(_Match(e, t));
      }
    }
    bool has(_K k) => matches.any((m) => m.entry.kind == k);
    final incs = matches.where((m) => m.entry.kind == _K.inc).length;
    final decs = matches.where((m) => m.entry.kind == _K.dec).length;
    var explicit = incs > decs ? 1 : (decs > incs ? -1 : null);
    var factor = has(_K.slight) ? 0.5 : (has(_K.strong) ? 1.8 : 1.0);
    // One entry per slider ("تظليل الحواف" names the vignette twice).
    final params = <_E>[];
    for (final m in matches) {
      if (m.entry.kind == _K.param && !params.any((p) => p.param == m.entry.param)) params.add(m.entry);
    }
    final looks = [
      for (final m in matches)
        if (m.entry.kind == _K.look) m.entry.look!,
    ];
    final actions = [
      for (final m in matches)
        if (m.entry.kind == _K.action) m.entry.action!,
    ];
    // "brighten the shadows" / "افتح الظلال": a light adjective next to
    // another slider is the direction for that slider, not an exposure
    // change of its own.
    var lightSteer = false;
    if (explicit == null && params.length >= 2) {
      final light = matches
          .where((m) => m.entry.param == AdjustmentParam.exposure && _isLightVerb(m.token))
          .map((m) => m.entry)
          .firstOrNull;
      if (light != null && params.any((p) => p.param != AdjustmentParam.exposure)) {
        explicit = light.dir;
        lightSteer = true;
        params.removeWhere((p) => p.param == AdjustmentParam.exposure);
      }
    }
    // "and saturation" after "increase contrast": inherit the direction.
    if (explicit == null && previous != null && params.isNotEmpty && looks.isEmpty && actions.isEmpty) {
      explicit = previous.direction;
      if (!has(_K.slight) && !has(_K.strong)) factor = previous.factor;
    }

    final ops = <EditOp>[];
    final remove = has(_K.remove);
    final background = has(_K.background);
    final person = has(_K.person);
    final blur = has(_K.blur);
    final depth = has(_K.depth);
    final skin = has(_K.skin);
    var consumedParams = false;

    // --- compound intents (noun + verb)
    if (background) {
      if (depth) {
        ops.add(const ActionOp(SmartAction.depthBlur));
      } else if (blur) {
        ops.add(const ActionOp(SmartAction.blurBackground));
      } else if (params.any((p) => p.param == AdjustmentParam.exposure) &&
          _dir(params.firstWhere((p) => p.param == AdjustmentParam.exposure), explicit) < 0) {
        ops.add(const ActionOp(SmartAction.relight));
        consumedParams = true;
      } else {
        ops.add(const ActionOp(SmartAction.removeBackground));
      }
    } else if (person && remove) {
      ops.add(const ActionOp(SmartAction.erasePerson));
    } else if ((person || has(_K.subject)) && has(_K.cut)) {
      ops.add(ActionOp(person ? SmartAction.cutOutPerson : SmartAction.removeBackground));
    } else if (has(_K.cut)) {
      ops.add(const ActionOp(SmartAction.removeBackground));
    } else if (skin) {
      ops.add(const ActionOp(SmartAction.faceRetouch));
      consumedParams = true;
    } else if (has(_K.eyes)) {
      ops.add(const ActionOp(SmartAction.eyeBrighten));
      consumedParams = true;
    } else if (has(_K.teeth)) {
      ops.add(const ActionOp(SmartAction.teethWhiten));
      consumedParams = true;
    } else if (has(_K.sky)) {
      // Sky-style words choose the replacement gradient: "replace the sky
      // with a sunset" / "سماء غروب" / "clear sky" / "sunset sky".
      final goldenLook = looks.contains('golden_hour');
      final replace = has(_K.replace) || has(_K.sunsetSky) || has(_K.clearSky) || has(_K.stormSky) || goldenLook;
      if (replace) {
        final action = has(_K.stormSky)
            ? SmartAction.skyReplaceStorm
            : has(_K.clearSky)
            ? SmartAction.skyReplaceClear
            : has(_K.sunsetSky)
            ? SmartAction.skyReplaceSunset
            : goldenLook
            ? SmartAction.skyReplaceGolden
            : SmartAction.skyReplaceSunset;
        ops.add(ActionOp(action));
        looks.clear();
      } else {
        // "deepen the sky" / "اغمق السماء" — masked, editable local edit.
        ops.add(const ActionOp(SmartAction.skyDeepen));
        looks.clear();
      }
      consumedParams = true;
    } else if (has(_K.blemish)) {
      ops.add(const ActionOp(SmartAction.heal));
    } else if (has(_K.relight) ||
        ((person || has(_K.subject)) && params.any((p) => p.param == AdjustmentParam.exposure))) {
      ops.add(const ActionOp(SmartAction.relight));
      consumedParams = true;
    } else if (depth) {
      ops.add(const ActionOp(SmartAction.depthBlur));
    } else if (remove && (has(_K.filter) || looks.isNotEmpty)) {
      ops.add(const ActionOp(SmartAction.clearLook));
      looks.clear();
    } else if (remove && params.isNotEmpty) {
      for (final p in params) {
        final param = p.param!;
        ops.add(switch (param) {
          AdjustmentParam.dehaze => AdjustOp(param, 0.4 * factor),
          AdjustmentParam.saturation => AdjustOp(param, -1, absolute: true),
          _ => AdjustOp(param, param.neutral, absolute: true),
        });
      }
      consumedParams = true;
    } else if (remove && has(_K.object)) {
      ops.add(const ActionOp(SmartAction.eraseObject));
    } else if (remove && looks.isEmpty && actions.isEmpty && params.isEmpty && !blur) {
      ops.add(const ActionOp(SmartAction.eraseObject));
    } else if (blur && params.isEmpty) {
      ops.add(AdjustOp(AdjustmentParam.blur, _step[AdjustmentParam.blur]! * factor * (explicit ?? 1)));
    }

    // --- rotation
    if (has(_K.rotate) || (has(_K.rotateWeak) && (has(_K.left) || has(_K.right) || numbers.isNotEmpty))) {
      final left = has(_K.left);
      final half = numbers.any((n) => n.$1.abs() == 180);
      final a = left ? SmartAction.rotateLeft : SmartAction.rotateRight;
      ops.add(ActionOp(a));
      if (half) ops.add(ActionOp(a));
      numbers.clear();
    }

    // --- standalone actions
    final compound = ops.isNotEmpty;
    for (final a in actions) {
      var action = a;
      // "improve the contrast" is about contrast; "improve the skin" was
      // handled above.
      if (a == SmartAction.autoEnhance && (compound || params.isNotEmpty)) continue;
      if (a == SmartAction.flipHorizontal && has(_K.vertical)) action = SmartAction.flipVertical;
      // "enhance resolution" / "improve quality" → upscale wins over auto.
      if (a == SmartAction.autoEnhance && actions.contains(SmartAction.upscale)) continue;
      if (a == SmartAction.upscale && remove) continue;
      if (!ops.any((o) => o is ActionOp && o.action == action)) ops.add(ActionOp(action));
    }
    // "enhance" alone → auto-enhance.
    if (ops.isEmpty && params.isEmpty && looks.isEmpty && matches.any((m) => m.token.startsWith('enhanc'))) {
      ops.add(const ActionOp(SmartAction.autoEnhance));
    }

    // --- looks ("film grain" is grain, not a film look)
    if (params.any((p) => p.param == AdjustmentParam.grain)) looks.remove('portra');
    for (final id in looks.toSet()) {
      ops.add(LookOp(id, intensity: (has(_K.slight) ? 0.5 : 1.0) * (explicit == -1 ? 0.5 : 1)));
    }

    // --- sliders
    if (!consumedParams) {
      for (final p in params) {
        final param = p.param!;
        // "darken the edges": the adjective already says which way the
        // slider moves, so the vignette's inverted polarity does not apply.
        final dir = lightSteer && param == AdjustmentParam.vignette ? explicit! : _dir(p, explicit);
        final number = numbers.isEmpty ? null : numbers.first;
        if (number != null) {
          final (v, signed, percent) = number;
          final scaled = param == AdjustmentParam.exposure
              ? (percent || v.abs() > 5 ? v / 100 * 2 : v)
              : v / 100 * (param.max - param.min) / (param.min < 0 ? 2 : 1);
          if (signed || explicit != null) {
            ops.add(AdjustOp(param, scaled.abs() * dir * (signed && explicit == null ? scaled.sign : 1)));
          } else {
            final polarity = _polarity[param] ?? 1;
            ops.add(AdjustOp(param, (scaled * polarity).clamp(param.min, param.max), absolute: true));
          }
        } else {
          ops.add(AdjustOp(param, (_step[param] ?? 0.2) * factor * dir));
        }
      }
    }

    return _ClauseResult(ops: ops, direction: explicit, factor: factor, unknownTokens: unknown);
  }

  /// Final direction of a parameter word: implicit direction × explicit
  /// verb × slider polarity.
  static int _dir(_E p, int? explicit) => p.dir * (explicit ?? 1) * (_polarity[p.param] ?? 1);

  /// Sums relative changes to the same slider; keeps order of first use.
  static List<EditOp> _merge(List<EditOp> ops) {
    final out = <EditOp>[];
    for (final op in ops) {
      if (op is AdjustOp && !op.absolute) {
        final i = out.indexWhere((o) => o is AdjustOp && o.param == op.param && !o.absolute);
        if (i >= 0) {
          final prev = out[i] as AdjustOp;
          out[i] = AdjustOp(op.param, prev.amount + op.amount);
          continue;
        }
      }
      if (op is LookOp) out.removeWhere((o) => o is LookOp); // last look wins
      final repeatable =
          op is ActionOp && (op.action == SmartAction.rotateLeft || op.action == SmartAction.rotateRight);
      if (repeatable || !out.contains(op)) out.add(op);
    }
    return out;
  }
}

class _ClauseResult {
  const _ClauseResult({required this.ops, required this.direction, required this.factor, required this.unknownTokens});

  final List<EditOp> ops;
  final int? direction;
  final double factor;
  final List<String> unknownTokens;
}
