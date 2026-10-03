#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
plist_path="$project_dir/App/Info.plist"
private_key_path="$project_dir/.build/sparkle-private-key"

swift package resolve --package-path "$project_dir"

sparkle_framework="$(find "$project_dir/.build/artifacts" -path '*/Sparkle.framework' -type d -print -quit 2>/dev/null || true)"
if [[ -z "$sparkle_framework" ]]; then
    echo "Sparkle.framework was not found after resolving package dependencies." >&2
    exit 1
fi
generate_keys="$(find "$project_dir/.build/artifacts" -path '*/bin/generate_keys' -type f -print -quit 2>/dev/null || true)"
if [[ ! -x "$generate_keys" ]]; then
    echo "Sparkle's generate_keys tool was not found." >&2
    exit 1
fi

existing_public_key="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$plist_path" 2>/dev/null || true)"
if [[ -n "$existing_public_key" ]]; then
    echo "Doubtabase already has a Sparkle public key. Export its matching private key from your keychain with Sparkle's generate_keys tool if needed."
    exit 0
fi

key_output="$("$generate_keys")"
public_key="$(printf '%s\n' "$key_output" | grep -Eo '[A-Za-z0-9+/]{43}=' | tail -n 1 || true)"
if [[ -z "$public_key" ]]; then
    printf '%s\n' "$key_output" >&2
    echo "Could not read the public key from generate_keys output." >&2
    exit 1
fi

mkdir -p "$(dirname "$private_key_path")"
"$generate_keys" -x "$private_key_path" >/dev/null
chmod 600 "$private_key_path"
/usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $public_key" "$plist_path"

cat <<EOF
Sparkle signing is ready.

Public key added to App/Info.plist. The private key is stored at:
  $private_key_path

Add it to this GitHub repository's Actions secrets:
  gh secret set SPARKLE_PRIVATE_ED_KEY < .build/sparkle-private-key

Keep the private key backed up securely and never commit it.
EOF
