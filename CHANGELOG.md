# Changelog · سجل التغييرات

All notable changes to Lumora Studio. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions follow [SemVer](https://semver.org/).

## [1.4.0] - 2026-11-25 (v1.4 "Pro foundations", first wave)

### Added
- **Face-aware retouching (on-device)**: OpenCV Zoo **YuNet** face detection (232 KB, pinned commit, SHA-256-verified; raw 12-output decode implemented in Dart and verified against `cv2.FaceDetectorYN`, ≈ 6 ms at 640×640 on the 2-core x86 sandbox) + **MediaPipe Face Mesh** 478 landmarks (4.9 MB, pinned HF revision, ≈ 12 ms per aligned pass). From the landmarks the editor builds feathered **skin / eyes / teeth** masks: *Skin retouch* (face oval minus eyes, brows and lips — smoothing no longer bleeds into eyes or lips, replacing the person-matte approximation), *Brighten eyes* and *Whiten teeth* as one-tap tools, all non-destructive masked local adjustments.
- **Sky edits (on-device)**: **SkySeg** (U²-Net fine-tune) quantised by this project to static int8 (44 MB, IoU vs fp32 ≈ 0.99, ≈ 290 ms at 320×320): *Enhance sky* applies a "bluer, punchier sky" recipe through the feathered sky matte, and *Replace sky* composites any photo picked from the gallery into the sky region (cover-fit, feathered, non-destructive).
- **Beat detection & waveform (video)**: pure-DSP, no model — log-energy-flux onset detection with adaptive thresholding, autocorrelation tempo (60–190 BPM) and a timeline waveform envelope. Validated on synthetic click tracks at 120/90/140/75 BPM: every click recovered within ±60 ms, zero strays, BPM within ±3 (`test/unit/audio_analysis_test.dart` mirrors `scripts/validate_beats.py`). `VideoEngine.extractAudioPcm/detectBeats/waveform` + `AudioAnalysis.snapToBeat` for cutting on the beat.
- **Auto-straighten**: per-column sub-pixel horizon positions + weighted least-squares line fit with 2σ outlier rejection and a residual-spread gate (random texture is refused). ±4° tilts recovered within 0.7° on the synthetic tests; the Crop panel gains an *Auto straighten* button.
- **Smart commands extended**: Arabic & English commands for the new tools — `بيّض أسناني`, `فحّت العيون`, `اجعل السماء أكثر زرقة`, `whiten teeth`, `brighten the eyes`, `make the sky bluer`, … — plus the intent-benchmark suite still at 100 % (the new phrases ride the same exact-plan gate).
- **Model pack `models-1.4`**: the three new models are mirrored as GitHub Release assets with identical SHA-256; the registry test enforces the contract.

### العربية
- **تجميل واعٍ بالوجه (على الجهاز)**: كشف الوجوه بـ **YuNet** (232 كيلوبايت، التزام مثبّت، فك التشفير الخام في Dart مُتحقَّق مقابل `cv2.FaceDetectorYN`، ≈ 6 مللي ثانية) + **Face Mesh** بـ 478 نقطة معالم (≈ 12 مللي ثانية لكل تمريرة). تُبنى من المعالم أقنعة ناعمة **للبشرة/العيون/الأسنان**: *تنعيم البشرة* (بيضاوي الوجه ناقص العيون والحواجب والشفاه — لم يعد التنعيم يمتد إلى العينين)، و*تفتيح العيون* و*تبييض الأسنان* كأدوات بلمسة، وكلها تعديلات محلية غير مدمّرة.
- **تحرير السماء (على الجهاز)**: **SkySeg** (U²-Net) كمّنتها المشروع إلى int8 ثابت (44 ميغابايت، IoU ≈ 0.99 مقابل fp32، ≈ 290 مللي ثانية): *تجميل السماء* يطبّق وصفة «سماء أكثر زرقة وحيوية» عبر قناع السماء الناعم، و*استبدال السماء* يركّب أي صورة من المعرض داخل منطقة السماء.
- **كشف الإيقاع والموجة الصوتية (فيديو)**: معالجة إشارات صرفة دون نماذج — كشف البدايات بتدفق الطاقة اللوغاريتمي، عتبة تكيفية، تقدير الإيقاع بالارتباط الذاتي (60–190 BPM) ومغلف موجة للخط الزمني. مُتحقَّق على مسارات نقر اصطناعية: كل نقرة ضمن ±60 مللي ثانية، بلا شواذ، والإيقاع ضمن ±3.
- **تسوية تلقائية**: مواقع أفق دون-بكسل لكل عمود + ملاءمة خطية موزونة مع رفض الشواذ وبوابة انتشار؛ تُستعاد ميول ±4° داخل 0.7°، وزر «تسوية تلقائية» في لوحة القص.
- **أوامر ذكية جديدة**: `بيّض أسناني`، `فحّت العيون`، `اجعل السماء أكثر زرقة`، `whiten teeth`، `make the sky bluer` وغيرها — ومعيار الأوامر ما زال 100٪.
- **حزمة نماذج `models-1.4`**: النماذج الثلاثة مروّعة في إصدار GitHub ببصمات متطابقة، واختبار السجل يفرض العقد.

## [1.3.3] - 2026-11-25

### Added
- **Model mirror** (v1.3.x roadmap): every model is also published as a GitHub Release asset of this repository (`models-1.3`) with **identical bytes and the same SHA-256**. `ModelManager` now tries the pinned primary URL first and falls back to the mirror automatically — on HTTP errors, TLS problems and checksum mismatches alike. `tool/mirror_models.dart` reads the registry (single source of truth), `tool/mirror_models.py` downloads and verifies, and the new `Mirror models` workflow uploads the verified assets.
- **Tap to select upgraded**: the SAM **multi-mask decoder** (16.5 MB, `8976b90a…22ffe`, verified by downloading, hashing and running it with ONNX Runtime: ≈ 96–105 ms per decode on the 2-core x86 sandbox) replaces the single-mask decoder. Every decode now returns **three candidates** ranked by the decoder's IoU predictions and switchable with one tap. New prompt modes: **drag a box** (SAM corners, labels 2/3, combinable with taps), a **refine brush** (painted strokes become SAM's 256 px mask input — add strokes extend the selection, eraser strokes cut parts away), and a **soft-edges slider** (0–4 px feather) applied when the selection is used for erase / cut out / adjust / blur-the-rest.
- **Smart bar: command history & favourites & next commands**: the last 24 unique commands persist on the device with a "Recent" row; long-press stars a command into "Saved" (up to 12). After every applied command the panel suggests up to three **next** commands chained to what just happened ("more contrast" after "brighter", "more blur" after background blur) — every suggestion is guaranteed to parse into a non-empty plan.
- **Home AI tools sheet**: the 1.3 tools are now quick actions from Home too — tap-to-select, depth blur, relight and remove person join the existing cards.
- **Dialect lexicon pass** (Gulf, Egyptian, Levantine, Maghrebi): intensifiers `مره / اوي / خالص / بزاف` (alongside MSA `كثيرًا` and Levantine `كتير`), removal verbs `شيل / اشيل / اطفي`, "make it good" `زين / حلو / منيح`, clarity `وضح`, Egyptian `حط`, and the French code-switch `moins`.
- **Intent benchmark** (`test/unit/smart_intent_benchmark_test.dart`): **1,527 commands** — MSA and the four dialect groups, numbers (incl. Arabic-Indic digits and percentages), looks, actions and Arabic/English code-switching — each with its exact expected plan. Measured accuracy: **Arabic 1089/1089 = 100 %, English 438/438 = 100 %** (release gate: ≥ 95 % per language). Failures are lexicon gaps by construction: fix the lexicon, never the expectation.
- `InferenceEngine.runNamed` returns several named outputs so pipelines can read the decoder's `iou_predictions`; the ONNX implementation, session handling and safe CPU defaults are unchanged.

### العربية
- **مرآة النماذج** (خارطة 1.3.x): كل نموذج يُنشر أيضًا كملف في إصدار GitHub للمشروع (`models-1.3`) بالبايتات نفسها وبصمة SHA-256 نفسها، وعند فشل الرابط الأساسي (خطأ شبكة أو TLS أو بصمة) يتحوّل التنزيل تلقائيًا إلى المرآة. أدوات `tool/mirror_models.dart` و`tool/mirror_models.py` وسير عمل «Mirror models» تنشرها وتتحقق منها.
- **ترقية التحديد بلمسة**: مُفكّك SAM متعدد الأقنعة (16.5 ميغابايت، تم جلبها والتحقق من بصمتها وتشغيلها فعليًا: ≈ 96–105 مللي ثانية لكل فكّ) يُعيد **ثلاثة مرشّحين** مرتبين بتنبؤ IoU مع تبديل بلمسة، وطرق تحديد جديدة: **سحب إطار** حول العنصر، و**فرشاة تدقيق** تحوّل التلوين إلى مدخل القناع (الإضافة توسّع و«الطرح» يستبعد)، ومنزلق **حواف ناعمة** يُطبَّق عند استخدام التحديد.
- **الشريط الذكي**: سجل آخر 24 أمرًا فريدًا + مفضلة بالضغط المطوّل، وبعد كل أمر تظهر حتى ثلاثة **أوامر تالية** مبنية على ما نُفّذ للتو، وكلها مضمونة الفهم.
- **أدوات الذكاء في الرئيسية**: تحديد بلمسة وتمويه بالعمق وإعادة الإضاءة وإزالة شخص أصبحت إجراءات سريعة من الشاشة الرئيسية.
- **معجم اللهجات** (الخليجية والمصرية والشامية والمغاربية): شدّات `مره/اوي/خالص/بزاف`، أفعال الإزالة `شيل/اشيل/اطفي`، التحسين `زين/حلو/منيح`، الوضوح `وضح`، المصرية `حط`، والخلط بالفرنسية `moins`.
- **معيار الأوامر**: **1,527 عبارة** بالفصحى واللهجات والأرقام والنسب والأنماط والإجراءات والخلط بين اللغتين، كلٌّ بخطتها المتوقعة بالضبط: **العربية 1089/1089 = 100٪ والإنجليزية 438/438 = 100٪** (بوابة الإصدار ≥ 95٪ لكل لغة).

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
