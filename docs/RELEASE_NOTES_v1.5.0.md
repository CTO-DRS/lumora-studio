# Lumora Studio v1.5.0 "Pro Intelligence" - release notes (DRAFT, NOT RELEASED)

Status: **pre-release draft**. No version bump and no tag yet. Tagging waits for the release gates below.

## Highlights
- **Auto-captions, offline, Arabic and English** (Whisper tiny int8, about 40 MB, optional download): one-tap captions on the video timeline, editable, exported burned-in or as SRT/VTT.
- **Low-light rescue**: denoise plus exposure lift, one tap, no model.
- **Lip colour and brow enhance**: from face landmarks, no new model.
- **LiteRT/NPU engine** (from the v1.4 line): acceleration where the device allows, with automatic fallback; local latency and memory log in Settings.
- **RAW/DNG** open path with camera colour and 16-bit TIFF export.
- 100 % on-device, no accounts, no analytics.

## Deferred (and why)
- Full 19-class face parsing: licence-clean weights are not available (CelebAMask-HQ is non-commercial).
- Hair tint: waits for a verified licence on Google's own model card for MediaPipe selfie_multiclass or HairSegmenter.
- Learned low-light models (Zero-DCE++, denoiser): not integrated yet.

## Release gates still open (need real devices or the user)
1. Device farm matrix (12 devices), crash-free at least 99.8 %.
2. Store builds and benchmark tables (engine x delegate x model).
3. On-device smoke test of OnnxWhisperRuntime, especially zero-length KV tensors on the first decode step.
4. Caption UI visual check: caption look and Arabic shaping in exported frames, toolbar fit on narrow phones, panel layout, burn-in export time on long videos, live preview overlays, multi-clip projects.
5. Lip and brow strength on real faces.
6. Low-light speed on a phone (about 3.6 s at 12 MP measured on a desktop; budget 1.5 s) and a before/after quality set.
7. The `models-v1.5` mirror assets are published (Whisper tiny done).

Last step after the gates pass: bump version in pubspec and app info, move [Unreleased] in CHANGELOG.md under 1.5.0, tag v1.5.0.
