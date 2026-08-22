#!/bin/bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
metadata_dir="$repo_root/docs/app-store/zh-Hans"
screenshot_dir="$repo_root/docs/app-store/screenshots/6.9-inch"

require_file() {
    [[ -s "$1" ]] || { echo "Missing or empty required file: $1" >&2; exit 65; }
}

character_count() {
    ruby -e 'print File.read(ARGV.fetch(0), encoding: "UTF-8").strip.length' "$1"
}

byte_count() {
    ruby -e 'print File.read(ARGV.fetch(0), encoding: "UTF-8").strip.bytesize' "$1"
}

assert_max() {
    local label="$1"
    local actual="$2"
    local maximum="$3"
    if (( actual > maximum )); then
        echo "$label exceeds its App Store limit: $actual > $maximum" >&2
        exit 65
    fi
}

subtitle="$metadata_dir/subtitle.txt"
keywords="$metadata_dir/keywords.txt"
description="$metadata_dir/description.txt"
review_notes="$metadata_dir/review-notes.txt"

for path in "$subtitle" "$keywords" "$description" "$review_notes"; do
    require_file "$path"
done

assert_max "Subtitle characters" "$(character_count "$subtitle")" 30
assert_max "Keywords bytes" "$(byte_count "$keywords")" 100
assert_max "Description characters" "$(character_count "$description")" 4000
assert_max "Review notes bytes" "$(byte_count "$review_notes")" 4000

privacy_page="$repo_root/docs/privacy.html"
support_page="$repo_root/docs/support.html"
require_file "$privacy_page"
require_file "$support_page"
grep -Fq '<html lang="zh-Hans">' "$privacy_page"
grep -Fq '<html lang="zh-Hans">' "$support_page"
grep -Fq 'privacy.html' "$support_page"
grep -Fq 'github.com/getyak/FitCoach/issues' "$support_page"

screenshots=()
while IFS= read -r screenshot; do
    screenshots+=("$screenshot")
done < <(find "$screenshot_dir" -maxdepth 1 -type f -name '*.png' | sort)
if (( ${#screenshots[@]} < 1 || ${#screenshots[@]} > 10 )); then
    echo "Expected 1–10 screenshots, found ${#screenshots[@]}." >&2
    exit 65
fi

for screenshot in "${screenshots[@]}"; do
    width="$(sips -g pixelWidth "$screenshot" | awk '/pixelWidth/ { print $2 }')"
    height="$(sips -g pixelHeight "$screenshot" | awk '/pixelHeight/ { print $2 }')"
    alpha="$(sips -g hasAlpha "$screenshot" | awk '/hasAlpha/ { print $2 }')"
    [[ "$width" == "1320" && "$height" == "2868" ]] || {
        echo "Invalid 6.9-inch screenshot size for $screenshot: ${width}x${height}" >&2
        exit 65
    }
    [[ "$alpha" == "no" ]] || {
        echo "Screenshot must not contain alpha: $screenshot" >&2
        exit 65
    }
done

echo "App Store assets verified"
echo "- subtitle: $(character_count "$subtitle")/30 characters"
echo "- keywords: $(byte_count "$keywords")/100 bytes"
echo "- description: $(character_count "$description")/4000 characters"
echo "- review notes: $(byte_count "$review_notes")/4000 bytes"
echo "- screenshots: ${#screenshots[@]} at 1320x2868, no alpha"
