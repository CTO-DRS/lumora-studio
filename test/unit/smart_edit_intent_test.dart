import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/photo_editor/domain/geometry.dart';
import 'package:lumora/features/photo_editor/domain/presets.dart';
import 'package:lumora/features/smart_edit/domain/edit_ops.dart';
import 'package:lumora/features/smart_edit/domain/intent_engine.dart';
import 'package:lumora/features/smart_edit/domain/text_normalizer.dart';

const _e = RuleIntentEngine();

AdjustOp up(AdjustmentParam p, double v) => AdjustOp(p, v);
AdjustOp setTo(AdjustmentParam p, double v) => AdjustOp(p, v, absolute: true);
ActionOp act(SmartAction a) => ActionOp(a);
LookOp look(String id, [double k = 1]) => LookOp(id, intensity: k);

void expectPlan(String text, List<EditOp> ops) {
  final plan = _e.parse(text);
  expect(plan.ops, ops, reason: '"$text" → $plan');
  expect(plan.unrecognized, isEmpty, reason: '"$text" → $plan');
}

void main() {
  group('normalizeCommandText', () {
    test('Arabic letters, diacritics, digits and punctuation', () {
      expect(normalizeCommandText('أَدْفَأ'), 'ادفا');
      expect(normalizeCommandText('إضاءة'), 'اضاءه');
      expect(normalizeCommandText('مستوى'), 'مستوي');
      expect(normalizeCommandText('قليـــلاً'), 'قليلا');
      expect(normalizeCommandText('٢٠٪'), '20%');
      expect(normalizeCommandText('زد السطوع، ثم قلل التباين'), 'زد السطوع , ثم قلل التباين');
      expect(normalizeCommandText('Make It WARMER.'), 'make it warmer .');
      expect(normalizeCommandText('exposure 0.5'), 'exposure 0.5');
    });

    test('tokenStems strips Arabic prefixes but keeps English words', () {
      expect(tokenStems('والخلفيه'), containsAll(<String>['والخلفيه', 'الخلفيه', 'خلفيه']));
      expect(tokenStems('background'), ['background']);
    });
  });

  group('Arabic commands', () {
    final cases = <String, List<EditOp>>{
      'اجعلها أدفأ': [up(AdjustmentParam.temperature, 0.2)],
      'أدفأ قليلاً': [up(AdjustmentParam.temperature, 0.1)],
      'أبرد': [up(AdjustmentParam.temperature, -0.2)],
      'أقل دفئاً': [up(AdjustmentParam.temperature, -0.2)],
      'زد السطوع قليلاً': [up(AdjustmentParam.exposure, 0.175)],
      'زد السطوع': [up(AdjustmentParam.exposure, 0.35)],
      'قلل السطوع كثيراً': [up(AdjustmentParam.exposure, -0.63)],
      'اجعلها أفتح': [up(AdjustmentParam.exposure, 0.35)],
      'أغمق شوية': [up(AdjustmentParam.exposure, -0.175)],
      'زد التباين': [up(AdjustmentParam.contrast, 0.2)],
      'زد التباين وقلل التشبع': [up(AdjustmentParam.contrast, 0.2), up(AdjustmentParam.saturation, -0.2)],
      'زد التباين والتشبع': [up(AdjustmentParam.contrast, 0.2), up(AdjustmentParam.saturation, 0.2)],
      'زد التباين ٢٠٪': [up(AdjustmentParam.contrast, 0.2)],
      'اجعل التباين 30': [setTo(AdjustmentParam.contrast, 0.3)],
      'خفف الإضاءات العالية': [up(AdjustmentParam.highlights, -0.25)],
      'ارفع الظلال': [up(AdjustmentParam.shadows, 0.25)],
      'افتح الظلال': [up(AdjustmentParam.shadows, 0.25)],
      'اجعلها أوضح': [up(AdjustmentParam.clarity, 0.25)],
      'زد الحدة': [up(AdjustmentParam.sharpen, 0.3)],
      'زد التفاصيل': [up(AdjustmentParam.structure, 0.25)],
      'ألوان أكثر حيوية': [up(AdjustmentParam.saturation, 0.2), up(AdjustmentParam.vibrance, 0.25)],
      'أضف حبيبات': [up(AdjustmentParam.grain, 0.25)],
      'أضف تظليل للحواف': [up(AdjustmentParam.vignette, -0.3)],
      'اغمق الحواف': [up(AdjustmentParam.vignette, -0.3)],
      'بدون حبيبات': [setTo(AdjustmentParam.grain, 0)],
      'ازل الضباب': [up(AdjustmentParam.dehaze, 0.4)],
      'احذف الألوان': [setTo(AdjustmentParam.saturation, -1)],
      'أزل الخلفية': [act(SmartAction.removeBackground)],
      'احذف الخلفيه': [act(SmartAction.removeBackground)],
      'خلفية شفافة': [act(SmartAction.removeBackground)],
      'اجعل الخلفية ضبابية': [act(SmartAction.blurBackground)],
      'طمس الخلفية': [act(SmartAction.blurBackground)],
      'اغمق الخلفية': [act(SmartAction.relight)],
      'وضع البورتريه': [act(SmartAction.depthBlur)],
      'أزل الشخص': [act(SmartAction.erasePerson)],
      'امسح الناس من الصورة': [act(SmartAction.erasePerson)],
      'قص الشخص': [act(SmartAction.cutOutPerson)],
      'احذف هذا': [act(SmartAction.eraseObject)],
      'ازل الحبوب': [act(SmartAction.heal)],
      'حسن الوجه': [act(SmartAction.retouch)],
      'نعّم البشرة': [act(SmartAction.retouch)],
      'حسن الصورة': [act(SmartAction.autoEnhance)],
      'تحسين تلقائي': [act(SmartAction.autoEnhance)],
      'كبر الصورة': [act(SmartAction.upscale)],
      'دقة أعلى': [act(SmartAction.upscale)],
      'أبيض وأسود': [look('mono')],
      'بالأبيض والأسود': [look('mono')],
      'سينمائي': [look('blockbuster')],
      'طابع سينمائي خفيف': [look('blockbuster', 0.5)],
      'الساعة الذهبية': [look('golden_hour')],
      'ستايل قديم': [look('seventies')],
      'فيلم': [look('portra')],
      'نيون': [look('cyberpunk')],
      'ألغ الفلتر': [act(SmartAction.clearLook)],
      'دور الصورة لليسار': [act(SmartAction.rotateLeft)],
      'دوّر': [act(SmartAction.rotateRight)],
      'اعكس الصورة': [act(SmartAction.flipHorizontal)],
      'اقلب الصورة عموديا': [act(SmartAction.flipVertical)],
      'تراجع': [act(SmartAction.undo)],
      'إعادة ضبط': [act(SmartAction.reset)],
      'حدد العنصر': [act(SmartAction.selectObject)],
      'أزل الخلفية واجعلها أدفأ': [act(SmartAction.removeBackground), up(AdjustmentParam.temperature, 0.2)],
      'زد السطوع ثم أبيض وأسود': [up(AdjustmentParam.exposure, 0.35), look('mono')],
    };
    for (final c in cases.entries) {
      test(c.key, () => expectPlan(c.key, c.value));
    }
  });

  group('English commands', () {
    final cases = <String, List<EditOp>>{
      'make it warmer': [up(AdjustmentParam.temperature, 0.2)],
      'a bit cooler': [up(AdjustmentParam.temperature, -0.1)],
      'less warm': [up(AdjustmentParam.temperature, -0.2)],
      'much brighter': [up(AdjustmentParam.exposure, 0.63)],
      'darker please': [up(AdjustmentParam.exposure, -0.35)],
      'increase brightness slightly': [up(AdjustmentParam.exposure, 0.175)],
      'reduce brightness': [up(AdjustmentParam.exposure, -0.35)],
      'exposure +1': [up(AdjustmentParam.exposure, 1)],
      'exposure -0.5': [up(AdjustmentParam.exposure, -0.5)],
      'set contrast to 30': [setTo(AdjustmentParam.contrast, 0.3)],
      'more contrast': [up(AdjustmentParam.contrast, 0.2)],
      'increase contrast and saturation': [up(AdjustmentParam.contrast, 0.2), up(AdjustmentParam.saturation, 0.2)],
      'reduce highlights and lift shadows': [up(AdjustmentParam.highlights, -0.25), up(AdjustmentParam.shadows, 0.25)],
      'brighten the shadows': [up(AdjustmentParam.shadows, 0.25)],
      'make it pop': [up(AdjustmentParam.vibrance, 0.25)],
      'more vivid': [up(AdjustmentParam.vibrance, 0.25)],
      'desaturate': [up(AdjustmentParam.saturation, -0.2)],
      'sharpen a lot': [up(AdjustmentParam.sharpen, 0.54)],
      'softer': [up(AdjustmentParam.clarity, -0.25)],
      'add film grain': [up(AdjustmentParam.grain, 0.25)],
      'add vignette': [up(AdjustmentParam.vignette, -0.3)],
      'vignette 30': [setTo(AdjustmentParam.vignette, -0.3)],
      'darken the edges': [up(AdjustmentParam.vignette, -0.3)],
      'no vignette': [setTo(AdjustmentParam.vignette, 0)],
      'remove haze': [up(AdjustmentParam.dehaze, 0.4)],
      'add some fog': [up(AdjustmentParam.dehaze, -0.25)],
      'faded matte look': [up(AdjustmentParam.fade, 0.2)],
      'black and white': [look('mono')],
      'B&W': [look('mono')],
      'turn it black and white': [look('mono')],
      'monochrome': [look('mono')],
      'film noir': [look('noir')],
      'cinematic': [look('blockbuster')],
      'slightly cinematic': [look('blockbuster', 0.5)],
      'teal and orange': [look('teal_orange')],
      'vintage': [look('seventies')],
      'golden hour': [look('golden_hour')],
      'moody and dramatic': [look('moody')],
      'remove the filter': [act(SmartAction.clearLook)],
      'remove background': [act(SmartAction.removeBackground)],
      'transparent background': [act(SmartAction.removeBackground)],
      'cut out': [act(SmartAction.removeBackground)],
      'cut out the person': [act(SmartAction.cutOutPerson)],
      'blur the background': [act(SmartAction.blurBackground)],
      'bokeh': [act(SmartAction.depthBlur)],
      'portrait mode': [act(SmartAction.depthBlur)],
      'darken the background': [act(SmartAction.relight)],
      'spotlight': [act(SmartAction.relight)],
      'remove the person': [act(SmartAction.erasePerson)],
      'erase the tourists': [act(SmartAction.erasePerson)],
      'remove this': [act(SmartAction.eraseObject)],
      'remove blemishes': [act(SmartAction.heal)],
      'smooth skin': [act(SmartAction.retouch)],
      'improve the skin': [act(SmartAction.retouch)],
      'enhance': [act(SmartAction.autoEnhance)],
      'auto fix': [act(SmartAction.autoEnhance)],
      'enhance contrast': [up(AdjustmentParam.contrast, 0.2)],
      'upscale': [act(SmartAction.upscale)],
      'enhance resolution': [act(SmartAction.upscale)],
      'rotate left': [act(SmartAction.rotateLeft)],
      'rotate': [act(SmartAction.rotateRight)],
      'rotate 180': [act(SmartAction.rotateRight), act(SmartAction.rotateRight)],
      'turn right': [act(SmartAction.rotateRight)],
      'flip': [act(SmartAction.flipHorizontal)],
      'flip vertically': [act(SmartAction.flipVertical)],
      'undo': [act(SmartAction.undo)],
      'start over': [act(SmartAction.reset)],
      'select the cup': [act(SmartAction.selectObject)],
      'make it warmer and remove the person': [up(AdjustmentParam.temperature, 0.2), act(SmartAction.erasePerson)],
      'warmer, more contrast, then black and white': [
        up(AdjustmentParam.temperature, 0.2),
        up(AdjustmentParam.contrast, 0.2),
        look('mono'),
      ],
    };
    for (final c in cases.entries) {
      test(c.key, () => expectPlan(c.key, c.value));
    }
  });

  group('dialect commands (v1.3.x lexicon pass)', () {
    final cases = <String, List<EditOp>>{
      // Gulf
      'خليها دافيه وايد': [up(AdjustmentParam.temperature, 0.36)],
      'دافي حيل': [up(AdjustmentParam.temperature, 0.36)],
      'خليها زين': [act(SmartAction.autoEnhance)],
      // Egyptian
      'خليها دافيه اوي': [up(AdjustmentParam.temperature, 0.36)],
      'حلو شويه': [act(SmartAction.autoEnhance)],
      'غامق خالص': [up(AdjustmentParam.exposure, -0.63)],
      // Levantine
      'مره حلو': [act(SmartAction.autoEnhance)],
      'خليها برد شوي': [up(AdjustmentParam.temperature, -0.1)],
      // Maghrebi
      'دافيه بزاف': [up(AdjustmentParam.temperature, 0.36)],
      'خليها بارد برشا': [up(AdjustmentParam.temperature, -0.36)],
      'خليها حلوة': [act(SmartAction.autoEnhance)],
      'ديرها زوينه': [act(SmartAction.autoEnhance)],
      // shared
      'زد السطوع شويه': [up(AdjustmentParam.exposure, 0.175)],
      'ع السريع': [act(SmartAction.autoEnhance)],
      'على السريع': [act(SmartAction.autoEnhance)],
    };
    for (final c in cases.entries) {
      test(c.key, () => expectPlan(c.key, c.value));
    }
  });

  group('plan semantics', () {
    test('unknown text is reported, not guessed', () {
      final plan = _e.parse('blah blah');
      expect(plan.isEmpty, isTrue);
      expect(plan.unrecognized, ['blah blah']);
      expect(_e.parse('').isEmpty, isTrue);
    });

    test('partly understood commands keep the understood part', () {
      final plan = _e.parse('warmer and frobnicate the widgets');
      expect(plan.ops, [up(AdjustmentParam.temperature, 0.2)]);
      expect(plan.unrecognized, ['frobnicate the widgets']);
    });

    test('repeated changes to one slider are summed', () {
      expect(_e.parse('warmer, warmer').ops, [up(AdjustmentParam.temperature, 0.4)]);
    });

    test('every look the engine can emit exists', () {
      const phrases = [
        'black and white',
        'noir',
        'cinematic',
        'teal and orange',
        'film',
        'vintage',
        'polaroid',
        'sepia',
        'golden hour',
        'moody',
        'dreamy',
        'airy',
        'hdr',
        'neon',
        'vhs',
        'food',
        'landscape',
        'night',
        'desert',
        'document',
        'studio',
        'nostalgic',
        'old film',
      ];
      for (final p in phrases) {
        final looks = _e.parse(p).looks.toList();
        expect(looks, hasLength(1), reason: p);
        expect(presetById(looks.single.presetId), isNotNull, reason: p);
      }
    });

    test('applyAdjustOps adds, sets and clamps', () {
      final a = applyAdjustOps(const Adjustments(exposure: 0.2, contrast: 0.9), [
        up(AdjustmentParam.exposure, 0.3),
        up(AdjustmentParam.contrast, 0.5),
        setTo(AdjustmentParam.vignette, -0.3),
      ]);
      expect(a.exposure, closeTo(0.5, 1e-9));
      expect(a.contrast, 1);
      expect(a.vignette, -0.3);
    });

    test('geometry actions rotate and flip', () {
      const g = GeometryState();
      expect(applyGeometryAction(g, SmartAction.rotateRight).quarterTurns, 1);
      expect(applyGeometryAction(g, SmartAction.rotateLeft).quarterTurns, 3);
      expect(applyGeometryAction(g, SmartAction.flipHorizontal).flipHorizontal, isTrue);
      expect(applyGeometryAction(g, SmartAction.flipVertical).flipVertical, isTrue);
      expect(applyGeometryAction(g, SmartAction.upscale), g);
    });

    test('plans round-trip through JSON (the contract for an LLM engine)', () {
      final plan = _e.parse('warmer, vignette 30, cinematic and remove the background');
      final json = jsonDecode(jsonEncode(plan.toJson())) as Map<String, Object?>;
      final back = SmartEditPlan.fromJson(json);
      expect(back.ops, plan.ops);
      expect(() => EditOp.fromJson(const {'op': 'nope'}), throwsFormatException);
    });

    test('instant actions are the model-free ones', () {
      expect(SmartAction.rotateLeft.instant, isTrue);
      expect(SmartAction.clearLook.instant, isTrue);
      expect(SmartAction.removeBackground.instant, isFalse);
      expect(SmartAction.selectObject.instant, isFalse);
    });
  });
}
