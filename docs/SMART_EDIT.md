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

Unknown fragments are reported back ("Didn't understand: …"), never guessed. `test/unit/smart_edit_intent_test.dart` holds the engine's contract phrases; `test/unit/smart_intent_benchmark_test.dart` is the v1.3.x release gate: 1,527 Arabic/English commands (MSA + Gulf/Egyptian/Levantine/Maghrebi dialects, numbers, code-switching) with exact expected plans — 100 % exact plans for both languages (gate ≥ 95 %).

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
`PhotoAnalysis.fromRgba` samples ≤ 65k pixels of a 256 px proxy: luminance histogram and clipping, gray-world colour cast, YCbCr skin tones (overall and centre), sky-like pixels in the top third, foliage, paper/ink ratios, histogram width. `suggestFixes` ranks 3–5 fixes; problem-specific fixes outrank the generic auto fix, creative looks fill the row. Suggestions are `Preset` deltas, so thumbnails come from the real GPU pipeline and applying one is a single undo step. These are heuristics, not face/scene detection; v2.0 replaces them with a scene classifier and face landmarks (ROADMAP.md).

## 3. Models added in 1.3 (all verified)
| Model | File | Size | SHA-256 | Licence | Measured* |
|---|---|---|---|---|---|
| MobileSAM image encoder | `Acly/MobileSAM@0d3b403/mobile_sam_image_encoder.onnx` | 28,157,093 B | `580f5fb6…c749` | Apache-2.0 | 1.9 s for a 1024×768 frame |
| SAM mask decoder (multi-mask, 1.3.x) | `Acly/MobileSAM@0d3b403/sam_mask_decoder_multi.onnx` | 16,496,559 B | `8976b90a…22ffe` | Apache-2.0 | 0.10–0.11 s per decode |
| Depth Anything V2 Small (int8) | `onnx-community/depth-anything-v2-small@4472b73/onnx/model_quantized.onnx` | 27,258,801 B | `fcf51f1b…f20d` | Apache-2.0 | 1.2 s at 518×518 |

Every file is also mirrored as a GitHub Release asset of this repository (`models-1.3`) with identical bytes; the app falls back to the mirror automatically when the primary URL fails (see `tool/mirror_models.dart` / `tool/mirror_models.py` and the `Mirror models` workflow).

\*ONNX Runtime 1.32 (Python) on a 2-core x86 sandbox CPU, single run; phone timings are tracked on the device farm (ROADMAP.md). Each file was downloaded, hashed, and run: a synthetic 120 px circle tapped at its centre gave a 44,850 px mask (expected ≈ 45,239), a 100×200 rectangle 19,842 px (expected 20,000); on a portrait the depth masks separated the person from the background cleanly.

I/O contracts:
* Encoder: `input_image` float `[H, W, 3]`, values 0..255, long side 1024 (the graph normalises and pads) → `image_embeddings [1,256,64,64]`.
* Decoder (multi-mask): same inputs as before — `image_embeddings`, `point_coords [1,N,2]` in the 1024 frame, `point_labels [1,N]` (1 add, 0 subtract, 2/3 box corners, −1 padding point when no box), `mask_input [1,1,256,256]` (zeros, or the painted refine strokes with `has_mask_input [1]` = 1), `orig_im_size [2]` = (h, w) → `masks [1,4,h,w]` logits (channel 0 = single-mask branch, 1..3 = the three candidates) + `iou_predictions [1,4]`. Verified with ONNX Runtime 1.32: point, box and mask-input prompts all decode in ≈ 100 ms on the 2-core x86 sandbox.
* Depth: `pixel_values [1,3,h,w]` ImageNet-normalised, sides multiples of 14 → `predicted_depth [1,h,w]` relative inverse depth (larger = nearer), normalised with 2nd/98th percentiles.

## 4. Models added in 1.4 (all verified)
| Model | File | Size | SHA-256 | Licence | Measured* |
|---|---|---|---|---|---|
| YuNet face detection (2023mar) | `opencv/opencv_zoo@48b10fa5/models/face_detection_yunet/face_detection_yunet_2023mar.onnx` | 232,589 B | `8f2383e4…2fa4` | Apache-2.0 (OpenCV Zoo) | ≈ 6 ms at 640×640 |
| MediaPipe Face Mesh (478 landmarks) | `senty-au/face_landmarks_detector-ONNX@337d5821/onnx/model.onnx` | 4,920,995 B | `7d6e82de…8beeb` | Apache-2.0 (Google MediaPipe) | ≈ 12 ms per 256×256 pass (2 passes per face) |
| SkySeg U²-Net (int8, project-built) | project release `models-1.4/skyseg_int8.onnx` | 44,247,982 B | `01c60b73…f2076` | Apache-2.0 (U²-Net / JianyuanWang/skyseg) | ≈ 290 ms at 320×320 |

The three files are mirrored on the project's `models-1.4` GitHub Release with identical bytes and SHA-256. SkySeg's fp32 weights (`JianyuanWang/skyseg@3ba8c6df`, 176 MB) are far too heavy for phones, so this project quantises them itself: static QOperator int8 (QUInt8 activations, QInt8 per-channel weights) calibrated on synthetic skies — IoU vs fp32 ≈ 0.99 on held-out scenes at ≈ 3× the speed (`scripts/quantize_skyseg.py`).

I/O contracts:
* **YuNet**: `input` float32 `[1,3,640,640]` **BGR 0..255** (static size — the pipeline letterboxes and maps back). Twelve raw outputs `cls_/obj_/bbox_/kps_{8,16,32}`; the Dart decode (anchors at grid corners, centre = anchor + bbox[:,:2]·stride, wh = exp(bbox[:,2:])·stride, kps = anchor + kps·stride, score = √(cls·obj), threshold 0.6, NMS IoU 0.3) was verified against `cv2.FaceDetectorYN` on real photos (`scripts/verify_yunet_decode.py`).
* **Face Mesh**: `input_12` float32 NHWC `[1,256,256,3]` RGB 0..1, an eyes-level aligned crop (two passes: YuNet eye keypoints → refine from the mesh's own bounding box, roll-aware bilinear sampling) → `Identity [1,1,1434]` = 478×(x,y,z) in crop pixels, `Identity_1` face-presence logit (sigmoid), `Identity_2` scalar. Landmark contours build **skin** (face oval − eyes − brows − lips, feathered), **eyes** (eye rings ×1.6) and **teeth** (inner lips ×0.9) masks (`scripts/verify_face_models.py`).
* **SkySeg**: `input.1` float32 `[1,3,320,320]` ImageNet-normalised RGB → first output `1959`: min–max normalise → soft sky matte (> 0.5 = sky), upsampled bilinearly to the source for feathered compositing (sky-only edits and sky replacement).
