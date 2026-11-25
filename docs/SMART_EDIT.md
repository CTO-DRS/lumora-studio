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
`PhotoAnalysis.fromRgba` samples ≤ 65k pixels of a 256 px proxy: luminance histogram and clipping, gray-world colour cast, YCbCr skin tones (overall and centre), sky-like pixels in the top third, foliage, paper/ink ratios, histogram width. `suggestFixes` ranks 3–5 fixes; problem-specific fixes outrank the generic auto fix, creative looks fill the row. Suggestions are `Preset` deltas, so thumbnails come from the real GPU pipeline and applying one is a single undo step. These are heuristics, not face/scene detection; v2.0 replaces them with a scene classifier and face landmarks (ROADMAP.md).

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

## 4. Model mirrors (v1.3.x)

Every model carries a `mirrorUrl` pointing at release assets of this repository (tag `models-v1.3`). `ModelManager` downloads from the primary URL first and falls back to the mirror on any HTTP/network error or checksum mismatch — a broken third-party host only costs one extra request. `tool/sync_model_mirrors.py` downloads, SHA-256-verifies and publishes the mirrors (idempotent, `--check` mode verifies only).

## 5. Smart bar helpers (v1.3.x)

* **History & favourites** (`SmartCommandBook`, SharedPreferences): the last 12 commands and starred commands appear as chip rows; tap to run again, long-press to star.
* **Next commands** (`next_commands.dart`): after each applied plan the bar offers follow-ups mapped to real command phrases (remove a look, reverse a temperature change, sharpen after AI work…).
* **Dialect lexicon**: Gulf (وايد، حيل، كلش، زين), Egyptian (اوي، خالص، حلو), Levantine (مره، منيح، بشويش), Maghrebi (بزاف، برشا، مليح، باهي، دير) intensifiers and "make it nice" words join the MSA/English lexicon.

## 6. Models added in 1.4 (faces, all verified)
| Model | File | Size | SHA-256 | Licence | Measured* |
|---|---|---|---|---|---|
| YuNet face detector (2023mar) | `opencv/face_detection_yunet@3cc26e7/face_detection_yunet_2023mar.onnx` | 232,589 B | `8f2383e4…2fa4` | MIT (OpenCV Zoo / libfacedetection) | ~20 ms per 640×640 frame |
| MediaPipe Face Landmarker (478-point mesh) | `senty-au/face_landmarks_detector-ONNX@337d582/onnx/model.onnx` | 4,920,995 B | `7d6e82de…8beeb` | Apache-2.0 (weights © Google, unchanged TFLite→ONNX conversion) | ~15 ms per face |

\*ONNX Runtime 1.32 (Python) on a 2-core x86 sandbox CPU; phone timings are tracked on the device farm. Verification: the YuNet decode was checked against the upstream reference implementation (empirically validated against `cv2.FaceDetectorYN`) and produces a 0.87-confidence box on a test portrait; the mesh reached presence 0.97 on the same portrait and correctly returned presence ≈ 0 on a face occluded by a camera. Together the pair costs 5.1 MB, inside the v1.4 budget of ≤ 15 MB.

I/O contracts and geometry:
* YuNet: `input` float `[1, 3, 640, 640]` BGR 0..255 (any photo resized to 640×640, boxes scaled back). Twelve raw outputs `cls_8/16/32 [1,N,1]`, `obj_8/16/32 [1,N,1]`, `bbox_8/16/32 [1,N,4]`, `kps_8/16/32 [1,N,10]` with N = 6400/1600/400 row-major grids. Decoding (`decodeYunet` in `face_pipeline.dart`): anchors at grid corners, centre = anchor + bbox[:2]·stride, w/h = exp(bbox[2:])·stride, keypoints = anchor + kps·stride, score = √(cls·obj) — the graph applies the sigmoids itself — then NMS (IoU 0.3), strongest first, ≤ 8 faces.
* Face Landmarker: `input_12` float `[1, 256, 256, 3]` NHWC RGB 0..1 — a square crop of side = the detection box (long side), centred on the box and rolled so the eye line is level (`alignedCrop`). Outputs: `Identity [1,1,1,1434]` = 478×(x,y,z) in crop pixels (0..256), mapped back to the raster with `cropToSource`; `Identity_1` presence **logit** (sigmoid > 0.5 keeps the face — occlusions such as a camera in front of the face score ≈ 0); `Identity_2` auxiliary, ignored.
* Masks (`buildFaceMask`): skin = the 36-point face oval minus the two 16-point eye rings, two 10-point brows and the 20-point outer lips; eyes = the eye rings dilated ×1.8; teeth = the 20-point inner-lip ring eroded ×0.8. Polygons are scanline-filled at ≤ 256 px and bilinearly stretched, giving soft edges like the other subject masks.
* Wiring: `FacePipeline.analyze` (cached per raster path) → `photoEditorController.faceAdjustment(region)` → one `LocalAdjustment` of kind `subject` with a generated mask PNG — editable, undoable, copy-safe like every other local adjustment. Smart actions `faceRetouch` / `eyeBrighten` / `teethWhiten`; tools `AiTool.faceRetouch` etc. download both models (5.1 MB) on demand.
