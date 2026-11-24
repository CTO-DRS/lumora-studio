#!/usr/bin/env python3
"""Generates test/benchmark/intent_benchmark_data.dart — the AR/EN intent
benchmark required by ROADMAP §5 (v1.3.x): 1,000+ commands with their
expected SmartEditPlan ops, so `intent_benchmark_test.dart` can measure
exact-plan accuracy per language (target >= 95 %, AR and EN separately).

Every entry is built from a template whose expected plan is fixed by
construction (steps, directions, intensities follow the engine's rule
table). Re-run after changing the lexicon:

    python3 tool/gen_intent_benchmark.py
"""

from __future__ import annotations

from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "test/benchmark/intent_benchmark_data.dart"

# (token, param, dir, step, kind) — kind 'blur' takes the blur branch
# (no polarity, explicit only); everything else goes through _dir().
SLIDERS_AR = [
    ("السطوع", "exposure", 1, 0.35, "param"),
    ("التباين", "contrast", 1, 0.2, "param"),
    ("الاضاءات", "highlights", 1, 0.25, "param"),
    ("الظلال", "shadows", 1, 0.25, "param"),
    ("البياض", "whites", 1, 0.2, "param"),
    ("السواد", "blacks", 1, 0.2, "param"),
    ("الدفء", "temperature", 1, 0.2, "param"),
    ("الصبغه", "tint", 1, 0.15, "param"),
    ("الحيويه", "vibrance", 1, 0.25, "param"),
    ("التشبع", "saturation", 1, 0.2, "param"),
    ("الباهت", "fade", 1, 0.2, "param"),
    ("الحده", "sharpen", 1, 0.3, "param"),
    ("الوضوح", "clarity", 1, 0.25, "param"),
    ("التفاصيل", "structure", 1, 0.25, "param"),
    ("الضباب", "dehaze", -1, 0.25, "param"),
    ("التمويه", "blur", 1, 0.3, "blur"),
    ("الحواف", "vignette", 1, 0.3, "param"),  # polarity −1
    ("الحبيبات", "grain", 1, 0.25, "param"),
    ("الغليتش", "glitch", 1, 0.3, "param"),
]

SLIDERS_EN = [
    ("brightness", "exposure", 1, 0.35, "param"),
    ("contrast", "contrast", 1, 0.2, "param"),
    ("highlights", "highlights", 1, 0.25, "param"),
    ("shadows", "shadows", 1, 0.25, "param"),
    ("whites", "whites", 1, 0.2, "param"),
    ("blacks", "blacks", 1, 0.2, "param"),
    ("warmth", "temperature", 1, 0.2, "param"),
    ("tint", "tint", 1, 0.15, "param"),
    ("vibrance", "vibrance", 1, 0.25, "param"),
    ("saturation", "saturation", 1, 0.2, "param"),
    ("fade", "fade", 1, 0.2, "param"),
    ("sharpness", "sharpen", 1, 0.3, "param"),
    ("clarity", "clarity", 1, 0.25, "param"),
    ("structure", "structure", 1, 0.25, "param"),
    ("haze", "dehaze", -1, 0.25, "param"),
    ("blur", "blur", 1, 0.3, "blur"),
    ("vignette", "vignette", 1, 0.3, "param"),  # polarity −1
    ("grain", "grain", 1, 0.25, "param"),
    ("glitch", "glitch", 1, 0.3, "param"),
]

# (template, explicit, factor)
TEMPLATES_AR = [
    ("{p}", None, 1.0),
    ("زد {p}", 1, 1.0),
    ("زيد {p}", 1, 1.0),
    ("زود {p}", 1, 1.0),
    ("ارفع {p}", 1, 1.0),
    ("قلل {p}", -1, 1.0),
    ("خفض {p}", -1, 1.0),
    ("اخفض {p}", -1, 1.0),
    ("زد {p} قليلا", 1, 0.5),
    ("زد {p} كثيرا", 1, 1.8),
    ("قلل {p} قليلا", -1, 0.5),
    ("قلل {p} كثيرا", -1, 1.8),
    ("{p} اكثر", 1, 1.0),
    ("{p} اقل", -1, 1.0),
    ("زيادة {p}", 1, 1.0),
    ("تقليل {p}", -1, 1.0),
    ("{p} بقوه", None, 1.8),
    ("{p} شوي", None, 0.5),
    ("{p} كتير", None, 1.8),
    ("اكثر {p}", 1, 1.0),
]

TEMPLATES_EN = [
    ("{p}", None, 1.0),
    ("more {p}", 1, 1.0),
    ("increase {p}", 1, 1.0),
    ("boost {p}", 1, 1.0),
    ("raise {p}", 1, 1.0),
    ("less {p}", -1, 1.0),
    ("reduce {p}", -1, 1.0),
    ("lower {p}", -1, 1.0),
    ("decrease {p}", -1, 1.0),
    ("increase {p} slightly", 1, 0.5),
    ("increase {p} a lot", 1, 1.8),
    ("reduce {p} slightly", -1, 0.5),
    ("reduce {p} a lot", -1, 1.8),
    ("{p} please", None, 1.0),
    ("{p} more", 1, 1.0),
    ("{p} less", -1, 1.0),
    ("a bit more {p}", 1, 0.5),
    ("a bit less {p}", -1, 0.5),
    ("much more {p}", 1, 1.8),
    ("much less {p}", -1, 1.8),
]

POLARITY = {"vignette": -1}

entries: list[tuple[str, str, list[str]]] = []  # (text, lang, expected op literals)


def num(x: float) -> str:
    """Dart literal: whole values as ints (prefer_int_literals lint)."""
    return str(int(x)) if float(x) == int(x) else repr(x)


def adj(param: str, amount: float, absolute: bool = False) -> str:
    if absolute:
        return f"adj('{param}', {num(amount)}, absolute: true)"
    return f"adj('{param}', {num(amount)})"


def look(preset: str, intensity: float = 1.0) -> str:
    return f"look('{preset}', {num(intensity)})" if intensity != 1.0 else f"look('{preset}')"


def act(action: str) -> str:
    return f"act('{action}')"


def slider_amount(step: float, factor: float, explicit: int | None, pdir: int, kind: str, param: str) -> float:
    if kind == "blur":
        return round(step * factor * (explicit if explicit is not None else 1), 10)
    polarity = POLARITY.get(param, 1)
    return round(step * factor * pdir * (explicit if explicit is not None else 1) * polarity, 10)


# ---- slider templates -------------------------------------------------------
for token, param, pdir, step, kind in SLIDERS_AR:
    for tpl, explicit, factor in TEMPLATES_AR:
        text = tpl.replace("{p}", token)
        amount = slider_amount(step, factor, explicit, pdir, kind, param)
        entries.append((text, "ar", [adj(param, amount)]))

for token, param, pdir, step, kind in SLIDERS_EN:
    for tpl, explicit, factor in TEMPLATES_EN:
        text = tpl.replace("{p}", token)
        amount = slider_amount(step, factor, explicit, pdir, kind, param)
        entries.append((text, "en", [adj(param, amount)]))

# ---- numbers (absolute / percent / signed) ---------------------------------
for token, param, pdir, step, kind in SLIDERS_AR:
    if param in ("blur", "exposure"):
        continue
    pol = POLARITY.get(param, 1)
    entries.append((f"{token} 20%", "ar", [adj(param, round(0.2 * pol, 10), True)]))
    entries.append((f"اجعل {token} 30", "ar", [adj(param, round(0.3 * pol, 10), True)]))
entries.append(("السطوع 25%", "ar", [adj("exposure", 0.5, True)]))
entries.append(("اجعل السطوع 50%", "ar", [adj("exposure", 1.0, True)]))
entries.append(("زد السطوع 50%", "ar", [adj("exposure", 1.0)]))

for token, param, pdir, step, kind in SLIDERS_EN:
    if param in ("blur", "exposure"):
        continue
    pol = POLARITY.get(param, 1)
    entries.append((f"{token} 20%", "en", [adj(param, round(0.2 * pol, 10), True)]))
    entries.append((f"set {token} to 30", "en", [adj(param, round(0.3 * pol, 10), True)]))
entries.append(("brightness 50%", "en", [adj("exposure", 1.0, True)]))
entries.append(("exposure 0.5", "en", [adj("exposure", 0.5, True)]))
entries.append(("exposure +1", "en", [adj("exposure", 1.0)]))
entries.append(("exposure -0.5", "en", [adj("exposure", -0.5)]))
entries.append(("no grain", "en", [adj("grain", 0.0, True)]))
entries.append(("no vignette", "en", [adj("vignette", 0.0, True)]))
entries.append(("remove the colours", "en", [adj("saturation", -1.0, True)]))
entries.append(("بدون حبيبات", "ar", [adj("grain", 0.0, True)]))
entries.append(("بدون تظليل", "ar", [adj("vignette", 0.0, True)]))
entries.append(("ازل التشبع", "ar", [adj("saturation", -1.0, True)]))
entries.append(("زد التباين 20%", "ar", [adj("contrast", 0.2)]))
entries.append(("قلل الحبيبات 50%", "ar", [adj("grain", -0.5)]))

# ---- looks ------------------------------------------------------------------
LOOKS_AR = [
    ("ابيض واسود", "mono"), ("رمادي", "mono"), ("نوار", "noir"),
    ("سينمائي", "blockbuster"), ("هوليود", "blockbuster"), ("تركواز", "teal_orange"),
    ("فيلم", "portra"), ("قديم", "seventies"), ("ريترو", "seventies"),
    ("سبعينات", "seventies"), ("سيبيا", "sepia"), ("بولارويد", "polaroid_fade"),
    ("غروب", "golden_hour"), ("ذهبي", "golden_hour"), ("درامي", "moody"),
    ("كئيب", "moody"), ("حالم", "dreamy"), ("هوائي", "airy"),
    ("نيون", "cyberpunk"), ("سايبر", "cyberpunk"), ("طعام", "food_fresh"),
    ("طبيعه", "vivid_landscape"), ("منظر", "vivid_landscape"), ("ليل", "night_city"),
    ("صحراء", "desert_gold"), ("صحراوي", "desert_gold"), ("مستند", "clean_paper"),
    ("استوديو", "studio"), ("فيلم قديم", "expired"),
]
for phrase, preset in LOOKS_AR:
    entries.append((phrase, "ar", [look(preset)]))
for phrase, preset in [
    ("سينمائي خفيف", "blockbuster"), ("ابيض واسود خفيف", "mono"),
    ("طابع سينمائي خفيف", "blockbuster"), ("غروب خفيف", "golden_hour"),
    ("نيون خفيف", "cyberpunk"), ("قديم خفيف", "seventies"),
    ("درامي خفيف", "moody"), ("فيلم خفيف", "portra"),
]:
    entries.append((phrase, "ar", [look(preset, 0.5)]))

LOOKS_EN = [
    ("black and white", "mono"), ("monochrome", "mono"), ("grayscale", "mono"),
    ("b&w", "mono"), ("film noir", "noir"), ("noir", "noir"),
    ("cinematic", "blockbuster"), ("movie", "blockbuster"), ("teal and orange", "teal_orange"),
    ("teal", "teal_orange"), ("film", "portra"), ("kodak", "portra"),
    ("vintage", "seventies"), ("retro", "seventies"), ("70s", "seventies"),
    ("polaroid", "polaroid_fade"), ("sepia", "sepia"), ("sunset", "golden_hour"),
    ("golden hour", "golden_hour"), ("moody", "moody"), ("dramatic", "moody"),
    ("dreamy", "dreamy"), ("airy", "airy"), ("hdr", "hdr_natural"),
    ("cyberpunk", "cyberpunk"), ("neon", "cyberpunk"), ("vhs", "vhs"),
    ("food", "food_fresh"), ("landscape", "vivid_landscape"), ("nature", "vivid_landscape"),
    ("night", "night_city"), ("desert", "desert_gold"), ("document", "clean_paper"),
    ("studio", "studio"), ("old film", "expired"),
]
for phrase, preset in LOOKS_EN:
    entries.append((phrase, "en", [look(preset)]))
for phrase, preset in [
    ("slightly cinematic", "blockbuster"), ("slightly vintage", "seventies"),
    ("slightly moody", "moody"), ("slightly golden hour", "golden_hour"),
    ("a bit cinematic", "blockbuster"), ("a bit vintage", "seventies"),
    ("a bit moody", "moody"), ("a bit dreamy", "dreamy"),
]:
    entries.append((phrase, "en", [look(preset, 0.5)]))

# ---- actions ----------------------------------------------------------------
ACTIONS_AR = [
    ("ازل الخلفيه", "removeBackground"), ("خلفيه شفافه", "removeBackground"),
    ("بدون خلفيه", "removeBackground"), ("طمس الخلفيه", "blurBackground"),
    ("اجعل الخلفيه ضبابيه", "blurBackground"), ("اغمق الخلفيه", "relight"),
    ("سبوت", "relight"), ("وضع البورتريه", "depthBlur"), ("بوكيه", "depthBlur"),
    ("ازل الشخص", "erasePerson"), ("امسح الناس", "erasePerson"),
    ("قص الشخص", "cutOutPerson"), ("احذف هذا", "eraseObject"),
    ("ازل الحبوب", "heal"), ("عالج الحبوب", "heal"), ("حسن الوجه", "retouch"),
    ("نعم البشره", "retouch"), ("حسن الصوره", "autoEnhance"),
    ("تحسين تلقائي", "autoEnhance"), ("كبر الصوره", "upscale"),
    ("دقه اعلي", "upscale"), ("جوده اعلي", "upscale"),
    ("اعاده ضبط", "reset"), ("تراجع", "undo"), ("دوّر", "rotateRight"),
    ("دور الصوره لليسار", "rotateLeft"), ("دور الصوره لليمين", "rotateRight"),
    ("اعكس الصوره", "flipHorizontal"), ("اقلب الصوره عموديا", "flipVertical"),
    ("الغ الفلتر", "clearLook"), ("حدد العنصر", "selectObject"),
]
for phrase, action in ACTIONS_AR:
    entries.append((phrase, "ar", [act(action)]))

ACTIONS_EN = [
    ("remove background", "removeBackground"), ("transparent background", "removeBackground"),
    ("no background", "removeBackground"), ("blur the background", "blurBackground"),
    ("darken the background", "relight"), ("spotlight", "relight"),
    ("portrait mode", "depthBlur"), ("bokeh", "depthBlur"),
    ("remove the person", "erasePerson"), ("erase the tourists", "erasePerson"),
    ("cut out the person", "cutOutPerson"), ("remove this", "eraseObject"),
    ("remove blemishes", "heal"), ("smooth skin", "retouch"),
    ("improve the skin", "retouch"), ("enhance", "autoEnhance"),
    ("auto fix", "autoEnhance"), ("upscale", "upscale"),
    ("enhance resolution", "upscale"), ("rotate", "rotateRight"),
    ("rotate left", "rotateLeft"), ("flip", "flipHorizontal"),
    ("flip vertically", "flipVertical"), ("undo", "undo"),
    ("start over", "reset"), ("remove the filter", "clearLook"),
    ("select the cup", "selectObject"),
]
for phrase, action in ACTIONS_EN:
    entries.append((phrase, "en", [act(action)]))

# ---- compounds (two intents, clause order preserved) ------------------------
COMPOUNDS_AR = [
    ("زد التباين وقلل التشبع", [adj("contrast", 0.2), adj("saturation", -0.2)]),
    ("زد التباين والتشبع", [adj("contrast", 0.2), adj("saturation", 0.2)]),
    ("ازل الخلفيه واجعلها ادفا", [act("removeBackground"), adj("temperature", 0.2)]),
    ("زد السطوع ثم ابيض واسود", [adj("exposure", 0.35), look("mono")]),
    ("اجعلها ادفا قليلا وازل الخلفيه", [adj("temperature", 0.1), act("removeBackground")]),
    ("زد السطوع وزد التباين", [adj("exposure", 0.35), adj("contrast", 0.2)]),
    ("ادفا وابيض واسود", [adj("temperature", 0.2), look("mono")]),
    ("حسن الصوره وامسح الناس", [act("autoEnhance"), act("erasePerson")]),
    ("ازل الحبوب وحسن الوجه", [act("heal"), act("retouch")]),
    ("دافي وازل الخلفيه", [adj("temperature", 0.2), act("removeBackground")]),
    ("دور الصوره لليمين واعكسها", [act("rotateRight"), act("flipHorizontal")]),
    ("ازل الضباب وارفع الظلال", [adj("dehaze", 0.4), adj("shadows", 0.25)]),
]
for text, ops in COMPOUNDS_AR:
    entries.append((text, "ar", ops))

COMPOUNDS_EN = [
    ("warmer, more contrast, then black and white", [adj("temperature", 0.2), adj("contrast", 0.2), look("mono")]),
    ("make it warmer and remove the person", [adj("temperature", 0.2), act("erasePerson")]),
    ("increase contrast and saturation", [adj("contrast", 0.2), adj("saturation", 0.2)]),
    ("reduce highlights and lift shadows", [adj("highlights", -0.25), adj("shadows", 0.25)]),
    ("brighten the shadows", [adj("shadows", 0.25)]),
    ("exposure +0.5 and more contrast", [adj("exposure", 0.5), adj("contrast", 0.2)]),
    ("increase brightness and lower saturation", [adj("exposure", 0.35), adj("saturation", -0.2)]),
    ("remove the background and upscale", [act("removeBackground"), act("upscale")]),
    ("cinematic and vignette 30", [look("blockbuster"), adj("vignette", -0.3, True)]),
    ("remove the filter and add film grain", [act("clearLook"), adj("grain", 0.25)]),
    ("rotate 180 and flip", [act("rotateRight"), act("rotateRight"), act("flipHorizontal")]),
    ("warmer and cut out the person", [adj("temperature", 0.2), act("cutOutPerson")]),
    ("boost contrast and reduce haze", [adj("contrast", 0.2), adj("dehaze", 0.25)]),
    ("set contrast to 30 and black and white", [adj("contrast", 0.3, True), look("mono")]),
    ("remove the background and make it cooler", [act("removeBackground"), adj("temperature", -0.2)]),
    ("darker please and no vignette", [adj("exposure", -0.35), adj("vignette", 0.0, True)]),
]
for text, ops in COMPOUNDS_EN:
    entries.append((text, "en", ops))

# ---- dialects (Gulf, Egyptian, Levantine, Maghrebi) -------------------------
DIALECT_STRONG = [
    ("وايد", "gulf"), ("حيل", "gulf"), ("اوي", "egyptian"), ("خالص", "egyptian"),
    ("مره", "levantine"), ("بزاف", "maghrebi"), ("برشا", "maghrebi"),
]
for word, _dialect in DIALECT_STRONG:
    for token, param, pdir, step, kind in SLIDERS_AR[:3]:  # exposure, contrast, temperature
        amount = slider_amount(step, 1.8, None, pdir, kind, param)
        entries.append((f"{token} {word}", "ar", [adj(param, amount)]))

for word in ["شويه", "شوي"]:
    entries.append((f"السطوع {word}", "ar", [adj("exposure", round(0.35 * 0.5, 10))]))
    entries.append((f"الدفء {word}", "ar", [adj("temperature", round(0.2 * 0.5, 10))]))

DIALECT_ACTIONS = [
    ("خليها زين", "autoEnhance"), ("حلو شويه", "autoEnhance"),
    ("مره حلو", "autoEnhance"), ("ديرها زوينه", "autoEnhance"),
    ("ع السريع", "autoEnhance"), ("على السريع", "autoEnhance"),
    ("حلو اوي", "autoEnhance"), ("مليح", "autoEnhance"), ("باهي", "autoEnhance"),
    ("خليها دافيه اوي", None), ("دافي حيل", None), ("دافيه بزاف", None),
    ("خليها بارد برشا", None), ("خليها برد شوي", None),
]
for phrase, action in DIALECT_ACTIONS:
    if action:
        entries.append((phrase, "ar", [act(action)]))
    else:
        # temperature phrases: اوي/حيل/بزاف/برشا = strong (×1.8), شوي = slight (×0.5)
        factor = 0.5 if phrase.endswith("شوي") else 1.8
        sign = -1.0 if ("برد" in phrase or "بارد" in phrase) else 1.0
        entries.append((phrase, "ar", [adj("temperature", round(sign * 0.2 * factor, 10))]))

# ---- code-switching (AR function words + EN content words and vice versa) ---
CODESWITCH = [
    ("اجعلها warmer", "ar", [adj("temperature", 0.2)]),
    ("اجعلها black and white", "ar", [look("mono")]),
    ("اجعلها cinematic", "ar", [look("blockbuster")]),
    ("اجعلها mono", "ar", [look("mono")]),
    ("make it ادفا", "en", [adj("temperature", 0.2)]),
    ("زد brightness", "ar", [adj("exposure", 0.35)]),
    ("زد warmth", "ar", [adj("temperature", 0.2)]),
    ("increase التباين", "en", [adj("contrast", 0.2)]),
    ("reduce السطوع", "en", [adj("exposure", -0.35)]),
    ("remove الخلفيه", "en", [act("removeBackground")]),
    ("blur الخلفيه", "en", [act("blurBackground")]),
    ("make it سينمائي", "en", [look("blockbuster")]),
    ("brighten الظلال", "en", [adj("shadows", 0.25)]),
    ("اجعلها softer", "ar", [adj("clarity", -0.25)]),
]
for text, lang, ops in CODESWITCH:
    entries.append((text, lang, ops))

# ---- chains (three intents) -------------------------------------------------
CHAINS = [
    ("زد السطوع وزد التباين وابيض واسود", "ar", [adj("exposure", 0.35), adj("contrast", 0.2), look("mono")]),
    ("ادفا ثم ابرد ثم سينمائي", "ar", [adj("temperature", 0.0), look("blockbuster")]),
    ("زد السطوع قليلا وقلل التشبع كثيرا", "ar", [adj("exposure", 0.175), adj("saturation", -0.36)]),
    ("ازل الخلفيه وامسح الناس ودور الصوره", "ar", [act("removeBackground"), act("erasePerson"), act("rotateRight")]),
    ("warmer, cooler, cinematic", "en", [adj("temperature", 0.0), look("blockbuster")]),
    ("more contrast, less contrast, mono", "en", [adj("contrast", 0.0), look("mono")]),
    ("remove background, upscale, rotate right", "en", [act("removeBackground"), act("upscale"), act("rotateRight")]),
    ("exposure +1, contrast 20%, vignette 30", "en", [adj("exposure", 1.0), adj("contrast", 0.2, True), adj("vignette", -0.3, True)]),
    ("smooth skin, sharpen a lot, undo", "en", [act("retouch"), adj("sharpen", round(0.3 * 1.8, 10)), act("undo")]),
    ("black and white, then remove the filter", "en", [look("mono"), act("clearLook")]),
]
for text, lang, ops in CHAINS:
    entries.append((text, lang, ops))

# ---- de-duplicate by text (first wins), keep language counts balanced -------
seen: set[str] = set()
unique: list[tuple[str, str, list[str]]] = []
for e in entries:
    if e[0] in seen:
        continue
    seen.add(e[0])
    unique.append(e)

ar = [e for e in unique if e[1] == "ar"]
en = [e for e in unique if e[1] == "en"]
print(f"AR: {len(ar)}  EN: {len(en)}  total: {len(unique)}")

def fmt_ops(ops: list[str]) -> str:
    return "[" + ", ".join(ops) + "]"

lines = [
    "// GENERATED by tool/gen_intent_benchmark.py — do not edit by hand.",
    "// The intent benchmark of ROADMAP §5 (v1.3.x): every entry pairs a",
    "// command with the exact plan the rule engine must produce.",
    "",
    "/// One benchmark entry: command text, language, expected plan ops",
    "/// (the same JSON contract as SmartEditPlan.toJson).",
    "class BenchmarkEntry {",
    "  const BenchmarkEntry(this.text, this.lang, this.expected);",
    "",
    "  final String text;",
    "  final String lang;",
    "  final List<Map<String, Object?>> expected;",
    "}",
    "",
    "Map<String, Object?> adj(String param, double amount, {bool absolute = false}) =>",
    "    {'op': 'adjust', 'param': param, 'amount': amount, 'absolute': absolute};",
    "",
    "Map<String, Object?> look(String preset, [double intensity = 1]) =>",
    "    {'op': 'look', 'preset': preset, 'intensity': intensity};",
    "",
    "Map<String, Object?> act(String action) => {'op': 'action', 'action': action};",
    "",
    "final List<BenchmarkEntry> kIntentBenchmark = <BenchmarkEntry>[",
]
for text, lang, ops in unique:
    text_esc = text.replace("\\", "\\\\").replace("'", "\\'")
    lines.append(f"  BenchmarkEntry('{text_esc}', '{lang}', {fmt_ops(ops)}),")
lines.append("];")
lines.append("")

OUT.write_text("\n".join(lines), encoding="utf-8")
print(f"wrote {OUT}")
