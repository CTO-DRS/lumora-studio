# Lumora Studio — Roadmap · Wave 2: "Pro Intelligence" (v1.5)

> **Headline:** *The smartest photo & video editor that never needs the cloud.* Lumora understands what you ask for — in Arabic or English — and does it on your phone, privately, for free, with open-source code anyone can audit.
>
> النسخة العربية: [docs/ROADMAP.ar.md](docs/ROADMAP.ar.md)

Status legend: ✅ shipped · 🚧 partial / in progress · 🔜 planned · 🧪 research spike (may change)
Last updated: 2026-11-25 (v1.4.0 released). Dates are targets, not promises; quality gates decide releases.

---

## 1. Where we stand (closed waves)

Wave 1 — **v1.3 "Smart" + v1.3.3 polish** ✅ — typed AR/EN commands → one-step edit plans at 100 % exact-plan accuracy (1,070 commands), suggestions, tap-to-select (MobileSAM multi-mask, box prompt, brush refine, feather), depth blur & relight, remove person, dialect lexicon (Gulf / Egyptian / Levantine / Maghrebi), model mirrors.

Wave 1b — **v1.4.0 "Pro foundations"** ✅ (this release, 2026-11-25) —
- **Faces:** skin-only retouch, eye brighten, teeth whiten via YuNet + 478-point MediaPipe landmarks (5.1 MB, ≤ 60 ms per face).
- **Sky & scene:** in-house int8 U²-Net sky segmentation (44.2 MB, ~305 ms at 320², IoU ≈ 0.93), deepen-sky + sky replacement (4 procedural gradients), MobileNetV2 scene classifier (3.5 MB) boosting Smart suggestions.
- **Video foundations:** audio waveform + energy-flux beat detection & snap-to-beats (pure Dart DSP, no model).
- **Crop:** Hough-based auto-straighten (pure Dart, ~2 ms).
- **Pro infra:** in-house static-int8 quantisation pipeline (`tool/quantize_skyseg.py`), project-hosted model mirrors (tag `models-v1.4`), privacy policy (AR/EN), 1,128-command intent benchmark at 100 %.

## 2. Vision for Wave 2

Every pro feature that remains cloud-only in 2026 — RAW processing, auto-captions, professional low-light rescue, studio-grade face retouching — ships behind subscriptions, credits and uploads. Lumora's Wave 2 answers with one idea: **make the phone's own silicon do the pro work.** The new LiteRT/NPU engine turns every future model into a hardware-accelerated, battery-friendly inference that respects the 100 % on-device promise; the RAW/DNG pipeline removes the 8-bit ceiling between Lumora and real cameras; Whisper captions make AR/EN video publishing accessible on a plane; face parsing and low-light rescue close the last two honest gaps named in the v1.3 competitive table.

Wave 2 = **v1.5 "Pro Intelligence"** (target: 2027 Q1–Q2), five workstreams, one shared runtime foundation.

## 3. Wave 2 workstreams

### W1 · LiteRT/NPU runtime 🚧 *starts now (first item of the wave)*

| | |
|---|---|
| **Goal** | Every model runs on the fastest engine the device offers — NPU where present, GPU fallback, CPU floor — with zero behaviour change for users and zero crash regressions. |
| **Scope** | Unified `InferenceEngine` abstraction behind the existing ONNX engine: `lite_rt_engine.dart` (tflite_flutter) with **NPU delegate (QNN / NNAPI per SoC)** → **GPU delegate** → **XNNPACK CPU** fallback chain; per-SoC allow-list & crash-guarded auto-fallback (a delegate that crashes once is blacklisted for the session); engine + delegate chosen per model in the registry; models may ship in dual format (`.onnx` for ONNX/CPU, `.tflite` for LiteRT) with one contract; latency + memory telemetry stays local (Settings › Diagnostics) and is exportable by the user. |
| **Models / tech** | `tflite_flutter` (LiteRT), LiteRT GPU delegate, NNAPI/QNN NPU delegates, SoC allow-list (Snapdragon 8-series with QNN, Tensor, Apple ANE via Core ML path on iOS 🧪). |
| **Targets** | MobileSAM encode ≥ 2× faster on NPU flagships vs CPU ONNX; scene classifier ≤ 5 ms on GPU path; sky 320² ≤ 150 ms on NPU; no native crash regressions on the farm (crash-free ≥ 99.8 %); CPU-only devices keep today's behaviour bit-for-bit. |
| **Acceptance** | `flutter analyze` clean; unit tests for delegate selection + fallback + blacklist; farm matrix (≥ 12 devices) green with auto-fallback proven on a deliberately broken delegate; benchmark table (engine × delegate × model) published per release. |

### W2 · RAW/DNG 16-bit pipeline 🚧 *M2-1…M2-4 shipped (decode + camera colour)*

| | |
|---|---|
| **Goal** | Open real camera files (DNG/RAW) without the 8-bit JPEG ceiling: 16-bit decode → 16-bit internal pipeline → tonemap at export. |
| **Scope** | DNG/TIFF-based decode (lossless JPEG + deflate + uncompressed), embedded thumbnail/preview fast path for instant display, 16-bit float internal buffers end-to-end (shaders + masks + LUTs), highlight recovery from linear data, camera-neutral → sRGB/Display-P3 tonemapping with adjustable shadow/highlight rolloff, export as 16-bit TIFF / JPEG / HEIC, tiled processing for ≥ 24 MP files. |
| **Models / tech** | Dart/Rust DNG decoder 🧪 (libraw-class semantics, MIT/Apache parts only), existing GLSL pipeline extended to RGBA16F. |
| **Targets** | Open a 24 MP DNG ≤ 2 s (preview-first < 300 ms); peak memory ≤ 900 MB for 24 MP 16-bit; no regression for 8-bit photos (same shaders, one code path). |
| **Acceptance** | Decoder fuzz-tested on malformed DNGs (crash-free); colour accuracy vs reference decode (ΔE ≤ 2 on a calibration set); golden tests for 16-bit shader path. |
| **Shipped — M2-1 (2026-11-25)** | In-house pure-Dart DNG open path: fuzz-safe TIFF/IFD parser → DNG document layer (CFA metadata, ActiveArea, black/white levels, embedded previews, compression classification) → strip decoder (uncompressed + Adobe-deflate, 8/12/14/16-bit-in-16) → bilinear demosaic → sRGB 8-bit PNG handed to the normal editor pipeline; lossless-JPEG raw payloads fall back honestly to the largest embedded preview with the reason surfaced in AR/EN UI; the picker accepts `.dng`/`.tif` next to everyday images. 17 new tests (structure fuzz gates, strip bounds, ActiveArea crop, deflate round-trip, preview fallback, honest failures). **M2-2 (same day): lossless-JPEG (SOF3) strips are now decoded too** — an in-house ITU-T T.81 decoder (Huffman + predictor lattice 1-7, 8/16-bit precision, point transform Pt, restart intervals DRI/RSTn, category-16 escape, byte stuffing, bounded loops and an MCU hang-guard) wired into `decodeCfa` per strip with width/height/precision validation, so **phone DNGs — the majority in the wild — now decode their real sensor data** instead of falling back to the preview; any genuinely broken payload still falls back honestly. 7 more tests with a fixture-side SOF3 encoder (predictor 1/5 round-trips, 8-bit, DRI+RSTn, multi-strip, truncation fuzz). **M2-3 (same day): 16-bit TIFF export** — a spec-correct pure-Dast TIFF writer (little-endian classic IFD, RGB uint16 strips capped at ~1 MB, the TIFF inline rule honoured, v·257 channel lift so 0xFF→65535 exactly) wired into the export sheet as a new "TIF" format beside JPEG/PNG/WebP/HEIC — the first export path that carries more than 8 bits per channel. 3 more tests (parser round-trip, multi-strip readability, range-exact lift) — **524 green, `flutter analyze` clean**. Two real bugs caught and fixed by the tests before they could ship: the zero-ActiveArea sentinel crashed the decoder, and the preview fallback was unreachable behind an over-eager parse-time rejection. **M2-4 (same day): camera-neutral colour + highlight recovery** — raw files no longer render with a colour cast. `colour_render.dart` implements the DNG-spec colour pipeline in pure Dart: white balance through `AsShotNeutral` (normalised so the shot's neutral maps to `[1,1,1]` in camera space), `ColorMatrix1` inverted and Y-normalised into a camera→XYZ matrix, **Bradford chromatic adaptation from the shot illuminant to D65**, then XYZ→linear-sRGB — achromatic scene colours land exactly on the sRGB white (verified: the camera's D65-white response renders 255/255/255 end-to-end). Between matrix and gamma, a **highlight-recovery shoulder** runs on the linear data: pixels above 0.95 take a quadratic shoulder (never overshooting 1) blended toward their Rec.709 luminance in proportion to clip depth, so blown channels lose their magenta/green fringes instead of hard-clipping; the clipped-pixel fraction is returned for diagnostics. The colour tags were unreachable before: the TIFF parser read **SRATIONAL numerators unsigned** — a real bug fixed in this milestone (every negative ColorMatrix coefficient came back as ~4e9). Files without colour metadata keep the legacy identity path bit-for-bit; singular matrices and degenerate neutrals degrade gracefully (fuzz gate). 17 new tests (matrix round-trips, white→white, grey invariance, SRATIONAL sign through a byte-built DNG, end-to-end white/hue/identity renders, recovery bounds and monotonicity) — **541 green, `flutter analyze` clean**. |

### W3 · Whisper auto-captions (AR/EN, offline) 🚧 *W3-M1…M5 shipped (infrastructure, captioning job, audio front end, token/decoder layer, transcriber + ONNX binding)*

| | |
|---|---|
| **Goal** | One-tap auto-captions for video — Arabic and English — running entirely on-device, styled like the text tool, exported burned-in or as SRT/VTT sidecar. |
| **Scope** | Whisper tiny/base int8 via ONNX Runtime first (shares W1's engine later), encoder-decoder with cached KV, 30 s window sliding over the audio track (reuses the v1.4 FFmpeg PCM decode path), AR/EN language auto-detect, word-level timestamps for karaoke-style styling, subtitle track UI on the timeline (drag, restyle, re-time), SRT/VTT export, dialect-tolerant post-processing (tatweel/alef normalisation) with an AR quality pass. |
| **Models / tech** | Whisper tiny (~39 M params; int8 ≈ 40 MB) first, base optional; MIT/Apache weights only; model registry contract + mirrors as usual. |
| **Targets** | ≥ 1× real-time on the reference phone (tiny int8); ≤ 2 GB peak RAM; AR word error rate on a held-out dialect set ≤ 18 % (tiny) / ≤ 12 % (base); captions never block editing (background job, cancellable). |
| **Acceptance** | Unit benchmark on synthetic + real samples; timeline subtitle UI widget tests; AR shaping correct (no broken ligatures) verified by golden tests. |
| **Shipped — W3-M1 (2026-11-25)** | Subtitle infrastructure, the data layer the ASR model will write into: `subtitles.dart` with **SubtitleCue / SubtitleTrack** (sorted cues, per-word timings for later karaoke styling, JSON round-trip for project files), **spec-correct SRT + WebVTT writers and strict bounded parsers** (comma vs dot clocks, hours ≥ 100 safe, NOTE/identifier blocks tolerated, ≤ 50k lines/cues and ≤ 5k chars per cue — malformed input raises `SubtitleFormatException`, never crashes or hangs; files truncated mid-write open with everything read so far, total garbage raises), **track sanitisation** (invalid cues dropped, overlaps truncated earlier-yields, times clamped to the video duration, captions cleaned + wrapped automatically) and the **dialect-tolerant Arabic pass** (tatweel strip, opt-in alef folding for ASR-text comparison, punctuation spacing repair, word-boundary line wrapping where every line is hard-bounded ≤ max chars — never breaks inside a word). 22 new tests (model + JSON round-trips, SRT/VTT round-trips, fuzz gates incl. a >50k-cue bounded error and truncated-file tolerance, sanitisation policies, AR shaping) — **563 green, `flutter analyze` clean**. The tests caught three real bugs before ship: `replaceAll` does not interpolate `$1` backreferences (literal `$1` leaked into captions), the line wrapper never emptied its buffer on flush (a 633-char runaway line), and the cue cap truncated silently instead of raising. **W3-M2 (same day): the captioning job pipeline** — `captioning.dart` turns decoded PCM into a timeline-safe `SubtitleTrack` through a pluggable `AutoTranscriber` seam (the real Whisper transcriber implements the same contract in the next W3 milestone — no call site changes). **30 s windows** slide over the audio the v1.4 FFmpeg path already decodes (any sample rate; a sub-second tail folds into the previous window instead of a sliver), a sequential background **`CaptionJob`** reports progress per window, is **cancellable between windows with partial results kept**, records transcriber failures as honest partial results instead of losing everything, shifts segment times to absolute timeline times and assembles the final track through W3-M1 sanitisation. 12 new tests (windowing coverage/contiguity/fold, job assembly, progress, cancellation, failure paths, overlap truncation) — **575 green, `flutter analyze` clean**. **W3-M3: Whisper audio front end** — `whisper_frontend.dart` (resample to 16 kHz, 30 s pad/trim, mixed-radix FFT, Slaney mel filterbank, 80x3000 log-mel with the reference normalisation), 13 tests, **588 green, `flutter analyze` clean**. **W3-M4: token layer + greedy decoder** (`whisper_decoding.dart`, 17 tests). **W3-M5: transcriber + ONNX binding** (`whisper_transcriber.dart`, `onnx_whisper_runtime.dart`, `ModelRegistry.speech`; real-clip transcription verified with desktop ONNX Runtime). Next: W3-M6 timeline UI (caption button, progress, subtitle track editing, SRT/VTT export) and the `models-v1.5` mirror. | |

### W4 · Face segmentation (parsing) 🔜

| | |
|---|---|
| **Goal** | Go from landmark-built masks to a real per-pixel face parse: skin, brows, eyes (l/r), glasses, lips, teeth, hair, background — enabling studio retouch that never leaks. |
| **Scope** | Face parsing model (BiSeNet-class CelebAMask-HQ 19-class, licence-clean weights only 🧪 — NC weights rejected by policy), runs per detected face crop (reuses YuNet from v1.4), class-id → semantic masks, replaces landmark-built skin/eye/teeth masks where parsing is confident (hybrid: landmarks gate, parsing refines), new tools: brows enhance, glasses glare reduce, lips colour (HSL through lip mask), hair colour tint, per-class strength sliders, all as editable local adjustments. |
| **Models / tech** | Face parsing int8 (≤ 10 MB budget, 512² crop inference), existing face pipeline as host. |
| **Targets** | ≤ 120 ms per face at 512² on reference phone (≤ 400 ms CPU floor); class IoU on held-out portraits: skin ≥ 0.85, lips ≥ 0.8, hair ≥ 0.8; masks never write outside the face crop's upscale region. |
| **Acceptance** | Benchmark set with pixel masks (IoU table published); new Smart commands AR/EN ("صبغ الشعر", "أحمر الشفاه", "tint my hair", "lip colour"…) added to the intent benchmark at 100 %; hybrid gating unit tests. |

### W5 · Low-light rescue 🔜

| | |
|---|---|
| **Goal** | Lift dark, noisy, hand-held night shots to shareable quality — denoise, brightness, colour noise, all on-device and editable. |
| **Scope** | Zero-DCE++-class exposure curve estimation (tiny, ~10k params, no training data leakage worries — MIT) for the lift, NAFNet-lite / SCUNet-class int8 denoiser 🧪 (≤ 25 MB) for grain, chroma-noise suppression on the CbCr planes, luminance-weighted denoise (stronger in shadows), integration as a one-step Smart action + manual panel (strength, preserve detail, colour noise), auto-suggestion when photo statistics say "underexposed" (mean < threshold + histogram), RAW integration with W2 (denoise linear before tonemap). |
| **Models / tech** | Zero-DCE++ (MIT), NAFNet-lite int8 (licence-checked), tiled inference for 12 MP ≤ 1.5 s. |
| **Targets** | ≤ 1.5 s at 12 MP tiled on reference phone; +SSIM/PSNR on an internal low-light set published per release; artifacts gate — no colour casts (ΔE drift ≤ 3). |
| **Acceptance** | Before/after benchmark set; regression alarm at −15 % quality; Smart command AR/EN ("حسّن الصورة الليلية", "قلل الضجيج", "fix this dark photo", "denoise"…) at 100 % benchmark. |

## 4. Delivery order & milestones

| Milestone | Content | Gate |
|---|---|---|
| **M1 — Runtime foundation** 🚧 | W1 LiteRT/NPU engine + delegate fallback + benchmarks | farm green, no crash regressions |
| **M2 — Pro imaging** | W2 RAW/DNG pipeline (decode → 16-bit → export) | fuzz + colour accuracy gates |
| **M3 — Video language** | W3 Whisper AR/EN captions | WER targets + UI golden tests |
| **M4 — Studio retouch** | W4 face parsing + new retouch tools | IoU table + benchmark 100 % |
| **M5 — Night** | W5 low-light rescue (+RAW integration) | SSIM/PSNR + artifact gates |
| **M6 — v1.5.0 release** | farm matrix, benchmark tables, store builds, mirrors `models-v1.5` | all gates green |

M1 ships first because every later workstream inherits its speed. W2/W3 can run in parallel once M1 lands; W4 lands on the v1.4 face host; W5 last (depends on M2 for the linear-data path).

## 5. Performance budgets (v1.5, reference phone)

| Metric | Budget |
|---|---|
| Cold start to Home | ≤ 1.2 s (low-end ≤ 2.5 s) |
| Open photo → first render | ≤ 600 ms (12 MP); RAW preview-first ≤ 300 ms |
| Slider → frame (2048 px proxy) | ≤ 16 ms (60 fps), never > 33 ms |
| Smart command (rule engine) | ≤ 10 ms parse |
| MobileSAM encode | ≤ 1.2 s NPU / ≤ 2.5 s CPU |
| Sky 320² | ≤ 150 ms NPU / ≤ 1 s CPU int8 |
| Face parse 512² | ≤ 120 ms NPU / ≤ 400 ms CPU |
| Whisper captions (tiny int8) | ≥ 1× real-time |
| Low-light 12 MP | ≤ 1.5 s tiled |
| Peak memory | ≤ 1.2 GB (low-end ≤ 900 MB, one model at a time) |
| Model downloads | each ≤ 50 MB; Whisper tiny ≈ 40 MB; face parse ≤ 10 MB |
| Battery | ≤ 3 % per 10-minute session with two AI steps |

## 6. Quality gates (unchanged principles, raised bar)

- Intent benchmark grows with every workstream (captions, hair/lips commands, night commands) — **≥ 100 % exact plans** before release, AR & EN separately.
- Every new model: pinned URL + SHA-256, licence check (no NC weights), measured latency + memory published in `docs/SMART_EDIT.md`, project mirror on `models-v1.5`.
- Farm matrix ≥ 12 devices (3 tiers × 2 OS × 2 vendors), crash-free ≥ 99.8 %, thermal trace on the 10-minute session.
- Fuzzing: DNG decoder, SRT/VTT writers, subtitle JSON; golden tests for 16-bit shaders and subtitle styling.

## 7. Risks & mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| NPU delegates crash on some SoCs/drivers | native kill | CPU default stays; per-SoC allow-list; crash-guarded auto-fallback with session blacklist; farm matrix |
| Face-parsing weights licensing | legal | licence gate in registry review; ship only permissive weights; fallback = landmark-built masks (v1.4 path) |
| Whisper Arabic dialects | wrong text | dialect-tolerant post-pass; benchmark on held-out dialect set; base model opt-in |
| DNG variants (compressed/sensor-specific) | open failures | format support matrix published; graceful "unsupported RAW" message; preview-first fallback |
| 16-bit memory blow-up | OOM | tiled processing, RGBA16F proxies, memory caps preserved |
| Dual-format model maintenance | repo bloat | one registry contract; tflite added per-model only where the delegate wins on the farm |

## 8. What stays fixed

100 % on-device · no accounts, no analytics, no ads · MIT code + open model licences only · every smart action stays an editable, undoable recipe · Arabic-first with full RTL · graceful CPU floor on every phone · optional models only, never auto-downloaded · local diagnostics, shared only by the user.
