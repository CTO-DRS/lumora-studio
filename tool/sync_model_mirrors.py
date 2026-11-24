#!/usr/bin/env python3
"""Sync the project-hosted model mirrors (ROADMAP §5, v1.3.x).

Downloads every model of `lib/features/ai/domain/model_registry.dart` from
its primary URL, verifies the SHA-256 recorded in the registry, and uploads
the file as a release asset of this repository (tag `models-v1.3`) so the
app has a project-controlled fallback host with the identical file.

Requires the GitHub CLI (`gh`) authenticated with a token that can create
releases on the target repository. Re-running is idempotent: assets are
replaced with `--clobber` and every file is re-verified before upload.

Usage:
  python3 tool/sync_model_mirrors.py            # download, verify, upload
  python3 tool/sync_model_mirrors.py --check    # verify only, no upload
"""

from __future__ import annotations

import argparse
import hashlib
import re
import subprocess
import sys
import urllib.request
from dataclasses import dataclass
from pathlib import Path

REGISTRY = Path(__file__).resolve().parent.parent / "lib/features/ai/domain/model_registry.dart"
OWNER_REPO = "CTO-DRS/lumora-studio"
TAG = "models-v1.3"

CONST = re.compile(r"static const (\w+) = ModelSpec\((.*?)\n  \);", re.S)
FIELD = r"(\w+):\s*'([^']+)'"


@dataclass(frozen=True)
class Model:
    const_name: str
    id: str
    url: str
    sha256: str
    size_bytes: int


def parse_registry() -> list[Model]:
    text = REGISTRY.read_text(encoding="utf-8")
    models: list[Model] = []
    for m in CONST.finditer(text):
        body = m.group(2)
        fields = dict(re.findall(FIELD, body))
        size = re.search(r"sizeBytes:\s*(\d+)", body)
        if "url" not in fields or "sha256" not in fields or not size:
            continue
        models.append(
            Model(
                const_name=m.group(1),
                id=fields["id"],
                url=fields["url"],
                sha256=fields["sha256"],
                size_bytes=int(size.group(1)),
            )
        )
    return models


def download(url: str, dest: Path) -> None:
    req = urllib.request.Request(url, headers={"User-Agent": "lumora-mirror-sync/1.0"})
    with urllib.request.urlopen(req, timeout=600) as r, dest.open("wb") as f:
        while chunk := r.read(1 << 20):
            f.write(chunk)


def sha256_of(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        while chunk := f.read(1 << 20):
            h.update(chunk)
    return h.hexdigest()


def gh(*args: str) -> None:
    subprocess.run(["gh", *args], check=True)


def ensure_release() -> None:
    try:
        subprocess.run(
            ["gh", "release", "view", TAG, "--repo", OWNER_REPO],
            check=True,
            capture_output=True,
        )
    except subprocess.CalledProcessError:
        print(f"Creating release {TAG} on {OWNER_REPO} ...")
        gh(
            "release", "create", TAG,
            "--repo", OWNER_REPO,
            "--title", "Model mirrors (v1.3)",
            "--notes",
            "Automatic fallback host for on-device model downloads. "
            "Every asset is byte-identical (same SHA-256) to the pinned "
            "primary URL recorded in lib/features/ai/domain/model_registry.dart. "
            "Regenerate with tool/sync_model_mirrors.py.",
        )


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="verify only, do not upload")
    args = ap.parse_args()

    models = parse_registry()
    if not models:
        print("ERROR: no models parsed from the registry", file=sys.stderr)
        return 1

    work = Path(__file__).resolve().parent / ".model_mirror_cache"
    work.mkdir(exist_ok=True)
    ok = True
    verified: list[tuple[Model, Path]] = []
    for model in models:
        dest = work / f"{model.id}.onnx"
        if dest.exists() and dest.stat().st_size == model.size_bytes:
            print(f"{model.id}: cached, skipping download")
        else:
            print(f"{model.id}: downloading {model.url}")
            try:
                download(model.url, dest)
            except Exception as e:  # noqa: BLE001 - report and continue
                print(f"{model.id}: DOWNLOAD FAILED: {e}", file=sys.stderr)
                ok = False
                continue
        digest = sha256_of(dest)
        if digest != model.sha256:
            print(f"{model.id}: CHECKSUM MISMATCH (expected {model.sha256}, got {digest})", file=sys.stderr)
            dest.unlink()
            ok = False
            continue
        print(f"{model.id}: verified {model.size_bytes} bytes, sha256 OK")
        verified.append((model, dest))

    if args.check:
        print(f"{len(verified)}/{len(models)} models verified against the registry")
        return 0 if ok else 1

    if not ok:
        print("Refusing to upload: some models failed verification.", file=sys.stderr)
        return 1

    ensure_release()
    for model, dest in verified:
        print(f"{model.id}: uploading as {dest.name}")
        gh("release", "upload", TAG, str(dest), "--repo", OWNER_REPO, "--clobber")
    print(f"Done. {len(verified)} mirrors published under https://github.com/{OWNER_REPO}/releases/tag/{TAG}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
