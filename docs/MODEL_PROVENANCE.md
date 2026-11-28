# Model provenance

Every learned model that ships (or may ship) with Lumora must be licence-clean
**verified from the source's own card or repo**, pinned by SHA-256, and
mirrored as a release asset on tag `models-v1.5` (identical bytes, same hash).
Nothing ships without all three. This file is the audit trail.

## Low-light enhancement (ROADMAP Track B1)

| Model | Licence | Verdict | Notes |
| --- | --- | --- | --- |
| Zero-DCE++ (Li-Chongyi/Zero-DCE_extension) | CC BY-NC 4.0 (own README License section, checked 2026-11-27) | **Blocked** | Non-commercial clause. |
| SCI (vis-opt-group/SCI, CVPR 2022) | None on the source repo (`license: null` via GitHub API, checked 2026-11-28) | **Blocked** | The NXP Hugging Face card (`nxp/sci-imx`) claims "Original License: MIT", but the source's own card says nothing, so the claim is unverifiable. Revisit if upstream adds a LICENSE. |
| **MAXIM-2S (google-research/maxim, CVPR 2022)** | **Apache-2.0** (repo `LICENSE` file, GitHub-detected `apache-2.0`, checked 2026-11-28) | **Cleared, weights pinned** | LOL low-light enhancement checkpoint. |

### MAXIM-2S LOL checkpoint (adopted)

- Source: `gs://gresearch/maxim/ckpt/Enhancement/LOL/checkpoint.npz`
  (GCS object generation `1648619824414492`, 172,436,430 bytes; GCS MD5 verified on download).
- SHA-256: `8a5b5c5ce85e56371ee8574790ff41d9be4827cefc563da62ad8480e42bf2788`
- Mirror: `https://github.com/CTO-DRS/lumora-studio/releases/download/models-v1.5/maxim_2s_lol_enhancement.npz` (byte-identical).
- Architecture: MAXIM-2S, 14.1 M params, 216 GFLOPs at full res, JAX/Flax `.npz` checkpoint. Reported 23.43 dB PSNR / 0.863 SSIM on LOL.
- **Integration gap (partly closed 2026-11-28):** the checkpoint is converted to ONNX, verified numerically against the JAX reference, and mirrored:
  - Artifact: `maxim_2s_lol_256x256.onnx` — fixed 256×256 tile, fp32, opset 17, 61,914,873 bytes.
  - SHA-256: `7294e4928031e5aafdb332877604bccc92900b6795c0e7be9add6b0fa794236c`
  - Mirror: `https://github.com/CTO-DRS/lumora-studio/releases/download/models-v1.5/maxim_2s_lol_256x256.onnx`
  - Conversion: `tool/convert_maxim_to_onnx.py` (jax2tf, XLA disabled → frozen GraphDef → tf2onnx). MAXIM pads inputs to multiples of 64, so 256×256 tiles need no internal padding.
  - Numerics: max abs diff 1.85e-6 / mean 2.24e-7 vs the JAX fp32 reference on a random 256×256 input — bit-faithful.
  - **fp16 build (fits the 50 MB budget)**: `maxim_2s_lol_256x256_fp16.onnx`, 32,967,474 bytes, SHA-256 `63fd1d26a5192c1b863a8dcadf39a06cf0829ce197c639e2a9b7d39f0ef4ab18`, same mirror tag. The naive float16 pass left mixed-type constants around the LeakyRelu comparison chains, so `tool/quantize_maxim_fp16.py` adds a boundary-fix pass that tracks dtypes and inserts casts; verified vs the JAX reference (max abs diff 1.1e-3, mean 1.8e-4 — visually lossless).
  - Open: on-device tile/overlap evaluation, then a `ModelSpec` entry (task `lowLightEnhancement`, fp16 artifact as the download, fp32 kept for reference). The tuned heuristic pipeline (A2) stays the shipped path until then.

## Hair tint / face parsing (ROADMAP Track B2)

Blocked. Training sets such as CelebAMask-HQ are non-commercial; landmark-built masks stay the shipped path. No candidate has cleared licence review.
