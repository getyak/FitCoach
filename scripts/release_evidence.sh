#!/bin/bash

set -euo pipefail

usage() {
    echo "Usage: $0 <result.xcresult> <archive.xcarchive>" >&2
    exit 64
}

[[ $# -eq 2 ]] || usage

result_path="$1"
archive_path="$2"
repo_root="$(git rev-parse --show-toplevel)"
app_path="$archive_path/Products/Applications/FitCoach.app"
extension_path="$app_path/PlugIns/FitCoachLiveActivity.appex"
binary_path="$app_path/FitCoach"
dsym_binary="$archive_path/dSYMs/FitCoach.app.dSYM/Contents/Resources/DWARF/FitCoach"

[[ -d "$result_path" ]] || { echo "Missing xcresult: $result_path" >&2; exit 66; }
[[ -d "$archive_path" ]] || { echo "Missing archive: $archive_path" >&2; exit 66; }
[[ -d "$app_path" ]] || { echo "Missing app in archive" >&2; exit 66; }
[[ -d "$extension_path" ]] || { echo "Missing Live Activity extension" >&2; exit 65; }
[[ -f "$app_path/PrivacyInfo.xcprivacy" ]] || { echo "Missing PrivacyInfo.xcprivacy" >&2; exit 65; }
[[ -f "$dsym_binary" ]] || { echo "Missing app dSYM" >&2; exit 65; }

cd "$repo_root"
if [[ -n "$(git status --porcelain)" ]]; then
    echo "Release evidence requires a clean worktree." >&2
    exit 65
fi

commit="$(git rev-parse HEAD)"
embedded_commit="$(/usr/libexec/PlistBuddy -c 'Print :FitCoachGitCommit' "$app_path/Info.plist" 2>/dev/null || true)"
if [[ "$embedded_commit" != "$commit" ]]; then
    echo "Archive commit mismatch: embedded '$embedded_commit', current '$commit'." >&2
    exit 65
fi

summary() {
    xcrun xcresulttool get test-results summary --path "$result_path" --format json \
        | plutil -extract "$1" raw -o - -
}

result="$(summary result)"
passed="$(summary passedTests)"
failed="$(summary failedTests)"
skipped="$(summary skippedTests)"
[[ "$result" == "Passed" && "$failed" == "0" && "$skipped" == "0" ]] || {
    echo "Tests are not release-green: result=$result failed=$failed skipped=$skipped" >&2
    exit 65
}

codesign --verify --deep --strict "$app_path"
app_uuid="$(dwarfdump --uuid "$binary_path" | awk 'NR == 1 { print $2 }')"
dsym_uuid="$(dwarfdump --uuid "$dsym_binary" | awk 'NR == 1 { print $2 }')"
[[ -n "$app_uuid" && "$app_uuid" == "$dsym_uuid" ]] || {
    echo "dSYM UUID mismatch: app=$app_uuid dSYM=$dsym_uuid" >&2
    exit 65
}

authority="$(codesign -dvv "$app_path" 2>&1 | sed -n 's/^Authority=//p' | head -1)"
get_task_allow="$(codesign -d --entitlements :- "$app_path" 2>/dev/null \
    | plutil -extract get-task-allow raw -o - - 2>/dev/null || echo absent)"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_path/Info.plist")"
build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app_path/Info.plist")"
archive_hash="$(shasum -a 256 "$binary_path" | awk '{ print $1 }')"

cat <<REPORT
# FitCoach Release Evidence

- Generated (UTC): $(date -u '+%Y-%m-%dT%H:%M:%SZ')
- Commit: $commit
- Worktree: clean
- Tests: $passed passed, $failed failed, $skipped skipped
- Version: $version ($build)
- App binary SHA-256: $archive_hash
- App UUID: $app_uuid
- dSYM UUID: $dsym_uuid
- Live Activity extension: present
- Privacy manifest: present
- Signing authority: $authority
- get-task-allow: $get_task_allow

The script validates archive structure and local signing integrity. A development
authority or get-task-allow=true is not an App Store distribution proof; Organizer
upload, App Store Connect validation, and processing remain separate gates.
REPORT
