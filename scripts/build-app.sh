#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_dir="$project_dir/.build/Recall.app"
asset_path="$project_dir/App/Assets/Doubtabase-logo-v2.png"
swift build --configuration release
bin_dir="$(swift build --configuration release --show-bin-path)"

rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$bin_dir/RecallMac" "$app_dir/Contents/MacOS/RecallMac"
cp "$project_dir/App/Info.plist" "$app_dir/Contents/Info.plist"

resource_bundle="$bin_dir/RecallMac_RecallMac.bundle"
if [[ -d "$resource_bundle" ]]; then
    cp -R "$resource_bundle" "$app_dir/Contents/Resources/"
fi

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
    codesign --force --deep --sign - "$app_dir" >/dev/null
fi

printf 'Built %s\n' "$app_dir"
