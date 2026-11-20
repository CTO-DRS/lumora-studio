# Roadmap · خارطة الطريق

Status legend: ✅ done · 🚧 partial · 🔜 planned

## v1.1 (this release)
- ✅ Live preset thumbnails on your own photo, 45 looks in 9 categories, favourites
- ✅ My presets: save, rename, delete, import/export JSON; copy/paste edits
- ✅ Home redesign: quick tools, project rename/duplicate/delete, dated names, onboarding, settings
- ✅ Document scanner: edge detection, perspective, shadow removal, B&W/magic colour, multi-page PDF
- ✅ Healing and clone brush (model-free), selective colour picker, richer local adjustments
- ✅ Batch editing and collage maker
- ✅ Frames, watermark, social export sizes, share sheet
- ✅ Histogram + clipping warnings, pinch zoom with double-tap 1:1, history panel
- ✅ Video: free-form crop, filter strength keyframes, vid.stab stabilisation, frame → photo, GIF export
- ✅ Haptics, animations, semantics labels, tablet layouts
- ✅ Release workflow (APKs + unsigned iOS on every `v*` tag)

## v0.1
- ✅ GPU photo pipeline, 30 presets, `.cube` LUTs, masks, text/stickers/drawing, undo/redo, projects, tiled export
- ✅ ONNX Runtime AI: background removal, portrait matting, object eraser (MI-GAN / LaMa), 4× upscale
- ✅ Video timeline, transitions, speed/reverse, music, text, FFmpeg export (fast + studio)

## Known gaps / next (v1.2)
- 🚧 **1:1 zoom** shows the ≤ 2048 px editing proxy; true full-resolution loupe (tile on demand) is planned.
- 🚧 **Zoom while painting**: pinch zoom is available in view tools (looks, adjust, colour…); brush/crop/text tools work at fit size.
- 🚧 **Selective colour** targets the 8 HSL bands (nearest band to the picked colour), not an arbitrary hue range.
- 🚧 **Healing** uses one automatically chosen source patch per stroke with membrane colour correction; a PatchMatch-style multi-patch fill is planned.
- 🚧 **Scanner** edge detection is classic CV (threshold + hull); it can miss white paper on a white table — drag the corners in that case. Live camera edge preview is planned.
- 🚧 **Batch** applies looks/copied edits, not crops or AI steps; it runs in the foreground (keep the screen on for large batches).
- 🚧 **Video keyframes** animate the look strength only (not individual sliders or text).
- 🚧 **Face landmarks** for portrait retouch (eye brighten, teeth whiten, skin-only mask). Retouch uses the MODNet person matte.
- 🚧 **Reverse / transition preview**: applied at export only.
- 🔜 Interactive straighten grid and auto-straighten (horizon detection)
- 🔜 Waveform display for audio tracks and beat snapping
- 🔜 RAW (DNG) decoding and a 16-bit pipeline
- 🔜 LiteRT (`tflite_flutter`) backend for NPU delegates; on-device OCR for scanned documents
- 🔜 Generative fill with a quantised on-device diffusion model (opt-in, large download)
- 🔜 Desktop targets (macOS / Windows / Linux)
- 🔜 Integration tests on real devices (`integration_test`) running the ONNX models and FFmpeg

## Ideas
- Plug-in system for community shaders and LUT packs
- Subtitle import (SRT) and on-device speech-to-text (Whisper.cpp) for auto captions
