#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

require_pattern() {
  local file="$1"
  local pattern="$2"
  if ! grep -Eq "$pattern" "$ROOT/$file"; then
    echo "missing pattern in $file: $pattern" >&2
    exit 1
  fi
}

require_absent() {
  local file="$1"
  local pattern="$2"
  if grep -Eq "$pattern" "$ROOT/$file"; then
    echo "unexpected pattern in $file: $pattern" >&2
    exit 1
  fi
}

require_pattern "Sources/NotchAgent/SettingsView.swift" 'case timeline'
require_pattern "Sources/NotchAgent/SettingsView.swift" 'case approvals'
require_pattern "Sources/NotchAgent/SettingsView.swift" 'case metrics'
require_pattern "Sources/NotchAgent/SettingsView.swift" 'TimelinePage'
require_pattern "Sources/NotchAgent/SettingsView.swift" 'ApprovalsPage'
require_pattern "Sources/NotchAgent/SettingsView.swift" 'MetricsPage'
require_pattern "Sources/NotchAgent/AppState.swift" 'recordTimelineEvent'
require_pattern "Sources/NotchAgent/AppState.swift" 'timelineEvents'
require_pattern "Sources/NotchAgent/AppState.swift" 'sessionMetrics'
require_pattern "Sources/NotchAgent/AppState.swift" 'approvalRules'
require_pattern "Sources/NotchAgent/AppState.swift" 'approvalPauseUntil'
require_pattern "Sources/NotchAgent/AppState.swift" 'approvalPauseUntil != nil'
require_pattern "Sources/NotchAgent/AppState.swift" 'matchedApprovalRule'
require_pattern "Sources/NotchAgent/Models.swift" 'struct TimelineEvent'
require_pattern "Sources/NotchAgent/Models.swift" 'struct SessionMetrics'
require_pattern "Sources/NotchAgent/Models.swift" 'struct ApprovalRule'
require_pattern "Sources/NotchAgent/Settings.swift" 'approvalRules'
require_pattern "Sources/NotchAgent/Settings.swift" 'approvalPauseUntil'
require_absent "Sources/NotchAgent/NotchPanelView.swift" 'MascotView\(source: "claude", status: \.idle'

echo "agent control feature checks passed"
