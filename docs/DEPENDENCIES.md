# Dependencies (verified on pub.dev on 2026-11-20)

| Package | Version | Published | Why |
|---|---|---|---|
| Flutter / Dart | 3.50.1 / 3.14.0 | 2026-11-18 | latest stable |
| material_ui | ^1.11.1 | 2026-11-16 | Material 3 widgets; `package:flutter/material.dart` is deprecated since 3.47 |
| flutter_riverpod / riverpod_annotation / riverpod_generator | ^3.5.0 / ^4.0.8 / ^4.0.10 | 2026-11-06 | state management with code generation |
| go_router | ^18.1.4 | 2026-11-09 | declarative routing |
| freezed / freezed_annotation | ^4.0.3 / ^3.1.0 | 2026-10 / 2025-07 | immutable models and unions |
| json_serializable / json_annotation | ^6.15.2 / ^4.12.0 | 2026-10 / 2026-05 | project serialization |
| build_runner | ^2.17.1 | 2026-10-14 | codegen (use `--force-jit` on slow machines) |
| drift / drift_flutter / drift_dev | ^2.35.4 / ^0.3.1 / ^2.35.3 | 2026-11-08 | local project database (`sqlite3_flutter_libs` is EOL; sqlite3 3.x build hooks are used) |
| very_good_analysis | ^11.0.0 | 2026-09-03 | strict lints |
| flutter_onnxruntime | ^1.9.0 | 2026-10-06 | maintained ONNX Runtime plugin (CoreML/NNAPI/XNNPACK); `onnxruntime` 1.4.1 is from 2024 |
| ffmpeg_kit_flutter_new_min_gpl | ^2.7.2 | 2026-11-17 | maintained FFmpegKit fork, FFmpeg 8.1.2 prebuilt (see ARCHITECTURE.md) |
| video_player | ^2.14.1 | 2026-10-02 | first-party playback; media_kit's last release was 2025-12 |
| image | ^4.13.1 | 2026-11-14 | isolate-side decode/encode/resize for tiling and AI |
| flutter_image_compress | ^2.5.1 | 2026-07-25 | platform WebP/HEIC encoders |
| native_exif | ^0.8.0 | 2026-05-08 | EXIF read/write |
| gal | ^3.0.1 | 2026-11-15 | save to gallery |
| image_picker / file_picker | ^1.2.4 / ^13.4.0 | 2026-10 / 2026-11 | media, LUT and audio selection |
| share_plus | ^13.3.1 | 2026-10-01 | share exports |
| path_provider / path / shared_preferences / uuid / crypto / http / intl | latest | | infrastructure |

Rejected or avoided:
* `google_mlkit_*`: requires Google Play services, which this project forbids.
* `ffmpeg_kit_flutter_*` (arthenica): discontinued, binaries removed.
* `tflite_flutter` 0.12.1 (2025-10): kept as a future `InferenceEngine` backend. ONNX gives direct access to the Hugging Face model zoo.
* `pro_image_editor`: a complete editor UI, but it would replace our own GPU pipeline and edit model.
