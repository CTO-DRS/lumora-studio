# Smart edit · التعديل الذكي

Lumora 1.3 lets people edit by typing what they want, in Arabic or English, and suggests one-tap fixes for each photo. Everything runs on the device.

## 1. Command → plan

```
"زد التباين وقلل التشبع ثم أبيض وأسود"
        │ normalizeCommandText   (diacritics, tatweel, أ/إ/آ→ا, ة→ه, ى→ي, ٠-٩→0-9, punctuation)
        │ phrase table           ("أبيض وأسود" → @mono, "black and white" → @mono, "a bit" → @slight …)
        │ clause split           (, ; . ثم and then, و/ف glued to a verb: "وقلل")
        │ per clause: lexicon    (longest-prefix match on each token and its Arabic prefix-stripped stems)
        ▼
SmartEditPlan [ adjust(contrast,+0.20) · adjust(saturation,−0.20) · look(mono) ]
```

### Clause semantics
| Signal | Examples | Effect |
|---|---|---|
| Direction | زد، ارفع، أكثر، أضف · more, increase, boost, lift · قلل، اخفض، خفف، أقل · less, reduce, lower, recover | sign of the change |
| Implicit direction | أدفأ/أبرد · warmer/cooler · أفتح/أغمق · brighter/darker · softer | the word itself carries the sign; "less warm" = −, "أقل دفئًا" = − |
| Light adjective steering another slider | "brighten the shadows", "افتح الظلال", "اغمق الحواف" | direction for the other slider, not an exposure change |
| Intensity | قليلًا، شوية، بسيط · a bit, slightly ⇒ ×0.5 · كثيرًا، جدًا · a lot, very ⇒ ×1.8 | scales the default step |
| Numbers | "+20", "٢٠٪", "exposure +1", "set contrast to 30", "vignette 30" | signed/with a verb ⇒ relative; bare ⇒ absolute; exposure numbers ≤ 5 are EV |
| Removal | أزل، احذف، امسح، بدون · remove, delete, erase, without, no | + background ⇒ remove background · + person ⇒ remove person · + this/object ⇒ eraser · + blemish ⇒ heal · + slider ⇒ reset it (haze ⇒ dehaze, colours ⇒ desaturate) · + filter ⇒ remove look |
| Nouns for AI tools | خلفية/background, شخص/person, بشرة/وجه/skin/face, عمق/bokeh/portrait mode, relight/spotlight | blur background, depth blur, relight, retouch, cut out person … |
| Inheritance | "increase contrast and saturation", "زد التباين والتشبع" | a clause with only a slider inherits the previous direction/intensity |

Default steps (slider units): exposure 0.35 EV, contrast 0.2, highlights/shadows 0.25, temperature 0.2, tint 0.15, vibrance 0.25, saturation 0.2, sharpen 0.3, clarity/structure/dehaze 0.25, vignette 0.3 (towards dark edges), grain 0.25.

Unknown fragments are reported back ("Didn't understand: …"), never guessed. `test/unit/smart_edit_intent_test.dart` holds 150+ Arabic and English phrases (dialects included) with their exact plans, and `test/benchmark/intent_benchmark_test.dart` runs the **1,070-command intent benchmark** (550 AR / 520 EN — slider templates × directions × intensities, looks, actions, compounds, chains, dialects and code-switching) at 100 % exact-plan accuracy; the v1.3.x acceptance bar is ≥ 95 % per language.

### Applying
`PhotoEditorController.applySmartPlan` applies sliders, looks, rotate/flip, auto-enhance, remove look and reset as **one undo step** and returns the actions that need a model or input (remove background, depth blur, relight, upscale, retouch, remove person, eraser, tap-to-select, heal). `runSmartAction` asks before downloading any model.

### Plan JSON (contract for any engine)
```json
{
  "ops": [
    {"op": "adjust", "param": "temperature", "amount": 0.2, "absolute": false},
    {"op": "look", "preset": "blockbuster", "intensity": 1.0},
    {"op": "action", "action": "removeBackground"}
  ],
  "unrecognized": ["frobnicate the widgets"]
}
```
`param` is an `AdjustmentParam` name, `preset` a built-in look id, `action` a `SmartAction` name. A future on-device LLM engine (e.g. Gemma-class model through LiteRT-LM) only needs to implement `EditIntentEngine.parse` and emit this JSON; the rule engine stays as the instant, offline fallback and as the validator (unknown params/actions are rejected by `EditOp.fromJson`).

## 2. Suggestions
`PhotoAnalysis.fromRgba` samples ≤ 65k pixels of a 256 px proxy: luminance histogram and clipping, gray-world colour cast, YCbCr skin tones (overall and centre), sky-like pixels in the top third, foliage, paper/ink ratios, histogram width. `suggestFixes` ranks 3–5 fixes; problem-specific fixes outrank the generic auto fix, creative looks fill the row. Suggestions are `Preset` deltas, so thumbnails come from the real GPU pipeline and applying one is a single undo step. These heuristics stay the always-available baseline; from v1.4 an **optional** scene classifier (MobileNetV2 int8, §3a) refines the ranking on top — pets, food, nature, city and plant tags add or boost suggestions the statistics cannot see (a dog portrait has no skin pixels but still gets the soft warm treatment). The classifier is never downloaded automatically; without it the ranking is byte-for-byte the statistics path.

## 3. Models added in 1.3 (all verified)
| Model | File | Size | SHA-256 | Licence | Measured* |
|---|---|---|---|---|---|
| MobileSAM image encoder | `Acly/MobileSAM@0d3b403/mobile_sam_image_encoder.onnx` | 28,157,093 B | `580f5fb6…c749` | Apache-2.0 | 1.9 s for a 1024×768 frame |
| SAM mask decoder (single mask) | `Acly/MobileSAM@0d3b403/sam_mask_decoder_single.onnx` | 16,501,323 B | `93915fc7…570d` | Apache-2.0 | 0.07–0.12 s per tap |
| SAM mask decoder (multi-candidate) | `Acly/MobileSAM@0d3b403/sam_mask_decoder_multi.onnx` | 16,496,559 B | `8976b90a…4ffe` | Apache-2.0 | used from 1.3.3 (same size/class as the single decoder) |
| Depth Anything V2 Small (int8) | `onnx-community/depth-anything-v2-small@4472b73/onnx/model_quantized.onnx` | 27,258,801 B | `fcf51f1b…f20d` | Apache-2.0 | 1.2 s at 518×518 |

\*ONNX Runtime 1.32 (Python) on a 2-core x86 sandbox CPU, single run; phone timings are tracked on the device farm (ROADMAP.md). Each file was downloaded, hashed, and run: a synthetic 120 px circle tapped at its centre gave a 44,850 px mask (expected ≈ 45,239), a 100×200 rectangle 19,842 px (expected 20,000); on a portrait the depth masks separated the person from the background cleanly.

I/O contracts:
* Encoder: `input_image` float `[H, W, 3]`, values 0..255, long side 1024 (the graph normalises and pads) → `image_embeddings [1,256,64,64]`.
* Decoder (single): `image_embeddings`, `point_coords [1,N+1,2]` in the 1024 frame, `point_labels [1,N+1]` (1 add, 0 subtract, −1 padding point), `mask_input [1,1,256,256]` zeros, `has_mask_input [1]` = 0, `orig_im_size [2]` = (h, w) → `masks [1,1,h,w]` logits (> 0 selected).
* Decoder (multi, used from 1.3.3): same inputs; a drag box is encoded as two corner points with labels 2 (top-left) and 3 (bottom-right); brush strokes become `mask_input` logits (+8 painted, −8 elsewhere, `has_mask_input` = 1) → `masks [1,4,h,w]` + `iou_predictions [1,4]` + `low_res_masks [1,4,256,256]`. The UI ranks candidates by IoU and lets the user switch; the chosen mask is feathered with a 2 px ramp before use.
* Depth: `pixel_values [1,3,h,w]` ImageNet-normalised, sides multiples of 14 → `predicted_depth [1,h,w]` relative inverse depth (larger = nearer), normalised with 2nd/98th percentiles.

## 3a. Model added in 1.4 (Unreleased — scene-aware suggestions)
| Model | File | Size | SHA-256 | Licence | Measured* |
|---|---|---|---|---|---|
| MobileNetV2 scene classifier (int8) | `onnx/models@4c46cd0/…/mobilenet/model/mobilenetv2-12-int8.onnx` | 3,655,033 B | `cc028fe6…f95f` | MIT (ONNX model zoo) | 2.4 ms per 224² frame |

Verified like every model: downloaded from the pinned zoo commit (immutable), hashed, and executed with ONNX Runtime. Semantic check: an ImageNet-normalised photo of a white fluffy cat returned white-fluffy-animal classes (Angora rabbit, West Highland terrier) in the top-5 while the same pixels without normalisation returned unrelated objects (wall clock, spotlight) — the preprocessing contract is the zoo's `[0..1] → ImageNet mean/std`. I/O contract: `input` float `[batch,3,224,224]` (RGB, ImageNet-normalised via `rgbaToNchw`), `output` float `[batch,1000]` ImageNet-1k logits; `SceneResult.fromLogits` softmaxes them and sums the mass of hand-curated class subsets into the pets/food/nature/city/vehicle/plant tags (`scene_tags.dart`).

## 4. Model mirrors (v1.3.x)

Every model carries a `mirrorUrl` pointing at release assets of this repository (tag `models-v1.3`). `ModelManager` downloads from the primary URL first and falls back to the mirror on any HTTP/network error or checksum mismatch — a broken third-party host only costs one extra request. `tool/sync_model_mirrors.py` downloads, SHA-256-verifies and publishes the mirrors (idempotent, `--check` mode verifies only).

## 5. Smart bar helpers (v1.3.x)

* **History & favourites** (`SmartCommandBook`, SharedPreferences): the last 12 commands and starred commands appear as chip rows; tap to run again, long-press to star.
* **Next commands** (`next_commands.dart`): after each applied plan the bar offers follow-ups mapped to real command phrases (remove a look, reverse a temperature change, sharpen after AI work…).
* **Dialect lexicon**: Gulf (وايد، حيل، كلش، زين), Egyptian (اوي، خالص، حلو), Levantine (مره، منيح، بشويش), Maghrebi (بزاف، برشا، مليح، باهي، دير) intensifiers and "make it nice" words join the MSA/English lexicon.
