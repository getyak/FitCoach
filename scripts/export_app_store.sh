#!/bin/bash

set -euo pipefail

usage() {
    echo "Usage: $0 <archive.xcarchive> <output-directory>" >&2
    exit 64
}

[[ $# -eq 2 ]] || usage

archive_path="$1"
output_path="$2"
repo_root="$(git rev-parse --show-toplevel)"
options_path="$repo_root/config/ExportOptions-AppStore.plist"

[[ -d "$archive_path" ]] || { echo "Missing archive: $archive_path" >&2; exit 66; }
[[ -f "$options_path" ]] || { echo "Missing export options: $options_path" >&2; exit 66; }

if [[ -e "$output_path" && -n "$(find "$output_path" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
    echo "Output directory must be absent or empty: $output_path" >&2
    exit 65
fi
mkdir -p "$output_path"

xcodebuild -exportArchive \
    -archivePath "$archive_path" \
    -exportPath "$output_path" \
    -exportOptionsPlist "$options_path" \
    -allowProvisioningUpdates

ipa_path="$(find "$output_path" -maxdepth 1 -name '*.ipa' -print -quit)"
[[ -f "$ipa_path" ]] || { echo "Export completed without an IPA." >&2; exit 65; }

inspection_dir="$(mktemp -d "${TMPDIR:-/tmp}/fitcoach-export.XXXXXX")"
trap 'rm -rf "$inspection_dir"' EXIT
ditto -x -k "$ipa_path" "$inspection_dir"
app_path="$(find "$inspection_dir/Payload" -maxdepth 1 -name '*.app' -type d -print -quit)"
[[ -d "$app_path" ]] || { echo "Exported IPA has no app bundle." >&2; exit 65; }

codesign --verify --deep --strict "$app_path"
authority="$(codesign -dvv "$app_path" 2>&1 | sed -n 's/^Authority=//p' | head -1)"
get_task_allow="$(codesign -d --entitlements :- "$app_path" 2>/dev/null \
    | plutil -extract get-task-allow raw -o - - 2>/dev/null || echo absent)"

if [[ "$authority" != Apple\ Distribution:* && "$authority" != "Apple Distribution" ]]; then
    echo "IPA is not distribution-signed: $authority" >&2
    exit 65
fi
if [[ "$get_task_allow" == "true" ]]; then
    echo "IPA still contains get-task-allow=true." >&2
    exit 65
fi

echo "App Store export verified"
echo "IPA: $ipa_path"
echo "Signing authority: $authority"
echo "get-task-allow: $get_task_allow"
