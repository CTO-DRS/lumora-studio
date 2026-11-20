# Roadmap · خارطة الطريق

Status legend: ✅ done · 🚧 partial · 🔜 planned

## v0.1 (this release)
- ✅ GPU photo pipeline (tone, colour, HSL, curves, LUT, detail, effects, geometry)
- ✅ 30 presets, `.cube` import, masks (brush / linear / radial / AI subject)
- ✅ Text, stickers, drawing layers
- ✅ Undo/redo, local projects (Drift), full-res and tiled export, EXIF copy
- ✅ ONNX Runtime AI: background removal, portrait matting, object eraser (MI-GAN / LaMa), 4× upscale
- ✅ Video timeline, transitions, speed/reverse, music, text overlays, FFmpeg export (fast + studio)
- ✅ Arabic/English with RTL, CI, Dependabot

## Known gaps / TODO (v0.2)
- 🚧 **Face landmarks** for portrait retouch (eye brighten, teeth whiten, skin-only mask). Today retouch uses the MODNet person matte.
- 🚧 **Video crop** uses presets; a free-form crop UI like the photo editor is planned.
- 🚧 **Reverse preview**: playback preview shows clips forward; the export is reversed correctly.
- 🚧 **Transition preview**: transitions are applied at export only.
- 🔜 Interactive straighten grid and auto-straighten (horizon detection)
- 🔜 Keyframes for video adjustments and text animation presets
- 🔜 Waveform display for audio tracks and beat snapping
- 🔜 RAW (DNG) decoding via platform codecs and a 16-bit pipeline (`PixelFormat.rgbaFloat32`)
- 🔜 Real-time video LUT preview on non-Impeller fallback (ColorFilter approximation)
- 🔜 Batch export / apply look to many photos
- 🔜 Healing brush (patch-based, no model) for small blemishes
- 🔜 LiteRT (`tflite_flutter`) backend behind the `InferenceEngine` interface for NPU delegates
- 🔜 Generative fill with a quantised on-device diffusion model (opt-in, large download)
- 🔜 Desktop targets (macOS / Windows / Linux): FFmpeg and ONNX plugins already support them
- 🔜 Integration tests on real devices (`integration_test`) running the ONNX models and FFmpeg

## Ideas
- Plug-in system for community shaders and LUT packs
- Collage and template layouts
- Subtitle import (SRT) and on-device speech-to-text (Whisper.cpp) for auto captions
