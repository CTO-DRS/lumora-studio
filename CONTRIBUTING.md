# Contributing to Lumora Studio · المساهمة في لومورا ستوديو

Thanks for helping build the best open-source on-device editor! · شكراً لمساهمتك!

## Ground rules
1. **Privacy is non-negotiable.** No analytics, crash reporters, cloud APIs, Firebase or Google Play Services / ML Kit. Network access is only allowed for downloading AI models listed in `ModelRegistry`, always with a SHA-256 checksum.
2. **Non-destructive editing.** New tools must be expressed as data in `EditState` / `VideoProject` (freezed, JSON-serializable) and rendered by the engine, so undo/redo and project restore work automatically.
3. **GPU first.** Per-pixel work belongs in a fragment shader (`shaders/`). CPU fallbacks run in isolates (`Isolate.run` / `compute`).
4. **Bilingual.** Every user-facing string goes in `lib/l10n/app_en.arb` **and** `app_ar.arb`. Test RTL layouts.

## Workflow
```bash
flutter pub get
dart run build_runner watch    # keep codegen running while you work
flutter gen-l10n
flutter analyze                # must report "No issues found!"
dart format lib test           # page width 120 (analysis_options.yaml)
flutter test
```
- Branch from `main`, keep PRs focused, and add tests: domain logic needs unit tests, widgets need widget tests, and shader changes should extend `test/unit/render_pipeline_test.dart`.
- Use [Conventional Commits](https://www.conventionalcommits.org/) (`feat(photo): add tone-mapping curve`).
- When you bump a dependency, check its latest version on pub.dev and update `docs/DEPENDENCIES.md`.

## Adding an AI model
1. Add a `ModelSpec` to `ModelRegistry` with a public HTTPS URL, the exact byte size, the SHA-256 (the Hugging Face LFS `oid`) and the license.
2. Implement the pre/post-processing in `lib/features/ai/pipelines/` using the pure helpers in `tensor_utils.dart`, and unit test them with a fake `InferenceEngine`.
3. Document the I/O contract (names, shapes, ranges) in `ModelSpec.notes`.

## Adding a shader effect
1. Add uniforms to the relevant `.frag` (or a new pass registered in `pubspec.yaml` and `ShaderLibrary`).
2. Follow the GLES convention: flip `uv.y` under `IMPELLER_TARGET_OPENGLES` for every texture that comes from a previous render pass (see `docs/ARCHITECTURE.md`).
3. Add the parameter to `Adjustments` and `AdjustmentParam`, plus a slider and both translations.
