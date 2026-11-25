#!/usr/bin/env python3
"""Downloads the pinned model files and verifies them for the mirror release.

Input: TSV lines of <url>\\t<sha256>\\t<asset name> (from tool/mirror_models.dart).
Output: one file per model, named after the mirror asset, in --out.

Every file is hashed with SHA-256 and compared with the pinned checksum; a
mismatch aborts with a non-zero exit so a broken mirror can never be
published. Run in CI by .github/workflows/mirror_models.yml.
"""
import argparse
import hashlib
import sys
import urllib.request
from pathlib import Path


def fetch(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "lumora-mirror/1.0"})
    with urllib.request.urlopen(req, timeout=600) as r:
        return r.read()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("tsv", help="TSV from tool/mirror_models.dart")
    ap.add_argument("--out", default="download", help="output directory")
    args = ap.parse_args()

    lines = [ln.strip() for ln in Path(args.tsv).read_text().splitlines() if ln.strip()]
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    ok = 0
    for i, ln in enumerate(lines, 1):
        url, sha, name = ln.split("\t")
        print(f"[{i}/{len(lines)}] {name}  <-  {url}")
        data = fetch(url)
        actual = hashlib.sha256(data).hexdigest()
        if actual != sha:
            print(f"  CHECKSUM MISMATCH: expected {sha}, got {actual}", file=sys.stderr)
            return 1
        (out / name).write_bytes(data)
        print(f"  OK  {len(data)} bytes  sha256={actual[:16]}…")
        ok += 1

    print(f"verified {ok}/{len(lines)} files in {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
