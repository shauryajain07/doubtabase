#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_dir="$project_dir/.build/Recall.app"

swift build --configuration release
rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$project_dir/.build/arm64-apple-macosx/release/RecallMac" "$app_dir/Contents/MacOS/RecallMac"
cp "$project_dir/App/Info.plist" "$app_dir/Contents/Info.plist"

if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$app_dir" >/dev/null
fi

printf 'Built %s\n' "$app_dir"
