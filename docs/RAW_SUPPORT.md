# RAW & pro export support matrix

Status as of commit after v0.1.0 reset (Track A3). Everything runs on-device; nothing here touches the network.

## RAW import (DNG / TIFF)

A picked `.dng` / `.tif` / `.tiff` goes through `importDng`: TIFF header sniff → structured parse → CFA classification → decode on an isolate. Failures never crash: corrupt files return a plain-language message, undecodable raw payloads fall back to the largest embedded preview JPEG and the UI says so honestly.

| Payload | Support | Notes |
|---|---|---|
| Uncompressed CFA strips | Full decode | black/white-level normalisation, bilinear demosaic |
| Adobe-deflate CFA strips | Full decode | in-house inflate path |
| Lossless JPEG (SOF3) CFA strips | Full decode | in-house T.81 lossless decoder; the phone-default compression |
| Lossy JPEG DNG | Preview fallback | embedded preview shown, reason surfaced |
| Other/exotic payloads | Preview fallback or honest failure | never a crash |

CFA bit depths: 8, 12, 14 and 16-bit samples (32-bit float rejected cleanly). Bayer patterns: RGGB family, 2x2 and larger repeats. Colour: DNG `AsShotNeutral` white balance, `ColorMatrix1` inverted and Y-normalised, Bradford adaptation to D65, linear-sRGB render with highlight recovery; files without colour metadata keep a legacy identity path. Negative `ColorMatrix` coefficients (SRATIONAL) are read signed.

Non-DNG TIFFs routed into the importer get the same parse; a TIFF without a CFA IFD reports "not a RAW" instead of failing oddly.

## Export formats

| Format | Bit depth | Alpha | Quality slider | EXIF carry-over | Notes |
|---|---|---|---|---|---|
| JPG | 8 | dropped | yes | yes (descriptive tags, orientation baked) | default |
| PNG | 8 | kept (4ch) | no | no | lossless, also the intermediate for WebP/HEIC |
| PNG 16 | 16 (v·257 from RGBA8) | dropped (RGB) | no | no | sRGB chunk, filter-0 scanlines, zlib |
| TIFF (16-bit) | 16 (v·257 from RGBA8) | dropped (RGB) | no | no | uncompressed strips ~1 MB, readable by the app's own parser |
| WebP | 8 | platform encoder | yes | no | platform encoder via PNG intermediate |
| HEIC | 8 | platform encoder | yes | no | platform encoder via PNG intermediate |

The editor's working data is RGBA8; the 16-bit containers expand each channel byte with v·257 so 0x00→0 and 0xFF→65535 exactly. They exist so a finished edit round-trips into desktop pro tools (darktable, Lightroom, DaVinci Resolve) without an 8-bit container ceiling — they do not claim more precision than the pipeline holds. Social-size exports (Instagram/X/WhatsApp presets) force JPG at the preset's quality.

## Verification

- `test/unit/png16_writer_test.dart`: chunk structure + CRC, filter-0 big-endian v·257 round-trip, exact 0/65535 endpoints, decode by the `image` package, invalid buffers raise.
- `test/unit/finishing_and_pixels_test.dart`: TIFF16 round-trip through the app's own `TiffDocument.parse`.
- RAW import: unit coverage for the decoder, colour pipeline and fuzz gates lives in `test/unit/pipelines_test.dart` and the raw test files; corrupt/truncated files raise typed exceptions, never crash.
