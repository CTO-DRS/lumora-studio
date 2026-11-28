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
- **Integration gap (open):** the checkpoint is JAX, not ONNX/LiteRT, and 216 GFLOPs is desktop-class, so it is not yet wired into `model_registry.dart`. Next steps: convert to ONNX (or TFLite) with dynamic shapes, evaluate tile/overlap inference on-device, and only then add a `ModelSpec` entry (task `lowLightEnhancement`, same SHA-256 recorded alongside the converted artifact's own hash). The current tuned heuristic pipeline (A2) stays the shipped path until then.

## Hair tint / face parsing (ROADMAP Track B2)

Blocked. Training sets such as CelebAMask-HQ are non-commercial; landmark-built masks stay the shipped path. No candidate has cleared licence review.
