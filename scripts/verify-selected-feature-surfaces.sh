#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

require_pattern() {
    local file="$1"
    local pattern="$2"
    if ! rg -q "$pattern" "$file"; then
        echo "Missing expected pattern in $file: $pattern" >&2
        exit 1
    fi
}

require_pattern "Sources/NotchAgent/SettingsView.swift" "ReleaseNotesView"
require_pattern "Sources/NotchAgent/SettingsView.swift" "GitHubReleaseNotes"
require_pattern "Sources/NotchAgent/SettingsView.swift" "HookDiagnosticsPanel"
require_pattern "Sources/NotchAgent/SettingsView.swift" "HookDiagnosticItem"
require_pattern "Sources/NotchAgent/SettingsView.swift" "AgentComparisonSummary"
require_pattern "Sources/NotchAgent/SettingsView.swift" "CustomMascotImage"
require_pattern "Sources/NotchAgent/Settings.swift" "customMascotPath"
require_pattern "Sources/NotchAgent/MascotView.swift" "CustomMascotImage"
require_pattern "scripts/build-dmg.sh" "notchagent-cli"
require_pattern "build.sh" "notchagent-cli"
require_pattern "Sources/NotchAgentCLI/main.swift" "sunPathCapacity"
require_pattern "Sources/NotchAgentCore/CostEstimator.swift" "1_000_000.0"
require_pattern "Sources/NotchAgent/SettingsView.swift" "primaryCLIName = \"notchagent\""
require_pattern "Sources/NotchAgent/SettingsView.swift" "legacyCLIName = \"notchagent-cli\""
require_pattern "Sources/NotchAgent/SettingsView.swift" "Contents/Helpers"
require_pattern "Sources/NotchAgent/SettingsView.swift" "notchagent status"

old_app='Code''Island'
old_app_lower='code''island'
wrong_cli='Code''Agent'
removed_feature_a='rem''ote'
removed_feature_b='bud''dy'

if rg -n "$wrong_cli|$old_app|$old_app_lower" Sources/NotchAgent Sources/NotchAgentCore Sources/NotchAgentCLI scripts build.sh Package.swift \
    -g '!Resources/cli-icons/*.png'; then
    echo "Unexpected stale branding remains in app sources or scripts" >&2
    exit 1
fi

if rg -n -i "$removed_feature_a|$removed_feature_b" Sources/NotchAgent Sources/NotchAgentCore Sources/NotchAgentCLI README.md Package.swift \
    -g '!Resources/cli-icons/*.png'; then
    echo "Unexpected removed feature references remain in app sources" >&2
    exit 1
fi

echo "selected feature surface checks passed"
