# Lumora Studio — World Roadmap · خارطة الطريق

> **Headline:** *The smartest photo & video editor that never needs the cloud.* Lumora understands what you ask for — in Arabic or English — and does it on your phone, privately, for free, with open-source code anyone can audit.
>
> Arabic version: [docs/ROADMAP.ar.md](docs/ROADMAP.ar.md) · One-page vision: [docs/VISION.md](docs/VISION.md)

Status legend: ✅ shipped · 🚧 partial / in progress · 🔜 planned · 🧪 research spike (may change)
Last updated: 2026-11-24 (v1.3.3). Dates are targets, not promises; quality gates decide releases.

---

## 1. Vision

Every big editor in 2026 is racing to add "describe your edit" AI: Lightroom's AI Assistant (early access, Nov 2026), Google Photos "Help me edit" (Gemini), Samsung Photo Assist on the Galaxy S26. All of them send your photo to a server for the generative part, need an account, are limited by region/language (Google's needs US English and 18+), add watermarks (Samsung), or meter usage with credits (Picsart, Photoroom, CapCut, Lightroom generative credits).

Lumora's bet is the opposite: **the best intelligence is the one that runs where your photos live.** By v2.0 Lumora should be the editor where you can say *"اجعل السماء أكثر زرقة وأزل السائح على اليسار ثم أعطها طابعًا سينمائيًا"* on a plane with no signal and get a professional result in seconds — with every step editable, undoable and explainable.

## 2. Guiding principles

1. **100 % on-device.** No image, video, audio or prompt ever leaves the device. The only network traffic is optional model downloads from pinned URLs, verified with SHA-256.
2. **Private by construction, not by policy.** No accounts, no analytics, no ads, no fingerprinting. Diagnostics stay local (Settings › Error log) and are shared only by the user.
3. **Fast and honest.** Real-time GPU preview; AI steps show progress and can be cancelled; failures are explained in plain words. We publish what each model is, its size, licence and measured latency.
4. **Non-destructive and explainable.** Every smart action becomes ordinary, editable edits (sliders, masks, looks) — never an opaque new image when it can be avoided.
5. **Arabic-first, world-ready.** Arabic is a first-class language for UI *and* commands (dialects included), with full RTL; then 30+ languages.
6. **Open.** MIT code, open model licences only (no non-commercial weights in shipped builds), reproducible builds, documented contracts so anyone can add engines, models, presets and plug-ins.
7. **Graceful on every phone.** CPU-safe defaults, accelerated paths opt-in per device, memory caps, small model packs, nothing required to download for the core editor.

## 3. Where we stand (v1.0 → v1.3)

| Area | Shipped |
|---|---|
| GPU photo pipeline | ✅ GLSL shaders for light/colour/HSL/curves/detail/effects, `.cube` LUTs, tiled full-resolution export, histogram & clipping, history |
| Looks | ✅ 45 looks in 9 categories with live thumbnails, favourites, user presets (import/export), copy/paste edits |
| Local & retouch | ✅ brush/linear/radial/subject masks, healing & clone (model-free), selective colour |
| AI (ONNX Runtime) | ✅ background removal (U²-Net-p), portrait matting (MODNet), eraser (MI-GAN / LaMa), 4× upscale (Real-ESRGAN), safe CPU defaults, verified downloads |
| **Smart (v1.3)** | ✅ **typed commands in Arabic & English** → one-step edit plan · ✅ **suggestions for this photo** · ✅ **tap to select** (MobileSAM) → erase / cut out / adjust / blur rest · ✅ **depth blur & relight** (Depth Anything V2) · ✅ **remove person** |
| **Smart polish (v1.3.3)** | ✅ **command history & favourites** + next-command suggestions after each edit · ✅ **dialect lexicon** (Gulf/Egyptian/Levantine/Maghrebi) · ✅ **1,070-command AR/EN intent benchmark** at 100 % exact plans · ✅ tap-to-select **multi-mask candidates** (IoU-ranked), **box prompt**, **brush refine**, **feathered edges** · ✅ **project-hosted model mirrors** with automatic fallback |
| Documents, batch, collage | ✅ scanner with PDF, batch edit, collage maker |
| Video | ✅ timeline, transitions, speed/reverse, crop, stabilisation, filter keyframes, music, text (Arabic shaping), GIF, fast & studio export |
| Platform | ✅ Android APKs per ABI, unsigned iOS build, glass design system, AR/EN + RTL, tablets layouts, CI + release workflows |
| Known gaps | 🚧 1:1 loupe shows the 2048 px proxy · 🚧 retouch uses a person matte, not face landmarks · 🚧 suggestions use image statistics, not a scene model · 🚧 keyframes animate look strength only · 🚧 iOS builds unsigned |

## 4. Competitive landscape (November 2026)

Legend: ✅ yes · ☁️ yes, but needs the cloud/account · ~ partial or limited · — no

| App | On-device AI | Works offline | Natural-language edit | Arabic commands | Tap-to-select | Generative fill | Video editing | Open source | Price model |
|---|---|---|---|---|---|---|---|---|---|
| **Lumora 1.3** | ✅ all | ✅ | ✅ (rule engine, AR/EN) | ✅ | ✅ MobileSAM | ~ eraser (MI-GAN/LaMa), no gen-fill yet | ✅ | ✅ MIT | free, no account |
| Lightroom Mobile 12 | ~ masks/quick actions | ~ | ☁️ AI Assistant (early access) | — | ✅ | ☁️ Generative Remove/Expand (credits) | ~ basic | — | subscription + generative credits |
| Snapseed 4 | ✅ (Object Brush on-device) | ✅ | — | — | ~ object brush | — | — | — | free |
| Google Photos | ~ | ~ | ☁️ "Help me edit" (Gemini; US English, 18+) | — | ✅ | ☁️ Magic Editor | ~ | — | free / Google One |
| Samsung Gallery (Photo Assist) | ~ some on-device | ~ | ☁️ natural language (S26) | ~ | ✅ | ☁️ Generative Edit (watermark, ≤ 12 MP) | ~ | — | bundled, Samsung account |
| Apple Photos (Clean Up) | ✅ Apple Intelligence devices only | ✅ | — | — | ~ | ~ Clean Up / Extend | ~ | — | bundled |
| Pixelmator Pro (iPad/Mac) · Photomator | ~ | ✅ | — | — | ✅ | ~ Generate Fill (5.0) | — | — | Creator Studio $12.99/mo or one-time (Mac) · Photomator stalled since 3.4 |
| Picsart | ☁️ | — | ~ agents | ~ | ✅ | ☁️ | ✅ | — | Pro + monthly AI credits |
| Photoroom | ☁️ | — | — | — | ✅ | ☁️ AI backgrounds | ~ | — | Pro/Max/Ultra + credits |
| VSCO | ~ | ✅ | — | — | — | — | ~ | — | VSCO Pro $60/yr |
| Meitu / Wink | ☁️ | — | — | — | ✅ | ☁️ | ✅ (enhance, interpolation) | — | VIP subscription |
| CapCut | ☁️ | ~ | ☁️ | ~ | ✅ | ☁️ | ✅ | — | Pro $19.99/mo + credits |
| InShot | ~ | ✅ | — | — | ~ cutout | — | ✅ (auto captions, auto beat) | — | ads / Pro / lifetime |
| VN | ~ (local caption models) | ✅ | ~ AI Edit (cloud) | — | ~ | ☁️ | ✅ (43-language captions) | — | free + Pro + credit packs |
| Remini | ☁️ | — | — | — | — | ☁️ | ~ enhance | — | weekly subscription |

**What no competitor combines:** on-device natural-language editing *in Arabic*, open source, offline, no account, no watermark, no credits — and every result stays an editable recipe. **Where we are behind (honestly):** generative fill/expand, face-aware retouch (open eyes, blemish detection), RAW, cloud-scale enhance for old videos, polish of trend templates, signed store builds.

Sources are listed in §16.

## 5. Phased plan

Each phase has themes, features, models (with size/latency targets on a **mid-range reference phone** — Snapdragon 7-class / Dimensity 7000-class / iPhone 13-class — and a **low-end floor**: 4 GB RAM Android), and acceptance criteria. A phase ships when its criteria pass on the device farm.

### v1.3 — "Smart" ✅ (this release, 2026-11)
- ✅ Typed commands AR/EN → `SmartEditPlan` (one undo step), JSON contract for future engines.
- ✅ Suggestions (statistics-based) with live thumbnails.
- ✅ Tap to select: MobileSAM encoder 28.2 MB + decoder 16.5 MB; measured 1.9 s encode / ≤ 0.12 s per tap on a 2-core x86 sandbox.
- ✅ Depth blur & relight: Depth Anything V2 Small int8 27.3 MB; 1.2 s at 518² on the same sandbox.
- ✅ Remove person (MODNet + MI-GAN); iOS build no longer depends on `download.onnxruntime.ai`.
- Acceptance met: `flutter analyze` clean; 350+ tests green incl. 140+ AR/EN command phrases; models SHA-256 verified and executed before shipping.

### v1.3.x — polish ✅ (features shipped 2026-11, v1.3.3)
- ✅ Home "AI tools" sheet & quick actions for the new tools; Smart bar suggestions of *next* commands after each edit.
- ✅ Command history & favourites; dialect lexicon pass (Gulf, Egyptian, Levantine, Maghrebi).
- ✅ 1,070-phrase intent benchmark (550 AR / 520 EN): slider templates × directions × intensities, looks, actions, compounds, chains, dialects, code-switching — measured in CI.
- ✅ Tap-to-select: multi-mask decoder (up to 4 IoU-ranked candidates, chips to switch), box prompt, brush refine (SAM `mask_input`), feathered edges (2 px ramp).
- ✅ Mirror of every model on a project-controlled host (GitHub Releases of this repo, tag `models-v1.3`) with identical SHA-256 as an automatic fallback (`tool/sync_model_mirrors.py`).
- **Acceptance:** intent benchmark **100 %** exact plans (AR & EN separately; bar ≥ 95 %) ✅ · select-tap p95 ≤ 150 ms on the reference phone 🚧 (needs the device farm; sandbox-verified 0.07–0.12 s per decode).

### v1.4 — "Pro foundations" (2027 Q1)
| Theme | Features | Models / tech | Targets |
|---|---|---|---|
| Faces | skin-only retouch, eye brighten, teeth whiten, face-aware suggestions, blemish detection | face detection + 468-point landmarks (MediaPipe-class, ONNX/LiteRT), face parsing (BiSeNet-class, ~50 MB fp16 → int8) | ≤ 15 MB total int8; ≤ 60 ms per face |
| Sky & scene | sky replacement & sky-only edits; scene classifier for suggestions | sky segmentation (U²-Net-p fine-tune or SAM prompt), MobileNetV3-class scene classifier (~5 MB) | ≤ 300 ms per photo |
| Low light | denoise & low-light lift | Zero-DCE++-class curve estimation (tiny, ~10k params) + NAFNet-lite denoise 🧪 | ≤ 1.5 s at 12 MP tiled |
| Runtime | **LiteRT backend** with NPU/GPU delegates; ONNX stays; per-SoC allow-list | `tflite_flutter`/LiteRT, Core ML on iOS | ≥ 2× faster encode on NPU devices; no native crash regressions |
| Pro | RAW/DNG 16-bit pipeline, true full-res loupe, auto-straighten (horizon), perspective auto | Dart/Rust DNG decode 🧪, Hough-based horizon | open 24 MP DNG ≤ 2 s |
| Video | **auto-captions AR/EN** (offline), waveform, **beat detection & snap** | Whisper tiny (~39 M params; ~40 MB int8) / base (~74 M) via whisper.cpp or ONNX; onset/BPM DSP (no model) | captions ≥ 1× real-time on reference phone |
- **Acceptance:** device-farm integration tests run every model on ≥ 12 devices (3 tiers × 2 OS × 2 vendors); crash-free rate on farm ≥ 99.8 %; no model > 50 MB in this phase.

### v1.5 — "Semantic" (2027 Q2)
- 🔜 **Smart search & auto-tags** across projects (on-device CLIP-class embeddings with open weights; ~90–150 MB fp16 → int8 target ≤ 60 MB); search in Arabic & English ("صور البحر عند الغروب").
- 🔜 Best-shot & duplicate culling; burst picking; blur/closed-eyes flags.
- 🔜 Face restoration for old photos (GFPGAN-class, permissive licence only), colourisation 🧪.
- 🔜 **Generative fill (opt-in, large download)**: quantised small diffusion or MI-GAN++ inpainting with prompt 🧪; strict size gate (≤ 1 GB, opt-in, Wi-Fi only).
- 🔜 Batch smart: apply a command to 100 photos ("make all of these warmer and crop to 4:5").
- **Acceptance:** search top-5 recall ≥ 85 % on an internal 2k-photo set; gen-fill gated behind explicit opt-in with clear size/time.

### v2.0 — "Lumora Intelligence" (2027 H2)
| Theme | Features | Models / tech | Targets |
|---|---|---|---|
| Language | **on-device LLM/VLM engine** for free-form, multi-turn edits ("a bit more… no, only the sky"); explains what it did; rule engine stays as instant fallback & validator | Gemma-4-E2B-class via **LiteRT-LM** (2.58 GB; Google reports 47 tok/s CPU / 52 tok/s GPU decode on Galaxy S26 Ultra) or smaller (Qwen3-0.6B / SmolVLM-class) for mid-range; optional download | plan JSON in ≤ 2 s on flagships; never required |
| Grounding | "remove the person on the left", "make the jacket red": text → region via VLM + SAM points | VLM + MobileSAM / SAM2-tiny 🧪 | correct region ≥ 80 % on benchmark |
| Reference looks | "edit like this photo": colour transfer to an editable LUT + sliders | analytic colour transfer + small regressor 🧪 | ≤ 1 s |
| Video AI | **video background matting** (RVM-class, MobileNetV3 backbone ~15 MB), **frame interpolation / slow-mo** (RIFE-class ~10–20 MB), object-tracked masks, auto-edit to the beat | ONNX/LiteRT, FFmpeg | RVM ≥ 15 fps 720p on reference phone; RIFE 2× at 720p ≥ 10 fps export |
| Platforms | tablets first-class (side panels, pencil), **desktop** (macOS / Windows / Linux) | Flutter desktop, ORT desktop | feature parity for photo |
| Ecosystem | **preset/LUT marketplace v1**, plug-in SDK preview | signed packages | — |
- **Acceptance:** an LLM-free install remains fully functional; LLM pack opt-in with measured RAM ≤ 1.8 GB peak; all smart actions remain undoable recipes.

### v3.0 — "Studio everywhere" (2028)
- 🔜 **Web** build (Flutter web + ONNX Runtime Web/WebGPU) — still local-only processing in the browser.
- 🔜 Local-first sync between your own devices (LAN / user-chosen storage, end-to-end encrypted, no Lumora server).
- 🔜 Plug-in SDK 1.0: shaders, LUT packs, models with manifests, signatures and sandboxing; community gallery.
- 🔜 Voice-first, hands-free editing (on-device speech → Smart engine) as an accessibility feature.
- 🔜 Lightweight generative video effects 🧪, 3D/depth parallax photos, spatial photo export 🧪.
- **Acceptance:** reproducible builds on all stores; plug-ins cannot access network or files outside their sandbox.

## 6. Platforms

| Platform | Now | Plan |
|---|---|---|
| Android phones | ✅ API 26+, split APKs | Play Store (AAB, Play App Signing) v1.4; F-Droid / IzzyOnDroid |
| iOS / iPadOS | ✅ unsigned build (best-effort CI) | signed TestFlight → App Store with LGPL FFmpeg variant (see risks) v1.5 |
| Tablets | ✅ side-panel layouts | pencil pressure masks, multi-window, keyboard shortcuts (v2.0) |
| Desktop (macOS/Windows/Linux) | — | v2.0 (photo first, then video) |
| Web | — | v3.0, local processing only |

## 7. Performance budgets (reference phone unless stated)

| Metric | Budget |
|---|---|
| Cold start to Home | ≤ 1.2 s (low-end ≤ 2.5 s) |
| Open photo to first render | ≤ 600 ms for 12 MP |
| Slider → frame (2048 px proxy) | ≤ 16 ms (60 fps), never > 33 ms |
| Smart command (rule engine) | ≤ 10 ms parse, one frame to apply |
| Suggestions | ≤ 50 ms analysis + thumbnails progressive |
| Tap-to-select | encode ≤ 2.5 s once per photo; tap p95 ≤ 150 ms |
| Depth | ≤ 1.5 s per photo |
| Export 12 MP JPEG | ≤ 2 s; 48 MP tiled ≤ 8 s |
| Peak memory | ≤ 1.2 GB (low-end ≤ 800 MB, with one model loaded at a time) |
| App download | ≤ 60 MB per ABI; models on demand, each ≤ 50 MB until v1.5 |
| Battery | ≤ 3 % for a 10-minute editing session with two AI steps |

## 8. Quality & testing

- ✅ Unit + widget + real GPU shader tests (350+), strict analysis, format gate in CI.
- 🔜 **Golden tests** for every shader and look (pixel tolerance, per backend: Impeller Vulkan/Metal/GLES).
- 🔜 **Device farm**: integration tests (`integration_test`) running each model and FFmpeg path on ≥ 12 real devices per release (cloud farm + a small owned rack); thermal and memory traces.
- 🔜 **Benchmarks**: per-model latency/memory tables per device tier published with each release; regression alarms at +15 %.
- 🔜 **Intent benchmark**: 1,000+ AR/EN commands (MSA + 4 dialect groups + code-switching "اجعلها warmer"), measured exact-plan accuracy; LLM engine must beat the rule engine before it ships.
- 🔜 Fuzzing of file decoders (JPEG/PNG/HEIC/DNG/.cube/JSON presets); crash-free target ≥ 99.8 % on the farm.

## 9. Accessibility & languages

- ✅ Semantics labels, reduce-motion support, WCAG AA contrast in the glass theme, haptics toggle, RTL.
- 🔜 Full TalkBack/VoiceOver audit each release; dynamic type up to 200 %; colour-blind-safe overlays; sliders operable by keyboard/switch.
- 🔜 Smart bar works with system dictation today; v3.0 adds on-device voice editing.
- 🔜 **30+ languages** via community translation (Weblate), with RTL for Arabic, Persian, Urdu, Hebrew; command lexicons for the top 8 languages (AR, EN, FR, ES, TR, ID, UR, HI), LLM engine for the rest.

## 10. Sustainability (monetisation compatible with open source)

- The editor stays **complete, free and ad-free**; no feature is paywalled, no credits, no watermark.
- Funding options, in order: GitHub Sponsors / Open Collective; paid **convenience builds** on stores (same code, signed, auto-updates) with free builds on GitHub/F-Droid; **creator marketplace** for premium LUT/preset/template packs (revenue share, packs are data, not code); sponsored hardware for the device farm; support contracts for schools/NGOs/newsrooms.
- Explicitly avoided: open-core, telemetry-for-revenue, selling data, cloud credits.

## 11. Community, plug-ins & marketplace

- 🔜 Preset/LUT pack format (versioned JSON + `.cube`, already importable) → gallery with ratings (v1.5).
- 🔜 Plug-in SDK: GLSL shader effects, model packs (ONNX/LiteRT with a manifest: I/O contract, licence, SHA-256, size), command lexicon packs for new languages.
- 🔜 Contributor guide, good-first-issues, translation sprints, monthly community call; code of conduct.

## 12. Distribution & signing

- ✅ GitHub Releases with split APKs + checksums; unsigned iOS zip.
- 🔜 Release signing with a dedicated keystore in GitHub Actions secrets; SLSA provenance & SBOM (CycloneDX) attached to releases.
- 🔜 Google Play (AAB, Play App Signing, staged rollout); F-Droid (requires building native libs from source — start with IzzyOnDroid); Apple App Store via TestFlight with the LGPL FFmpeg build.

## 13. Security & privacy

- ✅ No network except model downloads (pinned revision URLs + SHA-256); local error log; CPU-safe inference defaults; one model in memory.
- 🔜 Signed model manifests (minisign) and a project-hosted mirror; downloads resume and verify; optional "offline only" mode that blocks all network.
- 🔜 iOS privacy manifest audit, Android `networkSecurityConfig` restricted to model hosts, dependency review + OpenSSF Scorecard in CI, reproducible builds, coordinated disclosure policy (`SECURITY.md`).
- 🔜 Plug-in sandbox: no network, scoped file access, permission prompts.

## 14. Risks & mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Third-party hosts break (e.g. `download.onnxruntime.ai` TLS failure in Nov 2026) | builds or model downloads fail | pinned revisions, SHA-256, project mirror (live since v1.3.3 — every model also served from this repo's releases), scripted fallbacks (`tool/ios_fix_onnxruntime_spm.sh`) |
| Model licences (non-commercial weights) | legal | licence check in the registry review; reject NC weights (e.g. RMBG-2.0, CodeFormer-class) |
| GPL x264 in `min_gpl` vs App Store terms | iOS distribution | ship iOS with `ffmpeg_kit_flutter_new_min` + VideoToolbox (LGPL) |
| NPU/driver crashes on some SoCs | app killed natively | CPU default (done), per-SoC allow-list, farm testing, auto-fallback |
| Low-end memory | OOM kills | one model at a time (done), tiling, size caps, int8 models |
| LLM size (≈ 2.6 GB) | storage, download | optional pack, smaller models for mid-range, rule engine always available |
| Platform owners bundle free AI (Google, Apple, Samsung) | user acquisition | differentiate: privacy, Arabic, offline, open, no watermark, cross-device, pro tools |
| Dialect & code-switching coverage | failed commands | benchmark-driven lexicon, community lexicon packs, LLM engine |
| Maintainer bandwidth | slower releases | plug-in architecture, contributor programme, automated QA |

## 15. KPIs (measured without telemetry)

- **Quality:** intent benchmark exact-plan accuracy (target ≥ 95 % v1.3.x, ≥ 98 % with LLM v2.0); suggestion acceptance in moderated usability tests ≥ 50 %; farm crash-free ≥ 99.8 %.
- **Speed:** budgets in §7 met on all three device tiers each release.
- **Reach:** GitHub stars & release downloads, store installs and ratings (≥ 4.6), F-Droid availability, number of languages ≥ 30 by v3.0.
- **Community:** monthly contributors ≥ 20 by v2.0; marketplace packs ≥ 200 by v2.0; translators ≥ 100.
- **Trust:** zero network calls outside model hosts (verified by automated traffic test); 100 % of models with licence + SHA-256 + measured latency published.

## 16. Sources (competitive facts, checked 2026-11-21)

- Lightroom mobile 12.0 (AI Assistant early access, Glow): https://helpx.adobe.com/lightroom/mobile/whats-new/adobe-lightroom-on-mobile-release-notes.html · Open Eyes: https://blog.adobe.com/en/publish/2026/10/19/give-your-photos-a-second-chance-with-open-eyes-in-lightroom-on-mobile · Generative credits: https://www.lightroomqueen.com/whats-new-in-lightroom-2026-11/
- Google Photos "Help me edit": https://blog.google/products-and-platforms/products/photos/android-conversational-editing-google-photos/ · eligibility: https://9to5google.com/2025/10/14/google-photos-conversational-editing-is-now-available-for-most-us-based-android-users/
- Samsung Photo Assist (network, watermark, 12 MP): https://www.samsung.com/us/support/answer/ANS10000753/ · S26 natural-language editing: https://news.samsung.com/global/samsung-unveils-galaxy-s26-series-the-most-intuitive-galaxy-ai-phone-yet
- Snapseed 4.0 and on-device Object Brush: https://gadgets.beebom.com/news/snapseed-4-0-update-arrives-on-android · https://research.google/blog/introducing-interactive-on-device-segmentation-in-snapseed/
- Apple Clean Up requirements: https://support.apple.com/en-us/121429 · Pixelmator Pro for iPad / Creator Studio: https://www.apple.com/newsroom/2026/01/introducing-apple-creator-studio-an-inspiring-collection-of-creative-apps · Pixelmator Pro 5.0: https://support.apple.com/en-us/126257 · Photomator status: https://en.wikipedia.org/wiki/Pixelmator
- Picsart pricing/credits: https://picsart.com/pricing · Photoroom plans: https://help.photoroom.com/en/articles/6976012-what-are-photoroom-s-plans · CapCut pricing: https://www.capcut.com/help/new-capcut-subscription-pricing · VSCO: https://www.wired.com/story/vsco-is-gunning-for-adobe-lightroom-with-its-new-desktop-app/
- VN captions (local models, 43 languages): https://vlognow.me/blog/features/auto-captions · InShot: https://inshot.com/ · Wink: https://wink.meitu.com/ · Remini pricing: https://rankite.com/blog/best-video-enhancer-app
- LiteRT-LM / Gemma 4 E2B benchmarks: https://developers.google.com/edge/litert-lm/overview
- Models shipped in 1.3: see [docs/SMART_EDIT.md](docs/SMART_EDIT.md) (URLs, sizes, SHA-256, measured latency).
