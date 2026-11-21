# Changelog · سجل التغييرات

All notable changes to Lumora Studio. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions follow [SemVer](https://semver.org/).

## [1.1.1] - 2026-11-21

### Fixed
- **AI tools no longer close the app on Android.** Release builds are shrunk by R8, which renamed/removed ONNX Runtime's Java classes (`ai.onnxruntime.*`) that its native library looks up by name; the first AI tool then aborted the whole process ("Lumora Studio has stopped"). `android/app/proguard-rules.pro` now keeps ONNX Runtime, the flutter_onnxruntime bridge and FFmpegKit, and is wired into the release build type.
- Safer on-device inference: CPU execution by default (XNNPACK and KleidiAI kernels are now an opt-in "AI acceleration" switch in Settings), at most 4 threads, only one model loaded at a time, serialized runs, outputs released before inputs.
- Lower peak memory: the object eraser works on a copy capped at 4096 px (its mask too), and 4× upscale caps the input at ≈0.8 MP and no longer copies its ~200 MB buffers into a second isolate.
- Every AI tool checks that its model is on the device first: it asks before downloading and shows a progress dialog with retry. Failures are shown in plain words (no internet, damaged model, not enough memory, model cannot load on this device) instead of raw exceptions.

### Added
- **Settings › Error log**: a local log of Dart errors, breadcrumbs of each AI step, and — on Android 11+ — why the previous run ended (native crash, ANR, low memory) plus any uncaught JVM exception. Copy or share it; nothing is uploaded.

### Changed
- Version 1.1.1 (build 3).

### الإصلاحات (العربية)
- **أدوات الذكاء الاصطناعي لم تعد تُغلق التطبيق على Android.** كان R8 في نسخ الإصدار يحذف أو يعيد تسمية أصناف Java الخاصة بـ ONNX Runtime التي تبحث عنها مكتبته الأصلية بالاسم، فيتوقف التطبيق بالكامل ("Lumora Studio توقف") عند أول أداة ذكاء. أضفنا قواعد الحماية في `android/app/proguard-rules.pro` لـ ONNX Runtime وجسر flutter_onnxruntime وFFmpegKit وربطناها بنوع بناء الإصدار.
- تشغيل أكثر أمانًا: المعالج المركزي (CPU) افتراضيًا، وأصبح تسريع XNNPACK/KleidiAI خيارًا اختياريًا "تسريع الذكاء الاصطناعي" في الإعدادات، بحد أقصى 4 خيوط، ونموذج واحد في الذاكرة في كل مرة.
- استهلاك ذاكرة أقل: ممحاة العناصر تعمل على نسخة لا تتجاوز 4096 بكسل، والتكبير 4× يحدّ حجم الصورة المُدخلة بنحو 0.8 ميغابكسل.
- تتحقق كل أداة من وجود نموذجها قبل التشغيل: تطلب الإذن قبل التنزيل وتعرض نافذة تقدّم مع إعادة المحاولة، وتظهر الأخطاء بكلمات واضحة بدلًا من رسائل تقنية.
- **الإعدادات › سجل الأخطاء**: سجل محلي للأخطاء وخطوات الذكاء الاصطناعي وسبب انتهاء التشغيل السابق (Android 11 فأحدث)، مع النسخ والمشاركة؛ لا يُرفع أي شيء.

## [1.1.0] - 2026-11-20

### Added
**Looks & presets**
- Live preset thumbnails: every look is rendered on a low-res proxy of *your* photo by the real GPU pipeline, lazily and cached.
- 15 new looks (45 in total) and new categories: Essentials, Portrait, Food, Film, Vintage, Cinematic, Landscape, B&W, Creative.
- Favorites (long-press any look) and **My presets**: save the current look, rename, delete, import/export/share as `.json` (versioned, validated, values clamped).
- Copy / paste edits between photos with a choice of parts (look, crop, masks, text, frame & watermark). Also from a project tile on Home.

**Home & projects**
- Quick tools row: Remove background, Auto-enhance, Upscale 4×, Object eraser, Heal, Scan document, Collage, Batch edit.
- Project tiles with rename, duplicate, copy edits and delete; Photo/Video filter; friendly dated names (old file-number names such as "38624" are shown as dates); illustrated empty state.
- First-run tips (4 pages) and richer Settings: system/dark/light theme, haptics, default quality and maximum export size, AI model storage, clear temporary files.

**Document scanner**
- On-device edge detection (no ML Kit, no OpenCV), draggable corners with a magnifier, perspective correction, rotation.
- Filters: Magic color, No shadows, Grayscale, Black & white (adaptive).
- Multi-page PDF export (A4, Letter or fit-to-image) with a dependency-free PDF writer, or save pages as images.

**Photo editor**
- Healing brush (automatic source search + colour-corrected blending) and clone stamp — model-free.
- Selective colour: pick a colour on the photo, then drag up/down to change its hue, saturation or luminance.
- More per-mask sliders (whites, blacks, vibrance, sharpen, structure), duplicate and hide masks.
- Frames: border, polaroid, fit to 1:1 / 4:5 / 9:16 / 16:9 with colour or blurred-photo fill, rounded corners.
- Watermark: text and/or logo, 9 positions, size, opacity, margin, colour.
- Export: social sizes (Instagram 4:5 and 1:1, Story 9:16, X 16:9, WhatsApp, Facebook) with crop or pad, share without saving.
- Histogram overlay with clipping indicators and a red/blue clipping-warning shader.
- History panel: jump to any step (nothing is lost; later steps stay redoable).
- Pinch zoom/pan and double-tap 1:1 on the preview.

**Batch & collage**
- Batch edit: apply a preset (with strength), copied edits and/or per-photo auto-enhance to many photos and export them all at full resolution.
- Collage maker: 20 layouts for 1–9 photos, 5 aspect ratios, spacing, margin, rounded corners, colour or gradient backgrounds, pinch to position each photo.

**Video**
- Free-form crop on a frame of the clip, with aspect locks.
- Filter strength and keyframes (animated look) — previewed live, exported with an FFmpeg `blend` expression (fast) or per frame (studio).
- Stabilisation per clip (two-pass FFmpeg vid.stab, included in the `min_gpl` build).
- Save the frame under the playhead as a photo and open it in the photo editor.
- Animated GIF export (palettegen/paletteuse).

**Polish**
- Haptic feedback (can be turned off), animated tool panels, semantics labels, side-panel layouts on tablets for the photo and video editors.
- `release.yml` workflow: tag `v*` (or run it manually) to build split-per-ABI APKs and an unsigned iOS app and publish them to a GitHub Release.

### Changed
- Version 1.1.0 (build 2).
- Autosave no longer overwrites a project's name.

## [0.1.0] - 2026-11-20
- First release: GPU photo pipeline, 30 looks, masks, layers, ONNX AI tools, FFmpeg video timeline, Arabic/English.
