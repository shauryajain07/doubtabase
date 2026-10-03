#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_dir="$project_dir/.build/Recall.app"
asset_path="$project_dir/App/Assets/Doubtabase-logo-v2.png"
app_version="${APP_VERSION:-0.1.0}"
app_build_number="${APP_BUILD_NUMBER:-1}"

if [[ ! "$app_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "APP_VERSION must use a three-part version, such as 0.1.2" >&2
    exit 1
fi
if [[ ! "$app_build_number" =~ ^[0-9]+$ ]]; then
    echo "APP_BUILD_NUMBER must be an integer" >&2
    exit 1
fi

swift build --configuration release
bin_dir="$(swift build --configuration release --show-bin-path)"

rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$bin_dir/RecallMac" "$app_dir/Contents/MacOS/RecallMac"
cp "$project_dir/App/Info.plist" "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $app_version" "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $app_build_number" "$app_dir/Contents/Info.plist"

resource_bundle="$bin_dir/RecallMac_RecallMac.bundle"
if [[ -d "$resource_bundle" ]]; then
    cp -R "$resource_bundle" "$app_dir/Contents/Resources/"
fi

sparkle_framework="$(find "$project_dir/.build/artifacts" -path '*/Sparkle.framework' -type d -print -quit 2>/dev/null || true)"
if [[ -z "$sparkle_framework" ]]; then
    echo "Sparkle.framework was not found in .build/artifacts; make sure SwiftPM resolved the Sparkle dependency." >&2
    exit 1
fi
mkdir -p "$app_dir/Contents/Frameworks"
ditto "$sparkle_framework" "$app_dir/Contents/Frameworks/Sparkle.framework"

iconset_parent="$(mktemp -d "${TMPDIR:-/tmp}/doubtabase-iconset.XXXXXX")"
iconset_dir="$iconset_parent/Doubtabase.iconset"
mkdir -p "$iconset_dir"
trap 'rm -rf "$iconset_parent"' EXIT
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$asset_path" --out "$iconset_dir/icon_${size}x${size}.png" >/dev/null
done
sips -z 32 32 "$asset_path" --out "$iconset_dir/icon_16x16@2x.png" >/dev/null
sips -z 64 64 "$asset_path" --out "$iconset_dir/icon_32x32@2x.png" >/dev/null
sips -z 256 256 "$asset_path" --out "$iconset_dir/icon_128x128@2x.png" >/dev/null
sips -z 512 512 "$asset_path" --out "$iconset_dir/icon_256x256@2x.png" >/dev/null
sips -z 1024 1024 "$asset_path" --out "$iconset_dir/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$iconset_dir" -o "$app_dir/Contents/Resources/Doubtabase.icns"

if command -v codesign >/dev/null 2>&1; then
    if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
        codesign --force --deep --options runtime --timestamp --sign "$CODESIGN_IDENTITY" "$app_dir" >/dev/null
    else
        codesign --force --deep --sign - "$app_dir" >/dev/null
    fi
fi

printf 'Built %s (%s, build %s)\n' "$app_dir" "$app_version" "$app_build_number"
