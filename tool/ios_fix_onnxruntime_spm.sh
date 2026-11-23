#!/usr/bin/env bash
# Makes the iOS build independent of download.onnxruntime.ai.
#
# Why: flutter_onnxruntime (Swift Package Manager integration) depends on
# github.com/masicai/onnxruntime-swift-package-manager. That package declares
# TWO binary targets and SwiftPM downloads both while resolving, even though
# the plugin only links `onnxruntime`:
#   * onnxruntime            -> github.com release asset (fine)
#   * onnxruntime_extensions -> https://download.onnxruntime.ai/pod-archive-onnxruntime-extensions-c-0.13.0.zip
# download.onnxruntime.ai currently serves a TLS certificate for
# *.azureedge.net (hostname mismatch), so the download fails and with it the
# whole iOS build. Switching to CocoaPods does not help: the onnxruntime-c /
# onnxruntime-objc pods are fetched from the same host.
#
# What: clone the package at the pinned tag, remove the unused
# onnxruntime_extensions product/targets (its archive is no longer downloadable
# anywhere: v1.3.0 used Microsoft's origin storage, which now returns 404), and
# make the plugin depend on that local checkout instead of the remote URL.
# Idempotent; safe to run repeatedly.
#
# Usage (macOS, after `flutter pub get`):  bash tool/ios_fix_onnxruntime_spm.sh
set -euo pipefail

ORT_SPM_REPO="https://github.com/masicai/onnxruntime-swift-package-manager"
ORT_SPM_TAG="${ORT_SPM_TAG:-1.28.0}"

root="$(cd "$(dirname "$0")/.." && pwd)"
cfg="$root/.dart_tool/package_config.json"
if [[ ! -f "$cfg" ]]; then
  (cd "$root" && flutter pub get)
fi

plugin_dir="$(python3 - "$cfg" <<'PY'
import json, sys, os
from urllib.parse import urlparse, unquote
cfg = sys.argv[1]
for p in json.load(open(cfg))["packages"]:
    if p["name"] == "flutter_onnxruntime":
        uri = p["rootUri"]
        if uri.startswith("file://"):
            print(unquote(urlparse(uri).path))
        else:
            print(os.path.normpath(os.path.join(os.path.dirname(cfg), unquote(uri))))
        break
PY
)"
pkg="$plugin_dir/ios/flutter_onnxruntime/Package.swift"
if [[ ! -f "$pkg" ]]; then
  echo "ios_fix_onnxruntime_spm: $pkg not found (plugin layout changed?)" >&2
  exit 1
fi

dest="${ORT_SPM_DIR:-$HOME/.lumora-spm/onnxruntime-swift-package-manager}"
if [[ ! -f "$dest/Package.swift" ]]; then
  rm -rf "$dest"
  mkdir -p "$(dirname "$dest")"
  for i in 1 2 3; do
    git clone --quiet --depth 1 --branch "$ORT_SPM_TAG" "$ORT_SPM_REPO" "$dest" && break
    echo "clone attempt $i failed; retrying" >&2
    rm -rf "$dest"
    sleep 10
  done
fi
[[ -f "$dest/Package.swift" ]] || { echo "ios_fix_onnxruntime_spm: clone failed" >&2; exit 1; }

# 1) Drop onnxruntime_extensions entirely. flutter_onnxruntime only links the
#    `onnxruntime` product, but SwiftPM downloads every binary target while
#    resolving. The extensions archive has moved/vanished from both
#    download.onnxruntime.ai (bad TLS cert) and Microsoft's origin storage (404),
#    so we remove its product, targets and binary target from the local copy.
python3 - "$dest/Package.swift" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = re.sub(r'\s*\.library\(name:\s*"onnxruntime_extensions",.*?\]\),', '', s, flags=re.S)
s = re.sub(r'\s*\.target\(name:\s*"OnnxRuntimeExtensions",.*?\]\),', '', s, flags=re.S)
s = re.sub(r'\s*\.testTarget\(name:\s*"OnnxRuntimeExtensionsTests",.*?\]\),', '', s, flags=re.S)
i = s.find('if let ext_pod_archive_path')
if i != -1:
    s = s[:i].rstrip() + "\n// onnxruntime_extensions removed by Lumora (unused, archive unavailable).\n"
open(p, 'w').write(s)
PY
if grep -qE 'onnxruntime_extensions"|OnnxRuntimeExtensions|pod-archive-onnxruntime-extensions' "$dest/Package.swift"; then
  echo "ios_fix_onnxruntime_spm: could not strip onnxruntime_extensions from Package.swift" >&2
  grep -nE 'extensions|Extensions' "$dest/Package.swift" >&2 || true
  exit 1
fi

# 2) Plugin -> local checkout (the directory name keeps the package identity
#    "onnxruntime-swift-package-manager" that the plugin's products refer to).
perl -0pi -e 's#\.package\(\s*url:\s*"https://github\.com/masicai/onnxruntime-swift-package-manager(?:\.git)?"\s*,\s*exact:\s*"[^"]+"\s*\)#.package(path: "'"$dest"'")#g' "$pkg"
if ! grep -qF ".package(path: \"$dest\")" "$pkg"; then
  echo "ios_fix_onnxruntime_spm: could not patch $pkg - check the plugin's Package.swift" >&2
  grep -n "\.package(" "$pkg" >&2 || true
  exit 1
fi

# Stale resolutions of the remote package would be reused otherwise.
rm -rf "$root/ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved" \
       "$root/ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.resolved" 2>/dev/null || true

echo "ios_fix_onnxruntime_spm: flutter_onnxruntime now uses $dest (onnxruntime_extensions removed)"
