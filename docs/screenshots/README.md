# Screenshots

The PNGs here are rendered from the app's own widgets by the screenshot
harness in `test/screenshots/screenshots_test.dart` (Arabic, dark theme,
390×844 at 2×). `design/` holds the approved v1.2 design mockups.

The harness is skipped in normal test runs. To regenerate:

```bash
# Fonts: any TTFs covering Latin + Arabic (e.g. Tajawal from Google Fonts)
# Sample photos: thumb0-3.jpg, city.jpg, face.jpg and pt_*.png
LUMORA_SCREENSHOTS=docs/screenshots/out \
LUMORA_FONTS=/path/to/fonts \
LUMORA_SHOT_ASSETS=/path/to/sample/photos \
flutter test test/screenshots
```

Set `LUMORA_SHOT_LOCALE=en` for English captures. Rename the outputs to the
file names used in the main README (`home.png`, `photo_editor.png`,
`ai_tools.png`, `templates.png`).
