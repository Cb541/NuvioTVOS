#!/bin/bash
# Fetch the MPVKit 1.0.0 binary dependencies used by Nuvio tvOS.
# The component repositories use their own release versions, so each
# framework carries its exact repository/version pair here.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR="$ROOT/Vendor"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# repo | framework name | release version
FRAMEWORKS=(
  "mpvkit/MPVKit|Libmpv|1.0.0"
  "mpvkit/MPVKit|Libavcodec|1.0.0"
  "mpvkit/MPVKit|Libavdevice|1.0.0"
  "mpvkit/MPVKit|Libavfilter|1.0.0"
  "mpvkit/MPVKit|Libavformat|1.0.0"
  "mpvkit/MPVKit|Libavutil|1.0.0"
  "mpvkit/MPVKit|Libswresample|1.0.0"
  "mpvkit/MPVKit|Libswscale|1.0.0"

  "mpvkit/gnutls-build|gmp|3.8.11"
  "mpvkit/gnutls-build|gnutls|3.8.11"
  "mpvkit/gnutls-build|hogweed|3.8.11"
  "mpvkit/gnutls-build|nettle|3.8.11"

  "mpvkit/lcms2-build|lcms2|2.17.0"

  "mpvkit/libass-build|Libass|0.17.5"
  "mpvkit/libass-build|Libfreetype|0.17.5"
  "mpvkit/libass-build|Libfribidi|0.17.5"
  "mpvkit/libass-build|Libharfbuzz|0.17.5"
  "mpvkit/libass-build|Libunibreak|0.17.5"

  "mpvkit/libbluray-build|Libbluray|1.4.0"
  "mpvkit/libdav1d-build|Libdav1d|1.5.3"
  "mpvkit/libdovi-build|Libdovi|3.3.2"
  "mpvkit/libplacebo-build|Libplacebo|7.360.1"
  "mpvkit/libshaderc-build|Libshaderc_combined|2025.5.0"
  "mpvkit/libuavs3d-build|Libuavs3d|1.2.1-fix"
  "mpvkit/libuchardet-build|Libuchardet|0.0.8"
  "mpvkit/moltenvk-build|MoltenVK|1.4.2"

  "mpvkit/openssl-build|Libcrypto|3.3.5"
  "mpvkit/openssl-build|Libssl|3.3.5"
)

mkdir -p "$VENDOR"

echo "Fetching ${#FRAMEWORKS[@]} xcframeworks into Vendor/..."

for entry in "${FRAMEWORKS[@]}"; do
    IFS='|' read -r repo name version <<< "$entry"

    if [[ -d "$VENDOR/$name.xcframework" ]]; then
        echo "  ✓ $name (already present)"
        continue
    fi

    url="https://github.com/$repo/releases/download/$version/$name.xcframework.zip"
    zip="$TMP/$name.xcframework.zip"

    echo "  ↓ $name"
    echo "    $url"

    curl --fail --location --retry 3 --retry-delay 2 \
        --output "$zip" \
        "$url"

    unzip -q -o "$zip" -d "$VENDOR"
done

echo
echo "Trimming frameworks to tvOS slices..."

python3 - "$VENDOR" <<'PY'
import pathlib
import plistlib
import shutil
import sys

vendor = pathlib.Path(sys.argv[1])

for framework in sorted(vendor.glob("*.xcframework")):
    for slice_dir in list(framework.iterdir()):
        if slice_dir.is_dir() and not slice_dir.name.startswith("tvos"):
            shutil.rmtree(slice_dir)

    plist = framework / "Info.plist"
    if not plist.exists():
        continue

    data = plistlib.loads(plist.read_bytes())

    data["AvailableLibraries"] = [
        lib
        for lib in data.get("AvailableLibraries", [])
        if (framework / lib["LibraryIdentifier"]).exists()
    ]

    plist.write_bytes(plistlib.dumps(data))

    if not data["AvailableLibraries"]:
        raise SystemExit(f"ERROR: {framework.name} has no tvOS slice")

print("All frameworks have valid tvOS slices.")
PY

echo
echo "Done."
echo "Vendor size: $(du -sh "$VENDOR" | cut -f1)"
echo "Framework count: $(find "$VENDOR" -maxdepth 1 -name '*.xcframework' -type d | wc -l)"
