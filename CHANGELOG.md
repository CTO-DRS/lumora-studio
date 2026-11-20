# Changelog · سجل التغييرات

All notable changes to Lumora Studio. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions follow [SemVer](https://semver.org/).

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
