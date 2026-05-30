#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

FEED_URL="$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' Info.plist)"
EXPECTED_FEED_URL="https://github.com/tame-gg/NotchAgent/releases/latest/download/appcast.xml"

if [[ "$FEED_URL" != "$EXPECTED_FEED_URL" ]]; then
    echo "SUFeedURL must point at the latest GitHub Releases appcast asset" >&2
    echo "expected: $EXPECTED_FEED_URL" >&2
    echo "actual:   $FEED_URL" >&2
    exit 1
fi

require_pattern() {
    local file="$1"
    local pattern="$2"
    if ! rg -q "$pattern" "$file"; then
        echo "Missing expected pattern in $file: $pattern" >&2
        exit 1
    fi
}

require_absent() {
    local pattern="$1"
    if rg --hidden -n "$pattern" . \
        -g '!/.git/**' \
        -g '!/.build/**' \
        -g '!/.superpowers/**' \
        -g '!Package.resolved'; then
        echo "Unexpected stale update/release pattern remains: $pattern" >&2
        exit 1
    fi
}

require_pattern "scripts/update-appcast.sh" "https://github.com/tame-gg/NotchAgent/releases/download/v"
require_pattern "scripts/update-appcast.sh" "https://github.com/tame-gg/NotchAgent/releases/latest/download/appcast.xml"
require_pattern ".github/workflows/release.yml" "on:"
require_pattern ".github/workflows/release.yml" "tags:"
require_pattern ".github/workflows/release.yml" "v\\*"
require_pattern ".github/workflows/release.yml" "SPARKLE_PRIVATE_KEY"
require_pattern ".github/workflows/release.yml" "scripts/build-dmg.sh"
require_pattern ".github/workflows/release.yml" "scripts/update-appcast.sh"
require_pattern ".github/workflows/release.yml" "gh release"
require_pattern ".github/workflows/release.yml" "NotchAgent.dmg"
require_pattern ".github/workflows/release.yml" "appcast.xml"

legacy_repo='wxt''sky/Code''Island'
wrong_owner='tame''gg/NotchAgent'
old_feed='tame.gg/notch''agent/appcast.xml'

require_absent "$legacy_repo"
require_absent "github.com/$wrong_owner"
require_absent "$old_feed"

echo "github release update checks passed"
