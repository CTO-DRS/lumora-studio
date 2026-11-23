# Changelog · سجل التغييرات

All notable changes to Lumora Studio. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions follow [SemVer](https://semver.org/).

## [1.3.2] - 2026-11-23

### Fixed
- **iOS build**: the `onnxruntime_extensions` archive that SwiftPM insisted on downloading is now gone from Microsoft's origin storage too (HTTP 404), after `download.onnxruntime.ai` started serving a wrong TLS certificate. Lumora never links it, so `tool/ios_fix_onnxruntime_spm.sh` now removes that product and its targets from the pinned local copy of `onnxruntime-swift-package-manager` 1.28.0. Only the `onnxruntime` binary (a GitHub release asset, checksum-verified) is downloaded. No app code changed.
- **إصلاح بناء iOS**: حُذفت حزمة `onnxruntime_extensions` غير المستخدمة التي لم تعد متاحة للتحميل، فلم يعد البناء يعتمد عليها.

## [1.3.1] - 2026-11-23

### Changed
- **Official release signing**: Android release APKs are now signed with Lumora's own upload key (RSA 4096, SHA-256 `B7:1C:9F:6B:BB:B9:1B:22:D4:1A:A9:8F:9C:87:2B:2F:22:A0:E1:37:81:B6:C2:D0:7A:95:2A:86:83:F4:C6:91`) instead of the debug key. The key is kept outside this public repository; the release workflow verifies every APK against this fingerprint. Builds without the key (forks, local) still fall back to the debug key.
- **التوقيع الرسمي**: أصبحت ملفات APK موقّعة بمفتاح Lumora الرسمي بدل مفتاح التصحيح. **مرة واحدة فقط**: احذف النسخة القديمة من جوالك ثم ثبّت هذه النسخة (لاختلاف التوقيع). بعدها ستعمل التحديثات فوق بعضها مباشرة.

### Note
- Because the signature changed, Android will refuse to update an older debug-signed install: uninstall Lumora once, then install 1.3.1. Future updates install over it normally.

## [1.3.0] - 2026-11-21

### Added
- **Smart edit by typing** (`lib/features/smart_edit`): a new **Smart** tab, now the editor's first and default tab, with a command bar that understands Arabic and English instructions on the device. A deterministic intent engine (`RuleIntentEngine`) normalises Arabic (diacritics, hamza/alef forms, tatweel, Arabic-Indic digits, attached و/ف/ب/ل/ال), splits a sentence into clauses ("زد التباين وقلل التشبع", "warmer, more contrast, then black and white"), and maps each clause to sliders (with direction, intensity words, signed numbers, percentages and EV), looks, rotate/flip, reset/undo, or AI tools. The instant part of a plan is applied as **one undo step**; model-backed actions ask before downloading. Unknown fragments are reported, never guessed. Plans serialise to JSON (`SmartEditPlan.toJson`), the contract for a future on-device LLM engine (`EditIntentEngine`). See `docs/SMART_EDIT.md`.
- **Suggestions for this photo**: `PhotoAnalysis` (histogram, clipping, gray-world colour cast, YCbCr skin tones in the centre, sky in the top third, foliage, paper/ink for documents, haze) and `suggestFixes` rank 3–5 one-tap fixes (auto fix, brighten, recover highlights, fix colour, portrait glow, deeper sky, vivid nature, clean document, clear haze, vivid colour, cinematic, black & white) shown with live thumbnails rendered by the real GPU pipeline.
- **Tap to select** (MobileSAM, `ObjectSelectPipeline`): the photo is encoded once, every tap runs only the decoder; add/subtract points, undo the last tap, and use the selection to **erase** (MI-GAN), **cut out**, **adjust** (as a subject mask) or **blur the rest**. The selection overlay follows crop and rotation.
- **Depth blur** and **Relight** (Depth Anything V2 Small int8, `DepthPipeline`): depth-graded background blur, or a subject lift + background dim, both as editable subject masks.
- **Remove person**: MODNet person matte → object eraser, with a clear message when no person is found.
- New models (revision-pinned Hugging Face URLs, SHA-256 verified, each downloaded and run with ONNX Runtime before being added): `mobilesam_encoder` (28.2 MB), `mobilesam_decoder` (16.5 MB), `depth_anything_v2_small_q8` (27.3 MB).
- `tool/ios_fix_onnxruntime_spm.sh` and a world roadmap (`ROADMAP.md`, `docs/ROADMAP.ar.md`) plus `docs/VISION.md`.
- 180+ new tests: 140+ Arabic/English command phrases, analysis on synthetic photos, SAM/depth tensor contracts, the Smart panel end to end.

### Fixed
- **iOS release build**: SwiftPM resolves every binary target of `onnxruntime-swift-package-manager`, including `onnxruntime_extensions` hosted on `download.onnxruntime.ai`, whose TLS certificate is for `*.azureedge.net` (hostname mismatch), so the build failed although the plugin never links it. Switching to CocoaPods would not help (the `onnxruntime-c` / `onnxruntime-objc` pods use the same host). CI and the release workflow now run `tool/ios_fix_onnxruntime_spm.sh`, which makes the plugin depend on a local checkout of the pinned package whose extensions URL points at Microsoft's origin storage (`onnxruntimepackages.z14.web.core.windows.net`) — the same file, still verified by the original SHA-256 checksum. iOS stays best-effort in both workflows.

### Changed
- The editor opens on the **Smart** tab. `PresetTile` is public (shared by Looks and Smart).
- Version 1.3.0 (build 5).

### العربية
- **التعديل الذكي بالكتابة**: تبويب «ذكي» جديد أصبح التبويب الأول في المحرر. اكتب أمرك بالعربية أو الإنجليزية («اجعلها أدفأ»، «زد السطوع قليلاً»، «أبيض وأسود»، «أزل الخلفية») فيُنفَّذ على جهازك في خطوة تراجع واحدة. المحرّك حتمي ويعمل دون إنترنت، ويفهم الشدة والأرقام وعدة أوامر في جملة واحدة، ويُبلغك بما لم يفهمه بدل التخمين. صيغة الخطة JSON جاهزة لنموذج لغوي محلي مستقبلًا.
- **مقترحات لهذه الصورة**: تحليل سريع للتعريض والإضاءات والألوان والبشرة والسماء والمستندات، ثم 3–5 إصلاحات بلمسة واحدة بمعاينات حيّة.
- **التحديد بلمسة** (MobileSAM): حدّد أي عنصر ثم امسحه أو قصّه أو عدّله وحده أو موّه الباقي.
- **تمويه بالعمق** و**إعادة الإضاءة** (Depth Anything V2)، و**إزالة شخص** بلمسة واحدة.
- **إصلاح بناء iOS**: تجاوز خادم `download.onnxruntime.ai` ذي الشهادة غير الصالحة بجلب الملف نفسه من مخزن Microsoft الأصلي مع التحقق من بصمته.
- خارطة طريق عالمية ورؤية المشروع بالعربية والإنجليزية.
- الإصدار 1.3.0 (البناء 5).

## [1.2.0] - 2026-11-21

### Added
- **Design system "calm glass"** (`lib/core/ui`): `LumoraTokens` theme extension (dark + light), `GlassContainer` with a hairline gradient border (`GradientBorderPainter`), `LumoraBackground` (static, very faint glows), `GlowButton`, `GlassIconButton`, `GlowIconOrb`, `GlassChip`, `GlassTopBar` / `GlassAppBar`, `GlassNavBar`, `GlassToolTile`, `PressScale`, and gradient slider track / orb thumb shapes. All Material components (buttons, chips, segmented buttons, switches, sliders, tabs, dialogs, sheets, menus, snackbars, inputs) are themed from the tokens.
- **App shell with a floating glass bottom bar** (go_router `StatefulShellRoute`): Home, Templates, Projects, Settings and a raised **Create** button (photo, video, collage, scanner, batch). Animated selection indicator; every v1.1 route and deep link still works (`/photo`, `/video`, `/scan`, `/collage`, `/batch`, `/models`, `/errors`, `/welcome` open full screen above the bar).
- **Templates tab**: every look by category with live previews rendered by the real pipeline on a drawn sample scene; tapping one opens a picked photo with that look applied.
- **Projects tab** (all projects, search, filter) and project search on Home.
- **AI tools sheet** ("Runs on your device") with a 2-column grid of glass cards; cards of tools whose model is not installed show the download size and a live progress ring. Also used by the editor's AI tab. New quick actions: portrait cut-out, background blur, portrait retouch.
- New app icon on Android (all densities + adaptive icon on #07061A) and iOS (all AppIcon sizes, no alpha); `tool/generate_icons.py` regenerates them. The icon is also shown in the Home top bar, Settings and onboarding.
- Screenshot harness `test/screenshots/` (skipped unless `LUMORA_SCREENSHOTS` is set) renders real PNGs of the redesigned screens; README screenshots now come from it.

### Changed
- Colours are deliberately calm: navy background `#0E1022`, background glows ≤ 12 % opacity, borders soft violet→blue at ~40 % opacity, primary gradient `#6E5FE0 → #4C7BD8` (white text ≥ 4.5:1), muted accent tones (blue, teal, rose, mint, apricot, violet). Glow only on the selected element and the main call to action. The old amber/orange/brown accents are gone everywhere, including crop handles and brush cursors.
- Home: glass top bar with the app icon, hero card with **Edit photo / Edit video**, quick tools as round orbs (scrollable), recent projects as a 2-column glass grid (with "See all").
- Photo editor: glass top bar (back, more, history, compare, undo, redo, gradient **Export** pill), photo in a rounded frame, presets strip with a glowing selected border, gradient sliders (bipolar sliders fill from the neutral point), floating glass tool bar with an active glowing tile.
- Video editor, settings, scanner, collage, batch, onboarding, models and error log use the same components.
- Android launch screen and window background `#0E1022` (Android 12+ splash included); iOS launch screen background matches.
- Motion respects the system "reduce motion" setting (press scale, nav indicator, onboarding).
- Version 1.2.0 (build 4).

### Fixed
- Preset thumbnails now fill their tile (they were letterboxed by the cross-fade).

### العربية
- **نظام تصميم جديد "زجاج هادئ"**: أسطح زجاجية بحدود متدرجة رفيعة، خلفية كحلية هادئة (`#0E1022`) بتوهجات خافتة جدًا، تدرّج أساسي ناعم من البنفسجي إلى الأزرق، وألوان أدوات هادئة. التوهج فقط للعنصر المحدد والزر الرئيسي، مع تباين نصوص مطابق لمعيار WCAG AA. أُزيلت الألوان البرتقالية والبنية القديمة من كل مكان.
- **شريط تنقّل سفلي زجاجي عائم**: الرئيسية، القوالب، المشاريع، الإعدادات، وزر **إنشاء** بارز (صورة، فيديو، تجميعة، ماسح، دفعة). كل الروابط السابقة ما زالت تعمل.
- **تبويب القوالب** بمعاينات حيّة لكل نمط، و**تبويب المشاريع** مع البحث والتصفية.
- **لوحة أدوات الذكاء الاصطناعي** "يعمل على جهازك": بطاقات زجاجية تعرض حجم التنزيل وحلقة التقدّم للأدوات التي لم يُنزَّل نموذجها بعد.
- **محرر الصور** بتصميم جديد: شريط علوي زجاجي، صورة بإطار مستدير، شريط أنماط بتحديد متوهّج، منزلقات متدرجة، وشريط أدوات عائم.
- **أيقونة جديدة** للتطبيق على Android (بكل الكثافات والأيقونة التكيّفية) وiOS، وشاشة بدء كحلية.
- احترام إعداد "تقليل الحركة" في النظام.
- الإصدار 1.2.0 (البناء 4).

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
