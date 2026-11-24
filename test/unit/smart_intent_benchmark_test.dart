import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/smart_edit/domain/edit_ops.dart';
import 'package:lumora/features/smart_edit/domain/intent_engine.dart';

/// The v1.3.x intent benchmark (ROADMAP.md): 1,000+ Arabic and English
/// commands — MSA, the four dialect groups (Gulf, Egyptian, Levantine,
/// Maghrebi), numbers, code-switching — each with its exact expected plan.
///
/// Acceptance (v1.3.x): exact-plan accuracy ≥ 95 % for Arabic and English
/// separately. The rule engine is deterministic, so any failure here is a
/// lexicon gap: fix the lexicon, never the expectation.
void main() {
  const e = RuleIntentEngine();

  // Default slider steps (must mirror _step in intent_engine.dart).
  const step = {
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
    AdjustmentParam.blur: 0.3,
    AdjustmentParam.vignette: 0.3,
    AdjustmentParam.grain: 0.25,
  };
  final cases = <(String, List<EditOp>)>[];

  AdjustOp up(AdjustmentParam p, double v) => AdjustOp(p, v);
  AdjustOp setTo(AdjustmentParam p, double v) => AdjustOp(p, v, absolute: true);
  ActionOp act(SmartAction a) => ActionOp(a);
  LookOp look(String id, [double k = 1]) => LookOp(id, intensity: k);

  // ------------------------------------------------------------------
  // Family 1 — Arabic dialects: direction × parameter × intensity
  // (Gulf "مره/شوي", Egyptian "اوي/خالص", Levantine "كتير/شوي",
  //  Maghrebi "بزاف", plus MSA forms).
  const arDirections = {
    'زد': 1,
    'زيد': 1,
    'زود': 1, // Gulf/Egyptian
    'ارفع': 1,
    'قلل': -1,
    'اخفض': -1,
    'خفف': -1,
    'انقص': -1,
  };
  const arParams = {
    'التباين': AdjustmentParam.contrast,
    'التشبع': AdjustmentParam.saturation,
    'الاضاءات': AdjustmentParam.highlights,
    'الظلال': AdjustmentParam.shadows,
    'الحراره': AdjustmentParam.temperature,
    'الحيويه': AdjustmentParam.vibrance,
    'الحده': AdjustmentParam.sharpen,
    'الوضوح': AdjustmentParam.clarity,
    'التفاصيل': AdjustmentParam.structure,
    'الحبيبات': AdjustmentParam.grain,
    'التمويه': AdjustmentParam.blur,
    'الصبغه': AdjustmentParam.tint,
    'البياض': AdjustmentParam.whites,
    'السواد': AdjustmentParam.blacks,
    'البهتان': AdjustmentParam.fade,
  };
  const arIntensifiers = {
    '': 1.0,
    'شوي': 0.5, // Gulf/Levantine
    'شويه': 0.5, // Egyptian/Maghrebi spelling
    'كتير': 1.8, // Levantine
    'مره': 1.8, // Gulf
    'اوي': 1.8, // Egyptian
    'خالص': 1.8, // Egyptian
    'بزاف': 1.8, // Maghrebi
  };
  for (final MapEntry(key: dir, value: sign) in arDirections.entries) {
    for (final MapEntry(key: paramWord, value: param) in arParams.entries) {
      for (final MapEntry(key: intensifier, value: factor) in arIntensifiers.entries) {
        final phrase = [dir, paramWord, if (intensifier.isNotEmpty) intensifier].join(' ');
        cases.add((phrase, [up(param, step[param]! * factor * sign)]));
      }
    }
  }

  // ------------------------------------------------------------------
  // Family 2 — English: direction × parameter × intensity.
  const enDirections = {'increase': 1, 'reduce': -1, 'boost': 1, 'lower': -1};
  const enParams = {
    'contrast': AdjustmentParam.contrast,
    'saturation': AdjustmentParam.saturation,
    'highlights': AdjustmentParam.highlights,
    'shadows': AdjustmentParam.shadows,
    'temperature': AdjustmentParam.temperature,
    'vibrance': AdjustmentParam.vibrance,
    'sharpness': AdjustmentParam.sharpen,
    'clarity': AdjustmentParam.clarity,
    'details': AdjustmentParam.structure,
    'texture': AdjustmentParam.structure,
    'grain': AdjustmentParam.grain,
    'blur': AdjustmentParam.blur,
    'tint': AdjustmentParam.tint,
    'whites': AdjustmentParam.whites,
    'blacks': AdjustmentParam.blacks,
    'faded': AdjustmentParam.fade,
  };
  const enIntensifiers = {'': 1.0, 'a bit': 0.5, 'slightly': 0.5, 'a lot': 1.8, 'very much': 1.8};
  for (final MapEntry(key: dir, value: sign) in enDirections.entries) {
    for (final MapEntry(key: paramWord, value: param) in enParams.entries) {
      for (final MapEntry(key: intensifier, value: factor) in enIntensifiers.entries) {
        final phrase = [dir, paramWord, if (intensifier.isNotEmpty) intensifier].join(' ');
        cases.add((phrase, [up(param, step[param]! * factor * sign)]));
      }
    }
  }

  // ------------------------------------------------------------------
  // Family 3 — numbers (signed, bare and Arabic-Indic digits).
  for (final MapEntry(key: paramWord, value: param) in arParams.entries) {
    if (param == AdjustmentParam.blur) continue; // numbers are not applied to the blur kind
    cases.add((paramWord, [up(param, step[param]!)])); // bare word defaults to +
    cases.add(('زد $paramWord 20', [up(param, 0.2)]));
    cases.add(('قلل $paramWord 40', [up(param, -0.4)]));
    cases.add(('$paramWord 20', [setTo(param, 0.2)]));
  }
  cases
    ..add(('التباين ٢٠', [setTo(AdjustmentParam.contrast, 0.2)]))
    ..add(('التباين ٢٠٪', [setTo(AdjustmentParam.contrast, 0.2)]))
    ..add(('زد التباين ٢٠٪', [up(AdjustmentParam.contrast, 0.2)]))
    ..add(('التظليل 20', [setTo(AdjustmentParam.vignette, -0.2)]))
    ..add(('exposure +1', [up(AdjustmentParam.exposure, 1)]))
    ..add(('exposure -0.5', [up(AdjustmentParam.exposure, -0.5)]))
    ..add(('exposure 50', [setTo(AdjustmentParam.exposure, 1)]))
    ..add(('contrast 20%', [setTo(AdjustmentParam.contrast, 0.2)]))
    ..add(('contrast +20%', [up(AdjustmentParam.contrast, 0.2)]));
  for (final MapEntry(key: paramWord, value: param) in enParams.entries) {
    if (param == AdjustmentParam.blur) continue;
    cases.add(('$paramWord 20', [setTo(param, 0.2)]));
    cases.add(('increase $paramWord 20', [up(param, 0.2)]));
    cases.add(('reduce $paramWord 40', [up(param, -0.4)]));
  }
  cases.add(('vignette 30', [setTo(AdjustmentParam.vignette, -0.3)]));

  // ------------------------------------------------------------------
  // Family 4 — looks with intensity modifiers.
  const arLooks = {
    'ابيض واسود': 'mono',
    'سينمائي': 'blockbuster',
    'فيلم': 'portra',
    'نيون': 'cyberpunk',
    'قديم': 'seventies',
    'سيبيا': 'sepia',
    'غروب': 'golden_hour',
    'صحراوي': 'desert_gold',
    'درامي': 'moody',
    'حالم': 'dreamy',
    'مستند': 'clean_paper',
    'استوديو': 'studio',
    'ليل': 'night_city',
    'طبيعه': 'vivid_landscape',
  };
  for (final MapEntry(key: word, value: id) in arLooks.entries) {
    cases.add((word, [look(id)]));
    cases.add(('$word خفيف', [look(id, 0.5)]));
  }
  const enLooks = {
    'black and white': 'mono',
    'cinematic': 'blockbuster',
    'film': 'portra',
    'neon': 'cyberpunk',
    'vintage': 'seventies',
    'sepia': 'sepia',
    'golden hour': 'golden_hour',
    'desert': 'desert_gold',
    'moody': 'moody',
    'dreamy': 'dreamy',
    'document': 'clean_paper',
    'studio': 'studio',
    'night': 'night_city',
    'landscape': 'vivid_landscape',
    'hdr': 'hdr_natural',
    'vhs': 'vhs',
    'polaroid': 'polaroid_fade',
    'noir': 'noir',
    'teal and orange': 'teal_orange',
  };
  for (final MapEntry(key: word, value: id) in enLooks.entries) {
    cases.add((word, [look(id)]));
    cases.add(('slightly $word', [look(id, 0.5)]));
  }

  // ------------------------------------------------------------------
  // Family 5 — actions across dialects.
  cases.addAll(<(String, List<EditOp>)>[
    ('دور الصورة لليمين', [act(SmartAction.rotateRight)]),
    ('دور الصورة لليسار', [act(SmartAction.rotateLeft)]),
    ('اعكس الصورة', [act(SmartAction.flipHorizontal)]),
    ('اقلب الصورة عموديا', [act(SmartAction.flipVertical)]),
    ('تراجع', [act(SmartAction.undo)]),
    ('اعاده ضبط', [act(SmartAction.reset)]),
    ('أزل الخلفية', [act(SmartAction.removeBackground)]),
    ('شيل الخلفية', [act(SmartAction.removeBackground)]),
    ('اشيل الخلفيه', [act(SmartAction.removeBackground)]),
    ('امسح الخلفيه', [act(SmartAction.removeBackground)]),
    ('أزل الشخص', [act(SmartAction.erasePerson)]),
    ('امسح الشخص', [act(SmartAction.erasePerson)]),
    ('شيل الشخص', [act(SmartAction.erasePerson)]),
    ('قص الشخص', [act(SmartAction.cutOutPerson)]),
    ('طمس الخلفية', [act(SmartAction.blurBackground)]),
    ('وضع البورتريه', [act(SmartAction.depthBlur)]),
    ('حسن الوجه', [act(SmartAction.retouch)]),
    ('نعم البشره', [act(SmartAction.retouch)]),
    ('ازل الحبوب', [act(SmartAction.heal)]),
    ('حدد العنصر', [act(SmartAction.selectObject)]),
    ('كبر الصورة', [act(SmartAction.upscale)]),
    ('حسن الصورة', [act(SmartAction.autoEnhance)]),
    ('زين الصورة', [act(SmartAction.autoEnhance)]),
    ('خليها حلوة', [act(SmartAction.autoEnhance)]),
    ('خليها منيحه', [act(SmartAction.autoEnhance)]),
    ('ألغ الفلتر', [act(SmartAction.clearLook)]),
    ('ازل الضباب', [up(AdjustmentParam.dehaze, 0.4)]),
    ('اطفي الحبيبات', [setTo(AdjustmentParam.grain, 0)]),
    ('بدون الحبيبات', [setTo(AdjustmentParam.grain, 0)]),
    ('وضح الصورة', [up(AdjustmentParam.clarity, 0.25)]),
    ('حط التشبع', [up(AdjustmentParam.saturation, 0.2)]),
    ('rotate left', [act(SmartAction.rotateLeft)]),
    ('rotate right', [act(SmartAction.rotateRight)]),
    ('flip', [act(SmartAction.flipHorizontal)]),
    ('flip vertically', [act(SmartAction.flipVertical)]),
    ('undo', [act(SmartAction.undo)]),
    ('start over', [act(SmartAction.reset)]),
    ('remove background', [act(SmartAction.removeBackground)]),
    ('erase the background', [act(SmartAction.removeBackground)]),
    ('delete the background', [act(SmartAction.removeBackground)]),
    ('remove the person', [act(SmartAction.erasePerson)]),
    ('erase the tourists', [act(SmartAction.erasePerson)]),
    ('cut out the person', [act(SmartAction.cutOutPerson)]),
    ('blur the background', [act(SmartAction.blurBackground)]),
    ('portrait mode', [act(SmartAction.depthBlur)]),
    ('smooth skin', [act(SmartAction.retouch)]),
    ('remove blemishes', [act(SmartAction.heal)]),
    ('select the cup', [act(SmartAction.selectObject)]),
    ('upscale', [act(SmartAction.upscale)]),
    ('enhance', [act(SmartAction.autoEnhance)]),
    ('auto fix', [act(SmartAction.autoEnhance)]),
    ('remove the filter', [act(SmartAction.clearLook)]),
    ('no grain', [setTo(AdjustmentParam.grain, 0)]),
    ('remove haze', [up(AdjustmentParam.dehaze, 0.4)]),
  ]);

  // ------------------------------------------------------------------
  // Family 6 — multi-clause sentences and Arabic/English code-switching.
  cases.addAll(<(String, List<EditOp>)>[
    ('زد التباين وقلل التشبع', [up(AdjustmentParam.contrast, 0.2), up(AdjustmentParam.saturation, -0.2)]),
    (
      'زد التباين ثم الاضاءات واخيرا الحده',
      [up(AdjustmentParam.contrast, 0.2), up(AdjustmentParam.highlights, 0.25), up(AdjustmentParam.sharpen, 0.3)],
    ),
    ('اجعلها أدفأ ثم أبيض واسود', [up(AdjustmentParam.temperature, 0.2), look('mono')]),
    ('اجعلها warmer', [up(AdjustmentParam.temperature, 0.2)]),
    ('make it أدفأ', [up(AdjustmentParam.temperature, 0.2)]),
    ('اجعلها أدفأ ثم more contrast', [up(AdjustmentParam.temperature, 0.2), up(AdjustmentParam.contrast, 0.2)]),
    ('make it warmer ثم أبيض واسود', [up(AdjustmentParam.temperature, 0.2), look('mono')]),
    ('خليها كتير حالمه', [look('dreamy')]),
    (
      'warmer, more contrast, then black and white',
      [up(AdjustmentParam.temperature, 0.2), up(AdjustmentParam.contrast, 0.2), look('mono')],
    ),
    ('brighter and less saturated', [up(AdjustmentParam.exposure, 0.35), up(AdjustmentParam.saturation, -0.2)]),
    ('more contrast and lift the shadows', [up(AdjustmentParam.contrast, 0.2), up(AdjustmentParam.shadows, 0.25)]),
    ('remove the background and upscale', [act(SmartAction.removeBackground), act(SmartAction.upscale)]),
    ('make it pop and cinematic', [up(AdjustmentParam.vibrance, 0.25), look('blockbuster')]),
    ('moins de saturation', [up(AdjustmentParam.saturation, -0.2)]),
    ('زد التباين بزاف', [up(AdjustmentParam.contrast, 0.2 * 1.8)]),
    ('ازل الضباب وارفع الظلال', [up(AdjustmentParam.dehaze, 0.4), up(AdjustmentParam.shadows, 0.25)]),
  ]);

  // ------------------------------------------------------------------
  // Scoring
  String lang(String phrase) => RegExp(r'[\u0600-\u06FF]').hasMatch(phrase) ? 'ar' : 'en';

  var arTotal = 0;
  var arExact = 0;
  var enTotal = 0;
  var enExact = 0;
  final failures = <String>[];

  for (final (phrase, expected) in cases) {
    final plan = e.parse(phrase);
    final ok = plan.ops.toString() == expected.toString() && plan.unrecognized.isEmpty;
    if (lang(phrase) == 'ar') {
      arTotal++;
      if (ok) arExact++;
    } else {
      enTotal++;
      if (ok) enExact++;
    }
    if (!ok) {
      final unknown = plan.unrecognized.isEmpty ? '' : ' unrecognized: ${plan.unrecognized}';
      failures.add('"$phrase"\n  expected: $expected\n  actual:   ${plan.ops}$unknown');
    }
  }

  test('benchmark covers 1,000+ commands', () {
    expect(cases.length, greaterThanOrEqualTo(1000), reason: 'benchmark size');
    expect(arTotal, greaterThanOrEqualTo(900), reason: 'Arabic share');
    expect(enTotal, greaterThanOrEqualTo(250), reason: 'English share');
  });

  test('Arabic exact-plan accuracy ≥ 95 %', () {
    // Print the score so CI logs keep the measured number of each run.
    // ignore: avoid_print
    print('Arabic: $arExact/$arTotal = ${(arExact / arTotal * 100).toStringAsFixed(1)} %');
    expect(arExact / arTotal, greaterThanOrEqualTo(0.95), reason: failures.take(15).join('\n'));
  });

  test('English exact-plan accuracy ≥ 95 %', () {
    // Print the score so CI logs keep the measured number of each run.
    // ignore: avoid_print
    print('English: $enExact/$enTotal = ${(enExact / enTotal * 100).toStringAsFixed(1)} %');
    expect(enExact / enTotal, greaterThanOrEqualTo(0.95), reason: failures.take(15).join('\n'));
  });
}
