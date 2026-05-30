import SwiftUI
import AppKit
import UniformTypeIdentifiers
import NotchAgentCore

// MARK: - Navigation Model

enum SettingsPage: String, Identifiable, Hashable {
    case general
    case behavior
    case appearance
    case mascots
    case sound
    case shortcuts
    case timeline
    case approvals
    case metrics
    case cli
    case hooks
    case about

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .behavior: return "slider.horizontal.3"
        case .appearance: return "paintbrush.fill"
        case .mascots: return "person.2.fill"
        case .sound: return "speaker.wave.2.fill"
        case .shortcuts: return "command.circle.fill"
        case .timeline: return "list.bullet.rectangle.portrait.fill"
        case .approvals: return "checkmark.shield.fill"
        case .metrics: return "chart.bar.xaxis"
        case .cli: return "terminal.fill"
        case .hooks: return "link.circle.fill"
        case .about: return "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .general: return .gray
        case .behavior: return .orange
        case .appearance: return .blue
        case .mascots: return .pink
        case .sound: return .green
        case .shortcuts: return .indigo
        case .timeline: return .blue
        case .approvals: return .red
        case .metrics: return .mint
        case .cli: return .green
        case .hooks: return .purple
        case .about: return .cyan
        }
    }
}

private struct SidebarGroup: Hashable {
    let title: String?
    let pages: [SettingsPage]
}

private let sidebarGroups: [SidebarGroup] = [
    SidebarGroup(title: nil, pages: [.general, .behavior, .appearance, .mascots, .sound, .shortcuts]),
    SidebarGroup(title: "NotchAgent", pages: [.timeline, .approvals, .metrics, .cli, .hooks, .about]),
]

// MARK: - Main View

struct SettingsView: View {
    @ObservedObject private var l10n = L10n.shared
    @State private var selectedPage: SettingsPage = .general
    var appState: AppState?

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedPage) {
                ForEach(sidebarGroups, id: \.title) { group in
                    Section {
                        ForEach(group.pages) { page in
                            SidebarRow(page: page)
                                .tag(page)
                        }
                    } header: {
                        if let title = group.title {
                            Text(title)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(200)
        } detail: {
            Group {
                switch selectedPage {
                case .general: GeneralPage()
                case .behavior: BehaviorPage(appState: appState)
                case .appearance: AppearancePage()
                case .mascots: MascotsPage()
                case .sound: SoundPage()
                case .shortcuts: ShortcutsPage()
                case .timeline: TimelinePage(appState: appState)
                case .approvals: ApprovalsPage(appState: appState)
                case .metrics: MetricsPage(appState: appState)
                case .cli: CLIPage()
                case .hooks: HooksPage()
                case .about: AboutPage()
                }
            }
        }
        .toolbar(removing: .sidebarToggle)
    }
}

private struct PageHeader: View {
    let title: String
    var body: some View {
        EmptyView()
    }
}

private struct SidebarRow: View {
    @ObservedObject private var l10n = L10n.shared
    let page: SettingsPage

    var body: some View {
        Label {
            Text(l10n[page.rawValue])
                .font(.system(size: 13))
                .padding(.leading, 2)
        } icon: {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(page.color.gradient)
                    .frame(width: 24, height: 24)
                Image(systemName: page.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - General Page

private struct GeneralPage: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(SettingsKey.displayChoice) private var displayChoice = SettingsDefaults.displayChoice
    @AppStorage(SettingsKey.allowHorizontalDrag) private var allowHorizontalDrag = SettingsDefaults.allowHorizontalDrag
    @State private var launchAtLogin: Bool

    init() {
        _launchAtLogin = State(initialValue: SettingsManager.shared.launchAtLogin)
    }

    var body: some View {
        Form {
            Section {
                Picker(l10n["language"], selection: $l10n.language) {
                    Text(l10n["system_language"]).tag("system")
                    Text("English").tag("en")
                    Text("中文").tag("zh")
                    Text("日本語").tag("ja")
                    Text("한국어").tag("ko")
                    Text("Türkçe").tag("tr")
                }
                Toggle(l10n["launch_at_login"], isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, v in
                        SettingsManager.shared.launchAtLogin = v
                    }
                Toggle(l10n["allow_horizontal_drag"], isOn: $allowHorizontalDrag)
                    .onChange(of: allowHorizontalDrag) { _, enabled in
                        if !enabled {
                            SettingsManager.shared.panelHorizontalOffset = 0
                        }
                    }
                Text(l10n["allow_horizontal_drag_desc"])
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker(l10n["display"], selection: $displayChoice) {
                    Text(l10n["auto"]).tag("auto")
                    ForEach(Array(NSScreen.screens.enumerated()), id: \.offset) { index, screen in
                        let name = screen.localizedName
                        let isBuiltin = name.contains("Built-in") || name.contains("内置")
                        let label = isBuiltin ? l10n["builtin_display"] : name
                        Text(label).tag("screen_\(index)")
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Behavior Page

private struct BehaviorPage: View {
    @ObservedObject private var l10n = L10n.shared
    var appState: AppState?

    @AppStorage(SettingsKey.hideInFullscreen) private var hideInFullscreen = SettingsDefaults.hideInFullscreen
    @AppStorage(SettingsKey.hideWhenNoSession) private var hideWhenNoSession = SettingsDefaults.hideWhenNoSession
    @AppStorage(SettingsKey.smartSuppress) private var smartSuppress = SettingsDefaults.smartSuppress
    @AppStorage(SettingsKey.collapseOnMouseLeave) private var collapseOnMouseLeave = SettingsDefaults.collapseOnMouseLeave
    @AppStorage(SettingsKey.autoCollapseAfterSessionJump) private var autoCollapseAfterSessionJump = SettingsDefaults.autoCollapseAfterSessionJump
    @AppStorage(SettingsKey.autoExpandOnCompletion) private var autoExpandOnCompletion = SettingsDefaults.autoExpandOnCompletion
    @AppStorage(SettingsKey.pluginSessionMode) private var pluginSessionMode = SettingsDefaults.pluginSessionMode
    @AppStorage(SettingsKey.hapticOnHover) private var hapticOnHover = SettingsDefaults.hapticOnHover
    @AppStorage(SettingsKey.hapticIntensity) private var hapticIntensity = SettingsDefaults.hapticIntensity
    @AppStorage(SettingsKey.sessionTimeout) private var sessionTimeout = SettingsDefaults.sessionTimeout
    @AppStorage(SettingsKey.rotationInterval) private var rotationInterval = SettingsDefaults.rotationInterval
    @AppStorage(SettingsKey.maxToolHistory) private var maxToolHistory = SettingsDefaults.maxToolHistory
    @AppStorage(SettingsKey.autoApproveTools) private var autoApproveRaw: String = SettingsDefaults.autoApproveTools
    @AppStorage(SettingsKey.excludedHookCwdSubstrings) private var excludedHookCwdSubstrings: String = SettingsDefaults.excludedHookCwdSubstrings
    @AppStorage(SettingsKey.webhookEnabled) private var webhookEnabled: Bool = SettingsDefaults.webhookEnabled
    @AppStorage(SettingsKey.webhookURL) private var webhookURL: String = SettingsDefaults.webhookURL
    @AppStorage(SettingsKey.webhookEventFilter) private var webhookEventFilter: String = SettingsDefaults.webhookEventFilter

    private var pluginSessionModeBinding: Binding<String> {
        Binding(
            get: { pluginSessionMode },
            set: { newMode in
                guard pluginSessionMode != newMode else { return }
                pluginSessionMode = newMode
                appState?.applyCurrentPluginSessionMode()
            }
        )
    }

    private func autoApproveBinding(for name: String) -> Binding<Bool> {
        Binding(
            get: { autoApproveRaw.split(separator: ",").contains(Substring(name)) },
            set: { isOn in
                var set = Set(autoApproveRaw.split(separator: ",").map(String.init))
                if isOn { set.insert(name) } else { set.remove(name) }
                autoApproveRaw = set.sorted().joined(separator: ",")
            }
        )
    }

    var body: some View {
        Form {
            Section(l10n["display_section"]) {
                BehaviorToggleRow(
                    title: l10n["hide_in_fullscreen"],
                    desc: l10n["hide_in_fullscreen_desc"],
                    isOn: $hideInFullscreen,
                    animation: .hideFullscreen
                )
                BehaviorToggleRow(
                    title: l10n["hide_when_no_session"],
                    desc: l10n["hide_when_no_session_desc"],
                    isOn: $hideWhenNoSession,
                    animation: .hideNoSession
                )
                BehaviorToggleRow(
                    title: l10n["smart_suppress"],
                    desc: l10n["smart_suppress_desc"],
                    isOn: $smartSuppress,
                    animation: .smartSuppress
                )
                BehaviorToggleRow(
                    title: l10n["collapse_on_mouse_leave"],
                    desc: l10n["collapse_on_mouse_leave_desc"],
                    isOn: $collapseOnMouseLeave,
                    animation: .collapseMouseLeave
                )
                BehaviorToggleRow(
                    title: l10n["auto_collapse_after_session_jump"],
                    desc: l10n["auto_collapse_after_session_jump_desc"],
                    isOn: $autoCollapseAfterSessionJump,
                    animation: .clickJumpCollapse
                )
                BehaviorToggleRow(
                    title: l10n["auto_expand_on_completion"],
                    desc: l10n["auto_expand_on_completion_desc"],
                    isOn: $autoExpandOnCompletion,
                    animation: .smartSuppress
                )
                BehaviorToggleRow(
                    title: l10n["haptic_on_hover"],
                    desc: l10n["haptic_on_hover_desc"],
                    isOn: $hapticOnHover,
                    animation: .hapticHover
                )
                if hapticOnHover {
                    Picker(selection: $hapticIntensity) {
                        Text(l10n["haptic_light"]).tag(1)
                        Text(l10n["haptic_medium"]).tag(2)
                        Text(l10n["haptic_strong"]).tag(3)
                    } label: {
                        EmptyView()
                    }
                    .pickerStyle(.segmented)
                    .padding(.leading, 84)
                }
            }

            Section(l10n["auto_approve_tools"]) {
                Text(l10n["auto_approve_tools_desc"])
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(SettingsManager.allAutoApproveTools, id: \.name) { tool in
                    Toggle(isOn: autoApproveBinding(for: tool.name)) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(tool.name)
                                .font(.system(size: 12, design: .monospaced))
                            Text(l10n["auto_approve_\(tool.name)"])
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section(l10n["excluded_hook_cwd_title"]) {
                Text(l10n["excluded_hook_cwd_desc"])
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(l10n["excluded_hook_cwd_placeholder"], text: $excludedHookCwdSubstrings)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }

            Section(l10n["webhook_title"]) {
                Text(l10n["webhook_desc"])
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle(l10n["webhook_enable"], isOn: $webhookEnabled)
                if webhookEnabled {
                    TextField(l10n["webhook_url_placeholder"], text: $webhookURL)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                        .autocorrectionDisabled(true)
                    TextField(l10n["webhook_filter_placeholder"], text: $webhookEventFilter)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                        .autocorrectionDisabled(true)
                    Text(l10n["webhook_filter_hint"])
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section(l10n["sessions"]) {
                Picker(selection: $sessionTimeout) {
                    Text(l10n["no_cleanup"]).tag(0)
                    Text(l10n["10_minutes"]).tag(10)
                    Text(l10n["30_minutes"]).tag(30)
                    Text(l10n["1_hour"]).tag(60)
                    Text(l10n["2_hours"]).tag(120)
                } label: {
                    Text(l10n["session_cleanup"])
                    Text(l10n["session_cleanup_desc"])
                }
                Picker(selection: $rotationInterval) {
                    Text(l10n["3_seconds"]).tag(3)
                    Text(l10n["5_seconds"]).tag(5)
                    Text(l10n["8_seconds"]).tag(8)
                    Text(l10n["10_seconds"]).tag(10)
                } label: {
                    Text(l10n["rotation_interval"])
                    Text(l10n["rotation_interval_desc"])
                }
                Picker(selection: $maxToolHistory) {
                    Text("10").tag(10)
                    Text("20").tag(20)
                    Text("50").tag(50)
                    Text("100").tag(100)
                } label: {
                    Text(l10n["tool_history_limit"])
                    Text(l10n["tool_history_limit_desc"])
                }
                Picker(selection: pluginSessionModeBinding) {
                    Text(l10n["plugin_session_mode_separate"]).tag("separate")
                    Text(l10n["plugin_session_mode_merge"]).tag("merge")
                    Text(l10n["plugin_session_mode_hide"]).tag("hide")
                } label: {
                    Text(l10n["plugin_session_mode"])
                    Text(l10n["plugin_session_mode_desc"])
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Timeline Page

private struct TimelinePage: View {
    @ObservedObject private var l10n = L10n.shared
    var appState: AppState?

    var body: some View {
        Form {
            Section(l10n["timeline_title"]) {
                if let appState, !appState.timelineEvents.isEmpty {
                    ForEach(appState.timelineEvents.prefix(80)) { event in
                        TimelineEventRow(event: event)
                    }
                } else {
                    Text(l10n["timeline_empty"])
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct TimelineEventRow: View {
    let event: TimelineEvent

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 3) {
                Circle()
                    .fill(color(for: event))
                    .frame(width: 8, height: 8)
                Rectangle()
                    .fill(.secondary.opacity(0.18))
                    .frame(width: 1, height: 30)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(event.title)
                        .font(.system(size: 13, weight: .medium))
                    if let risk = event.risk {
                        Text(risk.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(riskColor(risk))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(riskColor(risk).opacity(0.13)))
                    }
                    if let decision = event.decision {
                        Text(decision.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(decision == "allow" ? .green : .red)
                    }
                }
                if let detail = event.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Text("\(event.project) · \(event.source) · \(event.timestamp.formatted(date: .omitted, time: .standard))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private func color(for event: TimelineEvent) -> Color {
        if event.decision == "deny" { return .red }
        if event.decision == "allow" { return .green }
        switch event.eventName {
        case "PermissionRequest": return .orange
        case "PostToolUseFailure": return .red
        case "Stop", "SessionEnd": return .green
        default: return .blue
        }
    }
}

// MARK: - Approvals Page

private struct ApprovalsPage: View {
    @ObservedObject private var l10n = L10n.shared
    var appState: AppState?

    @State private var ruleName = ""
    @State private var toolName = ""
    @State private var commandContains = ""
    @State private var cwdContains = ""
    @State private var source = ""
    @State private var decision: ApprovalRule.Decision = .allow

    var body: some View {
        Form {
            Section(l10n["approval_pause_title"]) {
                if let appState {
                    if appState.approvalPauseUntil != nil {
                        HStack {
                            Label(l10n["approval_paused"], systemImage: "pause.circle.fill")
                                .foregroundStyle(.orange)
                            Spacer()
                            Text(formatDuration(appState.approvalPauseRemaining))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Button(l10n["approval_resume"]) {
                            appState.resumeApprovals()
                        }
                    } else {
                        Text(l10n["approval_pause_desc"])
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Button(l10n["approval_pause_15"]) { appState.pauseApprovals(minutes: 15) }
                            Button(l10n["approval_pause_60"]) { appState.pauseApprovals(minutes: 60) }
                        }
                    }
                } else {
                    Text(l10n["approval_appstate_unavailable"])
                        .foregroundStyle(.secondary)
                }
            }

            Section(l10n["pending_approvals"]) {
                if let appState, !appState.permissionQueue.isEmpty {
                    ForEach(Array(appState.permissionQueue.enumerated()), id: \.offset) { _, request in
                        ApprovalRequestRow(request: request)
                    }
                    HStack {
                        Button(l10n["approval_allow_first"]) { appState.approvePermission() }
                        Button(l10n["approval_deny_first"], role: .destructive) { appState.denyPermission() }
                    }
                } else {
                    Text(l10n["pending_approvals_empty"])
                        .foregroundStyle(.secondary)
                }
            }

            Section(l10n["approval_rules_title"]) {
                if let appState {
                    if appState.approvalRules.isEmpty {
                        Text(l10n["approval_rules_empty"])
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(appState.approvalRules) { rule in
                            ApprovalRuleRow(rule: rule, appState: appState)
                        }
                    }
                }
            }

            Section(l10n["approval_rule_builder"]) {
                TextField(l10n["approval_rule_name"], text: $ruleName)
                TextField(l10n["approval_rule_tool"], text: $toolName)
                TextField(l10n["approval_rule_command"], text: $commandContains)
                    .font(.system(size: 12, design: .monospaced))
                TextField(l10n["approval_rule_cwd"], text: $cwdContains)
                    .font(.system(size: 12, design: .monospaced))
                TextField(l10n["approval_rule_source"], text: $source)
                Picker(l10n["approval_rule_decision"], selection: $decision) {
                    Text(l10n["approval_rule_allow"]).tag(ApprovalRule.Decision.allow)
                    Text(l10n["approval_rule_deny"]).tag(ApprovalRule.Decision.deny)
                }
                .pickerStyle(.segmented)

                Button(l10n["approval_rule_save"]) {
                    guard let appState else { return }
                    let fallbackName = toolName.isEmpty ? l10n["approval_rule_untitled"] : toolName
                    let rule = ApprovalRule(
                        name: ruleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallbackName : ruleName,
                        toolName: toolName,
                        commandContains: commandContains,
                        cwdContains: cwdContains,
                        source: source,
                        decision: decision
                    )
                    appState.approvalRules.append(rule)
                    ruleName = ""
                    toolName = ""
                    commandContains = ""
                    cwdContains = ""
                    source = ""
                    decision = .allow
                }
                .disabled(appState == nil)
            }
        }
        .formStyle(.grouped)
    }
}

private struct ApprovalRequestRow: View {
    let request: PermissionRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(request.event.toolName ?? "Approval")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(request.risk.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(riskColor(request.risk))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(riskColor(request.risk).opacity(0.13)))
            }
            Text(request.commandSummary)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(4)
            if let cwd = request.event.rawJSON["cwd"] as? String, !cwd.isEmpty {
                Text(cwd)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ApprovalRuleRow: View {
    let rule: ApprovalRule
    var appState: AppState

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Toggle("", isOn: enabledBinding)
                .labelsHidden()
            VStack(alignment: .leading, spacing: 3) {
                Text(rule.name)
                    .font(.system(size: 13, weight: .medium))
                Text(rule.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(rule.decision.rawValue.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(rule.decision == .allow ? .green : .red)
            }
            Spacer()
            Button(role: .destructive) {
                appState.approvalRules.removeAll { $0.id == rule.id }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { rule.enabled },
            set: { newValue in
                var rules = appState.approvalRules
                guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return }
                rules[index].enabled = newValue
                appState.approvalRules = rules
            }
        )
    }
}

// MARK: - Metrics Page

private struct MetricsPage: View {
    @ObservedObject private var l10n = L10n.shared
    var appState: AppState?

    var body: some View {
        Form {
            Section(l10n["metrics_title"]) {
                if let appState {
                    let metrics = appState.sessionMetrics()
                    if metrics.isEmpty {
                        Text(l10n["metrics_empty"])
                            .foregroundStyle(.secondary)
                    } else {
                        MetricsSummary(metrics: metrics, appState: appState)
                        AgentComparisonSummary(metrics: metrics)
                        ForEach(metrics) { item in
                            MetricsRow(metrics: item, appState: appState)
                        }
                    }
                } else {
                    Text(l10n["approval_appstate_unavailable"])
                        .foregroundStyle(.secondary)
                }
            }

            Section(l10n["leaderboard_title"]) {
                LeaderboardView()
            }
        }
        .formStyle(.grouped)
    }
}

private struct AgentComparisonSummary: View {
    struct AgentRollup: Identifiable {
        let id: String
        let source: String
        let sessions: Int
        let toolCalls: Int
        let approvals: Int
        let deniedApprovals: Int
        let elapsedSeconds: TimeInterval

        var approvalRateText: String {
            guard approvals > 0 else { return "0%" }
            let allowed = approvals - deniedApprovals
            return "\(Int((Double(allowed) / Double(approvals) * 100).rounded()))%"
        }
    }

    let metrics: [SessionMetrics]

    private var rollups: [AgentRollup] {
        Dictionary(grouping: metrics, by: \.source)
            .map { source, items in
                AgentRollup(
                    id: source,
                    source: source,
                    sessions: items.count,
                    toolCalls: items.reduce(0) { $0 + $1.toolCallCount },
                    approvals: items.reduce(0) { $0 + $1.approvalCount },
                    deniedApprovals: items.reduce(0) { $0 + $1.deniedApprovalCount },
                    elapsedSeconds: items.reduce(0) { $0 + $1.elapsedSeconds }
                )
            }
            .sorted {
                if $0.toolCalls != $1.toolCalls { return $0.toolCalls > $1.toolCalls }
                return $0.elapsedSeconds > $1.elapsedSeconds
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Agent comparison", systemImage: "chart.bar.doc.horizontal")
                .font(.system(size: 13, weight: .semibold))
            ForEach(rollups) { item in
                AgentComparisonRow(item: item)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct AgentComparisonRow: View {
    let item: AgentComparisonSummary.AgentRollup

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.source.capitalized)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(item.sessions) session\(item.sessions == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                Label("\(item.toolCalls)", systemImage: "hammer")
                Label("\(item.approvals)", systemImage: "checkmark.shield")
                Label(item.approvalRateText, systemImage: "percent")
                Label(formatDuration(item.elapsedSeconds), systemImage: "clock")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.25)))
    }
}

private struct MetricsSummary: View {
    let metrics: [SessionMetrics]
    var appState: AppState?

    var body: some View {
        HStack(spacing: 10) {
            MetricTile(title: "Tool calls", value: "\(metrics.reduce(0) { $0 + $1.toolCallCount })")
            MetricTile(title: "Approvals", value: "\(metrics.reduce(0) { $0 + $1.approvalCount })")
            MetricTile(title: "Active", value: "\(metrics.filter { $0.status != .idle }.count)")
            if let appState {
                let totalCost = appState.sessions.values.reduce(0.0) { $0 + $1.estimatedCost }
                MetricTile(title: "Est. Cost", value: String(format: "$%.3f", totalCost))
            }
        }
    }
}

private struct MetricTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.35)))
    }
}

private struct MetricsRow: View {
    let metrics: SessionMetrics
    var appState: AppState?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(metrics.project)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(metrics.source)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let appState,
                   let cost = appState.sessions[metrics.id]?.estimatedCost, cost > 0 {
                    Text(String(format: "%.3f", cost))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            HStack(spacing: 12) {
                Label("\(metrics.toolCallCount)", systemImage: "hammer")
                Label("\(metrics.approvalCount)", systemImage: "checkmark.shield")
                Label(formatDuration(metrics.elapsedSeconds), systemImage: "clock")
                if metrics.deniedApprovalCount > 0 {
                    Label("\(metrics.deniedApprovalCount)", systemImage: "xmark.octagon")
                        .foregroundStyle(.red)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct LeaderboardView: View {
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let entries = PerformanceTracker.leaderboard()
        if entries.isEmpty {
            Text(l10n["leaderboard_empty"])
                .foregroundStyle(.secondary)
        } else {
            ForEach(entries) { entry in
                HStack(spacing: 8) {
                    Text(entry.id.capitalized)
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 80, alignment: .leading)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 12) {
                            Label("\(entry.sessionCount)", systemImage: "number")
                            Label("\(entry.totalToolCalls)", systemImage: "hammer")
                            Label(formatDuration(entry.totalDurationSeconds), systemImage: "clock")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            Label(String(format: "%.0f%%", entry.completionRate * 100), systemImage: "checkmark.circle")
                            Label(String(format: "%.0f%%", entry.approvalRate * 100), systemImage: "checkmark.shield")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            Button(l10n["leaderboard_reset"]) {
                PerformanceTracker.reset()
            }
            .foregroundStyle(.red)
        }
    }
}

private func riskColor(_ risk: String) -> Color {
    switch risk {
    case "high": return .red
    case "medium": return .orange
    default: return .green
    }
}

private func formatDuration(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds.rounded()))
    if total < 60 { return "\(total)s" }
    let minutes = total / 60
    if minutes < 60 { return "\(minutes)m" }
    return "\(minutes / 60)h \(minutes % 60)m"
}

// MARK: - Hooks Page

private struct HooksPage: View {
    @ObservedObject private var l10n = L10n.shared
    @State private var cliStatuses: [String: Bool] = [:]
    @State private var statusMessage = ""
    @State private var statusIsError = false
    @State private var refreshKey = 0
    @State private var customName = ""
    @State private var customSource = ""
    @State private var customConfigPath = ""
    @State private var customConfigKey = "hooks"
    @State private var customFormat: HookFormat = .claude

    private func refreshCLIStatuses() {
        for cli in ConfigInstaller.allCLIs {
            cliStatuses[cli.source] = ConfigInstaller.isInstalled(source: cli.source)
        }
        cliStatuses["opencode"] = ConfigInstaller.isInstalled(source: "opencode")
    }

    private func statusText(installed: Bool, exists: Bool) -> String {
        installed ? l10n["activated"] : (exists ? l10n["not_installed"] : l10n["not_detected"])
    }

    private var hookDiagnostics: [HookDiagnosticItem] {
        var items: [HookDiagnosticItem] = ConfigInstaller.allCLIs.compactMap { cli in
            let exists = ConfigInstaller.cliExists(source: cli.source)
            let installed = ConfigInstaller.isInstalled(source: cli.source)
            let enabled = ConfigInstaller.isEnabled(source: cli.source)
            if exists && enabled && !installed {
                return HookDiagnosticItem(
                    title: "\(cli.name) hook missing",
                    detail: "\(cli.displayConfigPath) needs the NotchAgent hook command.",
                    severity: .warning,
                    suggestion: "Run Repair Detected Hooks."
                )
            }
            if exists && !enabled {
                return HookDiagnosticItem(
                    title: "\(cli.name) disabled",
                    detail: "The CLI exists, but NotchAgent is not allowed to manage its hook.",
                    severity: .info,
                    suggestion: "Enable it in the row above, then repair hooks."
                )
            }
            if !exists && enabled {
                return HookDiagnosticItem(
                    title: "\(cli.name) not detected",
                    detail: "NotchAgent could not find the CLI config path.",
                    severity: .info,
                    suggestion: "Install the tool or disable this source."
                )
            }
            return nil
        }

        let openCodeExists = ConfigInstaller.cliExists(source: "opencode")
        let openCodeInstalled = ConfigInstaller.isInstalled(source: "opencode")
        if openCodeExists && !openCodeInstalled {
            items.append(HookDiagnosticItem(
                title: "OpenCode plugin missing",
                detail: "~/.config/opencode/config.json does not include the NotchAgent plugin.",
                severity: .warning,
                suggestion: "Run Repair Detected Hooks."
            ))
        }
        return items
    }

    var body: some View {
        Form {
            Section(l10n["cli_status"]) {
                ForEach(ConfigInstaller.allCLIs, id: \.source) { cli in
                    let installed = cliStatuses[cli.source] ?? false
                    let exists = ConfigInstaller.cliExists(source: cli.source)
                    CLIStatusRow(
                        name: cli.name,
                        source: cli.source,
                        configPath: cli.displayConfigPath,
                        fullPath: cli.fullPath,
                        installed: installed,
                        exists: exists
                    ) { _ in refreshCLIStatuses() }
                    .id("\(cli.source)-\(refreshKey)")
                }
                // OpenCode (plugin-based, not hooks)
                let ocInstalled = cliStatuses["opencode"] ?? false
                let ocExists = ConfigInstaller.cliExists(source: "opencode")
                CLIStatusRow(
                    name: "OpenCode",
                    source: "opencode",
                    configPath: "~/.config/opencode/config.json",
                    fullPath: NSHomeDirectory() + "/.config/opencode/config.json",
                    installed: ocInstalled,
                    exists: ocExists
                ) { _ in refreshCLIStatuses() }
                .id("opencode-\(refreshKey)")
            }

            Section("Custom CLIs") {
                let customItems = ConfigInstaller.customCLIConfigs()
                if customItems.isEmpty {
                    Text("No custom CLI configured")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(customItems) { item in
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                Text("\(item.source) · \(item.configPath)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                _ = ConfigInstaller.setEnabled(source: item.source, enabled: false)
                                _ = ConfigInstaller.removeCustomCLI(source: item.source)
                                refreshCLIStatuses()
                                refreshKey += 1
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                TextField("Name (e.g. MyTool)", text: $customName)
                TextField("Source (e.g. mytool)", text: $customSource)
                TextField("Config path (e.g. .mytool/settings.json)", text: $customConfigPath)
                TextField("Config key", text: $customConfigKey)
                Picker("Template", selection: $customFormat) {
                    Text("Claude").tag(HookFormat.claude)
                    Text("Codex/Gemini").tag(HookFormat.nested)
                    Text("Cursor").tag(HookFormat.flat)
                    Text("Copilot").tag(HookFormat.copilot)
                }

                Button("Add Custom CLI") {
                    let result = ConfigInstaller.addCustomCLI(
                        name: customName,
                        source: customSource,
                        configPath: customConfigPath,
                        format: customFormat,
                        configKey: customConfigKey
                    )
                    statusMessage = result.message
                    statusIsError = !result.ok
                    guard result.ok else { return }

                    let normalizedSource = customSource
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .lowercased()
                    _ = ConfigInstaller.setEnabled(source: normalizedSource, enabled: true)
                    customName = ""
                    customSource = ""
                    customConfigPath = ""
                    customConfigKey = "hooks"
                    customFormat = .claude
                    refreshCLIStatuses()
                    refreshKey += 1
                }
            }

            Section("Diagnostics & Repair") {
                HookDiagnosticsPanel(items: hookDiagnostics) {
                    for cli in ConfigInstaller.allCLIs where ConfigInstaller.cliExists(source: cli.source) {
                        UserDefaults.standard.set(true, forKey: "cli_enabled_\(cli.source)")
                    }
                    if ConfigInstaller.cliExists(source: "opencode") {
                        UserDefaults.standard.set(true, forKey: "cli_enabled_opencode")
                    }
                    if ConfigInstaller.install() {
                        refreshCLIStatuses()
                        refreshKey += 1
                        statusMessage = "Detected hooks repaired"
                        statusIsError = false
                    } else {
                        statusMessage = l10n["install_failed"]
                        statusIsError = true
                    }
                }
            }

            Section(l10n["management"]) {
                HStack(spacing: 8) {
                    Button {
                        // Enable all detected CLIs before reinstalling
                        for cli in ConfigInstaller.allCLIs where ConfigInstaller.cliExists(source: cli.source) {
                            UserDefaults.standard.set(true, forKey: "cli_enabled_\(cli.source)")
                        }
                        if ConfigInstaller.cliExists(source: "opencode") {
                            UserDefaults.standard.set(true, forKey: "cli_enabled_opencode")
                        }
                        if ConfigInstaller.install() {
                            refreshCLIStatuses()
                            refreshKey += 1
                            statusMessage = l10n["hooks_installed"]
                            statusIsError = false
                        } else {
                            statusMessage = l10n["install_failed"]
                            statusIsError = true
                        }
                    } label: {
                        Text(l10n["reinstall"])
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        // Disable all CLIs before uninstalling
                        for cli in ConfigInstaller.allCLIs {
                            UserDefaults.standard.set(false, forKey: "cli_enabled_\(cli.source)")
                        }
                        UserDefaults.standard.set(false, forKey: "cli_enabled_opencode")
                        ConfigInstaller.uninstall()
                        refreshCLIStatuses()
                        refreshKey += 1
                        statusMessage = l10n["hooks_uninstalled"]
                        statusIsError = false
                    } label: {
                        Text(l10n["uninstall"])
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }

                if !statusMessage.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: statusIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(statusIsError ? .red : .green)
                        Text(statusMessage)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { refreshCLIStatuses() }
    }
}

struct HookDiagnosticItem: Identifiable, Equatable {
    enum Severity {
        case info
        case warning
    }

    let id = UUID()
    let title: String
    let detail: String
    let severity: Severity
    let suggestion: String
}

private struct HookDiagnosticsPanel: View {
    let items: [HookDiagnosticItem]
    let repair: () -> Void

    var body: some View {
        if items.isEmpty {
            Label("All detected hooks look healthy", systemImage: "checkmark.seal.fill")
                .foregroundStyle(.green)
        } else {
            ForEach(items) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: item.severity == .warning ? "exclamationmark.triangle.fill" : "info.circle.fill")
                        .foregroundStyle(item.severity == .warning ? .orange : .blue)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(.system(size: 13, weight: .semibold))
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(item.suggestion)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 2)
            }

            Button {
                repair()
            } label: {
                Label("Repair Detected Hooks", systemImage: "wrench.and.screwdriver")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

private struct CLIStatusRow: View {
    @ObservedObject private var l10n = L10n.shared
    let name: String
    let source: String
    let configPath: String
    let fullPath: String
    let installed: Bool
    let exists: Bool
    var onToggle: ((Bool) -> Void)?

    @State private var enabled: Bool

    init(name: String, source: String, configPath: String, fullPath: String,
         installed: Bool, exists: Bool, onToggle: ((Bool) -> Void)? = nil) {
        self.name = name
        self.source = source
        self.configPath = configPath
        self.fullPath = fullPath
        self.installed = installed
        self.exists = exists
        self.onToggle = onToggle
        _enabled = State(initialValue: ConfigInstaller.isEnabled(source: source))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                if let icon = cliIcon(source: source, size: 20) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 20, height: 20)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                    if !exists {
                        Text(l10n["not_detected"])
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    } else if installed {
                        HStack(spacing: 2) {
                            Text(configPath)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.tertiary)
                            Button {
                                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: fullPath)])
                            } label: {
                                Image(systemName: "arrow.right.circle")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Spacer()
                if exists {
                    Toggle("", isOn: $enabled)
                        .labelsHidden()
                        .onChange(of: enabled) { _, newValue in
                            ConfigInstaller.setEnabled(source: source, enabled: newValue)
                            onToggle?(newValue)
                        }
                }
            }
        }
    }
}

// MARK: - Appearance Page

private struct AppearancePage: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(SettingsKey.maxVisibleSessions) private var maxVisibleSessions = SettingsDefaults.maxVisibleSessions
    @AppStorage(SettingsKey.contentFontSize) private var contentFontSize = SettingsDefaults.contentFontSize
    @AppStorage(SettingsKey.aiMessageLines) private var aiMessageLines = SettingsDefaults.aiMessageLines
    @AppStorage(SettingsKey.showAgentDetails) private var showAgentDetails = SettingsDefaults.showAgentDetails
    @AppStorage(SettingsKey.showToolStatus) private var showToolStatus = SettingsDefaults.showToolStatus
    @AppStorage(SettingsKey.collapsedWidthScale) private var collapsedWidthScale = SettingsDefaults.collapsedWidthScale
    @AppStorage(SettingsKey.notchHeightMode) private var notchHeightModeRaw = SettingsDefaults.notchHeightMode
    @AppStorage(SettingsKey.customNotchHeight) private var customNotchHeight = SettingsDefaults.customNotchHeight
    @AppStorage(SettingsKey.panelMode) private var panelMode = SettingsDefaults.panelMode

    private var notchHeightMode: Binding<NotchHeightMode> {
        Binding(
            get: { NotchHeightMode(rawValue: notchHeightModeRaw) ?? .matchNotch },
            set: { notchHeightModeRaw = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            Section(l10n["preview"]) {
                AppearancePreview(
                    fontSize: contentFontSize,
                    lineLimit: aiMessageLines,
                    showDetails: showAgentDetails
                )
            }

            Section(l10n["panel"]) {
                Picker(selection: $panelMode) {
                    Text(l10n["panel_mode_notch"]).tag("notch")
                    Text(l10n["panel_mode_floating"]).tag("floating")
                } label: {
                    Text(l10n["panel_mode"])
                    Text(l10n["panel_mode_desc"])
                }

                Picker(selection: $maxVisibleSessions) {
                    Text("3").tag(3)
                    Text("5").tag(5)
                    Text("8").tag(8)
                    Text("10").tag(10)
                    Text(l10n["unlimited"]).tag(99)
                } label: {
                    Text(l10n["max_visible_sessions"])
                    Text(l10n["max_visible_sessions_desc"])
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(l10n["collapsed_width_scale"])
                        Spacer()
                        Text("\(collapsedWidthScale)%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: Binding(
                        get: { Double(collapsedWidthScale) },
                        set: { collapsedWidthScale = Int($0) }
                    ), in: 50...150, step: 10)
                    Text(l10n["collapsed_width_scale_desc"])
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Picker(selection: notchHeightMode) {
                        Text(l10n["notch_height_match_notch"]).tag(NotchHeightMode.matchNotch)
                        Text(l10n["notch_height_match_menubar"]).tag(NotchHeightMode.matchMenuBar)
                        Text(l10n["notch_height_custom"]).tag(NotchHeightMode.custom)
                    } label: {
                        Text(l10n["notch_height_mode"])
                        Text(l10n["notch_height_mode_desc"])
                    }

                    if notchHeightMode.wrappedValue == .custom {
                        HStack {
                            Text(l10n["custom_notch_height"])
                            Spacer()
                            Text("\(Int(customNotchHeight.rounded()))pt")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $customNotchHeight, in: 15...60, step: 1)
                    }
                }
            }

            Section(l10n["content"]) {
                Picker(l10n["content_font_size"], selection: $contentFontSize) {
                    Text("10pt").tag(10)
                    Text(l10n["11pt_default"]).tag(11)
                    Text("12pt").tag(12)
                    Text("13pt").tag(13)
                }
                Picker(l10n["ai_reply_lines"], selection: $aiMessageLines) {
                    Text(l10n["1_line_default"]).tag(1)
                    Text(l10n["2_lines"]).tag(2)
                    Text(l10n["3_lines"]).tag(3)
                    Text(l10n["5_lines"]).tag(5)
                    Text(l10n["unlimited"]).tag(0)
                }
                Toggle(l10n["show_agent_details"], isOn: $showAgentDetails)
                Toggle(l10n["show_tool_status"], isOn: $showToolStatus)
            }
        }
        .formStyle(.grouped)
    }
}

/// Live preview mimicking the real SessionCard layout.
private struct AppearancePreview: View {
    let fontSize: Int
    let lineLimit: Int
    let showDetails: Bool

    private var fs: CGFloat { CGFloat(fontSize) }
    private let green = Color(red: 0.3, green: 0.85, blue: 0.4)
    private let aiColor = Color(red: 0.85, green: 0.47, blue: 0.34)

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Column 1: Mascot
            VStack(spacing: 3) {
                MascotView(source: "claude", status: .processing, size: 32)
                if showDetails {
                    HStack(spacing: 1) {
                        MiniAgentIcon(active: true, size: 8)
                        MiniAgentIcon(active: false, size: 8)
                    }
                }
            }
            .frame(width: 36)

            // Column 2: Content
            VStack(alignment: .leading, spacing: 6) {
                // Header
                HStack(spacing: 6) {
                    Text("my-project")
                        .font(.system(size: fs + 2, weight: .bold, design: .monospaced))
                        .foregroundStyle(green)
                    Spacer()
                    Text("3m")
                        .font(.system(size: max(9, fs - 1.5), weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.08)))
                }

                // Chat
                VStack(alignment: .leading, spacing: 3) {
                    // User prompt
                    HStack(alignment: .top, spacing: 4) {
                        Text(">")
                            .font(.system(size: fs, weight: .bold, design: .monospaced))
                            .foregroundStyle(green)
                        Text("Fix the login bug")
                            .font(.system(size: fs, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                    // AI reply
                    HStack(alignment: .top, spacing: 4) {
                        Text("$")
                            .font(.system(size: fs, weight: .bold, design: .monospaced))
                            .foregroundStyle(aiColor)
                        Text("I've analyzed the codebase and found the issue in the authentication module. The token validation was skipping the expiry check when refreshing sessions.")
                            .font(.system(size: fs, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(lineLimit > 0 ? lineLimit : nil)
                            .truncationMode(.tail)
                    }
                    // Working indicator
                    HStack(spacing: 4) {
                        Text("$")
                            .font(.system(size: fs, weight: .bold, design: .monospaced))
                            .foregroundStyle(aiColor)
                        Text("Edit src/auth.ts")
                            .font(.system(size: fs, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(1)
                    }
                }
                .padding(.leading, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 0.05))
        )
        .animation(.easeInOut(duration: 0.25), value: fontSize)
        .animation(.easeInOut(duration: 0.25), value: lineLimit)
        .animation(.easeInOut(duration: 0.25), value: showDetails)
    }
}

// MARK: - Mascots Page

private struct MascotsPage: View {
    @ObservedObject private var l10n = L10n.shared
    @State private var previewStatus: AgentStatus = .processing
    @State private var mascotRefreshKey = 0
    @AppStorage(SettingsKey.mascotSpeed) private var mascotSpeed = SettingsDefaults.mascotSpeed
    @AppStorage(SettingsKey.defaultSource) private var defaultSource = SettingsDefaults.defaultSource

    private let mascotList: [(name: String, source: String, desc: String, color: Color)] = [
        ("Clawd", "claude", "Claude Code", Color(red: 0.871, green: 0.533, blue: 0.427)),
        ("Dex", "codex", "Codex (OpenAI)", Color(red: 0.92, green: 0.92, blue: 0.93)),
        ("Gemini", "gemini", "Gemini CLI", Color(red: 0.278, green: 0.588, blue: 0.894)),
        ("CursorBot", "cursor", "Cursor", Color(red: 0.96, green: 0.31, blue: 0.0)),
        ("TraeBot", "trae", "Trae", Color(red: 0.96, green: 0.31, blue: 0.0)),
        ("TraeCNBot", "traecn", "Trae CN", Color(red: 0.96, green: 0.31, blue: 0.0)),
        ("CopilotBot", "copilot", "GitHub Copilot", Color(red: 0.35, green: 0.75, blue: 0.95)),
        ("QoderBot", "qoder", "Qoder", Color(red: 0.165, green: 0.859, blue: 0.361)),
        ("Droid", "droid", "Factory", Color(red: 0.835, green: 0.416, blue: 0.149)),
        ("StepFun", "stepfun", "StepFun", Color(red: 0.424, green: 0.302, blue: 1.0)),
        ("AntiGravity", "antigravity", "AntiGravity", Color(red: 0.424, green: 0.302, blue: 1.0)),
        ("Hermes", "hermes", "Hermes", Color(red: 0.424, green: 0.302, blue: 1.0)),
        ("QwenBot", "qwen", "Qwen Code", Color(red: 0.486, green: 0.228, blue: 0.929)),
        ("KimiBot", "kimi", "Kimi Code CLI", Color(red: 0.29, green: 0.56, blue: 1.0)),
        ("OpBot", "opencode", "OpenCode", Color(red: 0.55, green: 0.55, blue: 0.57)),
        ("ClineBot", "cline", "Cline", Color(red: 0.00, green: 0.70, blue: 0.49)),
    ]

    var body: some View {
        Form {
            Section {
                Picker(l10n["preview_status"], selection: $previewStatus) {
                    Text(l10n["processing"]).tag(AgentStatus.processing)
                    Text(l10n["idle"]).tag(AgentStatus.idle)
                    Text(l10n["waiting_approval"]).tag(AgentStatus.waitingApproval)
                }
                .pickerStyle(.segmented)

                HStack {
                    Text(l10n["mascot_speed"])
                    Spacer()
                    Text(mascotSpeed == 0
                         ? l10n["speed_off"]
                         : String(format: "%.1f×", Double(mascotSpeed) / 100.0))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: Binding(
                    get: { Double(mascotSpeed) },
                    set: { mascotSpeed = Int($0) }
                ), in: 0...300, step: 25)

                Picker(selection: $defaultSource) {
                    ForEach(mascotList, id: \.source) { mascot in
                        Text(mascot.desc).tag(mascot.source)
                    }
                } label: {
                    Text(l10n["default_mascot"])
                    Text(l10n["default_mascot_desc"])
                }
            }

            Section {
                ForEach(mascotList, id: \.source) { mascot in
                    MascotRow(
                        name: mascot.name,
                        source: mascot.source,
                        desc: mascot.desc,
                        color: mascot.color,
                        status: previewStatus,
                        refreshKey: mascotRefreshKey,
                        onImport: { importCustomMascot(for: mascot.source) },
                        onReset: {
                            CustomMascotStore.removePath(for: mascot.source)
                            mascotRefreshKey += 1
                        }
                    )
                }
            }
        }
        .formStyle(.grouped)
    }

    private func importCustomMascot(for source: String) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        CustomMascotStore.setPath(url.path, for: source)
        mascotRefreshKey += 1
    }
}

private struct MascotRow: View {
    let name: String
    let source: String
    let desc: String
    let color: Color
    let status: AgentStatus
    let refreshKey: Int
    let onImport: () -> Void
    let onReset: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black)
                    .frame(width: 56, height: 56)
                if CustomMascotStore.path(for: source) != nil {
                    CustomMascotImage(source: source, size: 40)
                } else {
                    MascotView(source: source, status: status, size: 40)
                }
            }
            .id("\(source)-\(refreshKey)")

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                    if let icon = cliIcon(source: source, size: 16) {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 16, height: 16)
                    }
                }
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                if CustomMascotStore.path(for: source) != nil {
                    Text("Custom image")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }

            Spacer()

            Button {
                onImport()
            } label: {
                Image(systemName: "photo.badge.plus")
            }
            .help("Import custom mascot image")
            .buttonStyle(.borderless)

            if CustomMascotStore.path(for: source) != nil {
                Button(role: .destructive) {
                    onReset()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .help("Reset custom mascot image")
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Sound Page

private struct SoundPage: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(SettingsKey.soundEnabled) private var soundEnabled = SettingsDefaults.soundEnabled
    @AppStorage(SettingsKey.soundVolume) private var soundVolume = SettingsDefaults.soundVolume
    @AppStorage(SettingsKey.soundSessionStart) private var soundSessionStart = SettingsDefaults.soundSessionStart
    @AppStorage(SettingsKey.soundTaskComplete) private var soundTaskComplete = SettingsDefaults.soundTaskComplete
    @AppStorage(SettingsKey.soundTaskError) private var soundTaskError = SettingsDefaults.soundTaskError
    @AppStorage(SettingsKey.soundApprovalNeeded) private var soundApprovalNeeded = SettingsDefaults.soundApprovalNeeded
    @AppStorage(SettingsKey.soundPromptSubmit) private var soundPromptSubmit = SettingsDefaults.soundPromptSubmit
    @AppStorage(SettingsKey.soundBoot) private var soundBoot = SettingsDefaults.soundBoot

    var body: some View {
        Form {
            Section {
                Toggle(l10n["enable_sound"], isOn: $soundEnabled)
                if soundEnabled {
                    HStack(spacing: 8) {
                        Text(l10n["volume"])
                        Image(systemName: "speaker.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Slider(
                            value: Binding(
                                get: { Double(soundVolume) },
                                set: { soundVolume = Int($0) }
                            ),
                            in: 0...100,
                            step: 5
                        )
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text("\(soundVolume)%")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }

            if soundEnabled {
                Section(l10n["sessions"]) {
                    SoundEventRow(title: l10n["session_start"], subtitle: l10n["new_claude_session"], soundName: "8bit_start", isOn: $soundSessionStart)
                    SoundEventRow(title: l10n["task_complete"], subtitle: l10n["ai_completed_reply"], soundName: "8bit_complete", isOn: $soundTaskComplete)
                    SoundEventRow(title: l10n["task_error"], subtitle: l10n["tool_or_api_error"], soundName: "8bit_error", isOn: $soundTaskError)
                }

                Section(l10n["interaction"]) {
                    SoundEventRow(title: l10n["approval_needed"], subtitle: l10n["waiting_approval_desc"], soundName: "8bit_approval", isOn: $soundApprovalNeeded)
                    SoundEventRow(title: l10n["task_confirmation"], subtitle: l10n["you_sent_message"], soundName: "8bit_submit", isOn: $soundPromptSubmit)
                }

                Section(l10n["system_section"]) {
                    SoundEventRow(title: l10n["boot_sound"], subtitle: l10n["boot_sound_desc"], soundName: "8bit_boot", isOn: $soundBoot)
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct SoundEventRow: View {
    @ObservedObject private var l10n = L10n.shared
    let title: String
    var subtitle: String? = nil
    let soundName: String
    @Binding var isOn: Bool
    @State private var customPath: String = ""

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if customPath.isEmpty {
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    Text(l10n["custom_sound_set"].replacingOccurrences(of: "%@", with: URL(fileURLWithPath: customPath).lastPathComponent))
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                }
            }
            Spacer(minLength: 16)
            // Choose custom sound
            Menu {
                Button {
                    chooseCustomSound()
                } label: {
                    Label(l10n["choose_sound_file"], systemImage: "folder")
                }
                if !customPath.isEmpty {
                    Button {
                        clearCustomSound()
                    } label: {
                        Label(l10n["reset_to_default"], systemImage: "arrow.counterclockwise")
                    }
                }
            } label: {
                Image(systemName: customPath.isEmpty ? "waveform" : "waveform.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(customPath.isEmpty ? .secondary : Color.orange)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24)
            Button {
                if !customPath.isEmpty {
                    SoundManager.shared.previewCustom(customPath)
                } else {
                    SoundManager.shared.preview(soundName)
                }
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .onAppear {
            customPath = UserDefaults.standard.string(forKey: SettingsKey.soundCustomPath(soundName)) ?? ""
        }
    }

    private func chooseCustomSound() {
        let panel = NSOpenPanel()
        panel.title = l10n["choose_sound_file"]
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            customPath = url.path
            UserDefaults.standard.set(url.path, forKey: SettingsKey.soundCustomPath(soundName))
        }
    }

    private func clearCustomSound() {
        customPath = ""
        UserDefaults.standard.removeObject(forKey: SettingsKey.soundCustomPath(soundName))
    }
}

// MARK: - About Page

private struct AboutPage: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var updater = UpdateChecker.shared

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 24) {
                AppLogoView(size: 100)

                VStack(spacing: 6) {
                    Text("NotchAgent")
                        .font(.system(size: 26, weight: .bold))
                    Text("Version \(AppVersion.current)")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 4) {
                    Text(l10n["about_desc1"])
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                    Text(l10n["about_desc2"])
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                    Text(l10n["about_devs"])
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(l10n["about_credit"])
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 12) {
                    aboutLink("tame.gg", icon: "globe", url: "https://tame.gg")
                    aboutLink("GitHub", icon: "chevron.left.forwardslash.chevron.right", url: "https://github.com/tame-gg")
                }

                // In-app update section
                updateSection
                ReleaseNotesView()

                Button {
                    DiagnosticsExporter.export()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "ladybug")
                            .font(.system(size: 11))
                        Text(l10n["export_diagnostics"])
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                }
                .buttonStyle(.plain)
                .onHover { h in
                    if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
            }
            .frame(maxWidth: .infinity)

            Spacer()
        }
    }

    @ViewBuilder
    private var updateSection: some View {
        switch updater.state {
        case .idle:
            aboutButton(l10n["check_for_updates"], icon: "arrow.triangle.2.circlepath") {
                updater.checkForUpdates()
            }

        case .checking:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(l10n["check_for_updates"])
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

        case .upToDate:
            Button {
                updater.checkForUpdates()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 13))
                    Text(String(format: l10n["no_update_body"], AppVersion.current))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .onHover { h in
                if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }

        case let .available(version):
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.system(size: 13))
                    Text(String(format: l10n["update_available_body"], version, AppVersion.current))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if updater.isHomebrewInstall {
                    HStack(spacing: 8) {
                        Text(l10n["update_homebrew_command"])
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor)))
                        aboutButton(l10n["update_copy_command"], icon: "doc.on.doc") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(l10n["update_homebrew_command"], forType: .string)
                        }
                    }
                } else {
                    // Sparkle owns the download + install alert; this button just
                    // re-surfaces it if the user dismissed it earlier.
                    aboutButton(l10n["update_now"], icon: "arrow.down.to.line") {
                        updater.checkForUpdates()
                    }
                }
            }

        // Download progress and install state are owned by Sparkle's standard
        // UI, not the About page — those enum cases no longer exist.

        case let .failed(message):
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 13))
                    Text(String(format: l10n["update_failed_body"], message))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                aboutButton(l10n["update_retry"], icon: "arrow.clockwise") {
                    updater.checkForUpdates()
                }
            }
        }
    }

    private func aboutButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
        .buttonStyle(.plain)
        .onHover { h in
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }

    private func aboutLink(_ title: String, icon: String, url: String) -> some View {
        aboutButton(title, icon: icon) {
            if let u = URL(string: url) { NSWorkspace.shared.open(u) }
        }
    }
}

private struct GitHubReleaseNotes: Decodable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlURL: URL?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
    }
}

private struct ReleaseNotesView: View {
    @State private var notes: GitHubReleaseNotes?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                releaseButton("Release Notes", icon: "doc.text.magnifyingglass") {
                    Task { await loadLatestReleaseNotes(force: true) }
                }
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let notes {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(notes.name?.isEmpty == false ? notes.name! : notes.tagName)
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        if let htmlURL = notes.htmlURL {
                            Button {
                                NSWorkspace.shared.open(htmlURL)
                            } label: {
                                Image(systemName: "arrow.up.right.square")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    ScrollView {
                        Text(.init(notes.body?.isEmpty == false ? notes.body! : "No release notes were published for this release."))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 150)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }
        }
        .task {
            if notes == nil && errorMessage == nil {
                await loadLatestReleaseNotes(force: false)
            }
        }
    }

    private func releaseButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)))
        }
        .buttonStyle(.plain)
        .onHover { h in
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }

    private func loadLatestReleaseNotes(force: Bool) async {
        if isLoading || (!force && notes != nil) { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let url = URL(string: "https://api.github.com/repos/tame-gg/NotchAgent/releases/latest") else {
            errorMessage = "Invalid release notes URL."
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw NSError(domain: "ReleaseNotesView", code: http.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "GitHub returned HTTP \(http.statusCode)."
                ])
            }
            notes = try JSONDecoder().decode(GitHubReleaseNotes.self, from: data)
        } catch {
            errorMessage = "Could not load GitHub release notes: \(error.localizedDescription)"
        }
    }
}

// MARK: - Behavior Animation Previews

private enum BehaviorAnim {
    case hideFullscreen, hideNoSession, smartSuppress, collapseMouseLeave, clickJumpCollapse, hapticHover
}

struct ClickJumpCollapsePreviewTimeline {
    let expand: Double
    let showClickRing: Bool
    let ringOpacity: Double
    let ringRadius: CGFloat
    let cursorX: CGFloat
    let cursorY: CGFloat
    let clickPointY: CGFloat
    let showSuccessArrow: Bool
    let successArrowOpacity: Double
}

func clickJumpCollapsePreviewTimeline(progress: Double) -> ClickJumpCollapsePreviewTimeline {
    // Wrap to [0,1) so loop seam is identical between end and start.
    let p = progress >= 1 ? progress.truncatingRemainder(dividingBy: 1) : min(1, max(0, progress))

    let clickPointY: CGFloat = 16 // lowered ~20% vs previous ~8

    // Seam-friendly phases:
    // [0.00, 0.08): expanded + cursor very fast move in (from offscreen)
    // [0.08, 0.26): expanded + cursor hover before click
    // [0.26, 0.32): click ring pulse
    // [0.32, 0.47): collapse (match mouse-leave collapse speed)
    // [0.47, 0.62): collapsed hold
    // [0.62, 0.80): cursor moves fully offscreen
    // [0.80, 0.93): expand back (match mouse-leave expand speed, after cursor is offscreen)
    // [0.93, 1.00): fully expanded idle with cursor still offscreen
    let expand: Double
    switch p {
    case ..<0.32:
        expand = 1.0
    case ..<0.47:
        expand = max(0, 1.0 - (p - 0.32) / 0.15)
    case ..<0.80:
        expand = 0
    case ..<0.93:
        expand = min(1, (p - 0.80) / 0.13)
    default:
        expand = 1.0
    }

    // Cursor path: offscreen -> click point -> offscreen, aligned to mouse-leave move-out timing.
    let cursorX: CGFloat
    let cursorY: CGFloat
    switch p {
    case ..<0.08:
        let m = p / 0.08
        cursorX = CGFloat((1 - m) * 34)
        cursorY = CGFloat((1 - m) * 28)
    case ..<0.62:
        cursorX = 0
        cursorY = 0
    case ..<0.80:
        let m = (p - 0.62) / 0.18
        cursorX = CGFloat(m * 34)
        cursorY = CGFloat(m * 28)
    default:
        cursorX = 34
        cursorY = 28
    }

    let ringWindow = p >= 0.26 && p <= 0.32
    let ringPhase = ringWindow ? (p - 0.26) / 0.06 : 0
    let ringOpacity = ringWindow ? sin(ringPhase * .pi) : 0
    let ringRadius: CGFloat = 4 + CGFloat(ringPhase) * 6

    let arrowWindow = p >= 0.34 && p <= 0.42
    let arrowPhase = arrowWindow ? (p - 0.34) / 0.08 : 0
    let arrowOpacity = arrowWindow ? sin(arrowPhase * .pi) : 0

    return ClickJumpCollapsePreviewTimeline(
        expand: expand,
        showClickRing: ringWindow,
        ringOpacity: ringOpacity,
        ringRadius: ringRadius,
        cursorX: cursorX,
        cursorY: cursorY,
        clickPointY: clickPointY,
        showSuccessArrow: arrowWindow,
        successArrowOpacity: arrowOpacity
    )
}

private struct BehaviorToggleRow: View {
    let title: String
    let desc: String
    @Binding var isOn: Bool
    let animation: BehaviorAnim

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                NotchMiniAnim(animation: animation)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(desc)
                }
            }
        }
    }
}

/// Canvas-based notch animation with smooth interpolation.
private struct NotchMiniAnim: View {
    let animation: BehaviorAnim
    private let orange = Color(red: 0.96, green: 0.65, blue: 0.14)

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.03)) { ctx in
            Canvas { c, sz in
                draw(c, sz: sz, t: ctx.date.timeIntervalSinceReferenceDate)
            }
        }
        .frame(width: 72, height: 48)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(Color.secondary.opacity(0.15), lineWidth: 0.5))
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: Double) -> CGFloat {
        a + (b - a) * CGFloat(min(1, max(0, t)))
    }

    private func draw(_ c: GraphicsContext, sz: CGSize, t: Double) {
        switch animation {
        case .hideFullscreen:   drawFullscreen(c, sz: sz, t: t)
        case .hideNoSession:    drawNoSession(c, sz: sz, t: t)
        case .smartSuppress:    drawSuppress(c, sz: sz, t: t)
        case .collapseMouseLeave: drawMouseLeave(c, sz: sz, t: t)
        case .clickJumpCollapse: drawClickJumpCollapse(c, sz: sz, t: t)
        case .hapticHover:      drawHaptic(c, sz: sz, t: t)
        }
    }

    /// Draw a notch pill: smooth w/h/opacity, with orange eyes + content lines when expanded.
    private func drawPill(_ c: GraphicsContext, sz: CGSize,
                          w: CGFloat, h: CGFloat, op: Double,
                          flashColor: Color? = nil) {
        guard op > 0.01 else { return }
        let x = (sz.width - w) / 2
        let r = min(w, h) * 0.45
        let rect = CGRect(x: x, y: 0, width: w, height: h)
        let pill = Path(roundedRect: rect, cornerRadius: r, style: .continuous)
        c.fill(pill, with: .color(Color(white: 0.06).opacity(op)))

        // Eyes — always visible when notch is visible
        let eyeSize: CGFloat = h > 16 ? 3.5 : 2.5
        let eyeY: CGFloat = h > 16 ? 5 : max(2, (h - eyeSize) / 2)
        let eyeGap: CGFloat = h > 16 ? 5 : 3
        c.fill(Path(CGRect(x: sz.width / 2 - eyeGap - eyeSize / 2, y: eyeY,
                           width: eyeSize, height: eyeSize)),
               with: .color(orange.opacity(op)))
        c.fill(Path(CGRect(x: sz.width / 2 + eyeGap - eyeSize / 2, y: eyeY,
                           width: eyeSize, height: eyeSize)),
               with: .color(orange.opacity(op)))

        // Content lines — only when expanded
        if h > 16 {
            let contentOp = op * Double(min(1, (h - 16) / 10))
            let lx = x + 6
            let widths: [CGFloat] = [w * 0.6, w * 0.45, w * 0.55]
            for (i, lw) in widths.enumerated() {
                let ly = 12 + CGFloat(i) * 5
                if ly + 2 < h - 3 {
                    c.fill(Path(CGRect(x: lx, y: ly, width: lw, height: 2)),
                           with: .color(.white.opacity(0.3 * contentOp * (1 - Double(i) * 0.2))))
                }
            }
        }

        // Flash overlay
        if let color = flashColor {
            c.fill(pill, with: .color(color))
        }
    }

    // 1) Fullscreen: notch visible → screen dims → notch fades → restore
    private func drawFullscreen(_ c: GraphicsContext, sz: CGSize, t: Double) {
        let cycle = t.truncatingRemainder(dividingBy: 3.5) / 3.5
        let vis: Double = cycle < 0.3 ? 1.0 :
            cycle < 0.45 ? 1.0 - (cycle - 0.3) / 0.15 :
            cycle < 0.7 ? 0.0 :
            min(1, (cycle - 0.7) / 0.15)
        // Fullscreen dimming overlay
        if vis < 0.95 {
            c.fill(Path(CGRect(origin: .zero, size: sz)),
                   with: .color(Color(white: 0.08).opacity(0.85 * (1 - vis))))
            // Fullscreen icon
            let iconOp = cycle > 0.45 && cycle < 0.65 ?
                sin((cycle - 0.45) / 0.2 * .pi) * 0.5 : 0
            if iconOp > 0.01 {
                c.draw(Text("⛶").font(.system(size: 16)).foregroundColor(.white.opacity(iconOp)),
                       at: CGPoint(x: sz.width / 2, y: sz.height / 2 + 2))
            }
        }
        drawPill(c, sz: sz, w: 28, h: 10, op: vis)
    }

    // 2) No session: green dots vanish → notch fades
    private func drawNoSession(_ c: GraphicsContext, sz: CGSize, t: Double) {
        let cycle = t.truncatingRemainder(dividingBy: 3.5) / 3.5
        let dotOp: Double = cycle < 0.25 ? 1.0 :
            cycle < 0.4 ? 1.0 - (cycle - 0.25) / 0.15 :
            cycle < 0.7 ? 0.0 :
            min(1, (cycle - 0.7) / 0.15)
        let pillOp: Double = cycle < 0.35 ? 1.0 :
            cycle < 0.55 ? 1.0 - (cycle - 0.35) / 0.2 :
            cycle < 0.7 ? 0.0 :
            min(1, (cycle - 0.7) / 0.15)

        drawPill(c, sz: sz, w: 28, h: 10, op: pillOp)
        // Green session dots
        if dotOp > 0.01 {
            let cx = sz.width / 2
            for i in 0..<2 {
                let dx: CGFloat = CGFloat(i) * 6 - 3
                c.fill(Path(ellipseIn: CGRect(x: cx + dx - 1.5, y: 3, width: 3, height: 3)),
                       with: .color(.green.opacity(0.85 * dotOp * pillOp)))
            }
        }
    }

    // 3) Smart suppress: event flash → notch pulses but stays collapsed → × indicator
    private func drawSuppress(_ c: GraphicsContext, sz: CGSize, t: Double) {
        let cycle = t.truncatingRemainder(dividingBy: 3.0) / 3.0
        // Two event pulses
        let p1 = (cycle > 0.15 && cycle < 0.4) ? sin((cycle - 0.15) / 0.25 * .pi) : 0.0
        let p2 = (cycle > 0.55 && cycle < 0.75) ? sin((cycle - 0.55) / 0.2 * .pi) : 0.0
        let pulse = max(p1, p2)
        let pw = 28 + CGFloat(pulse) * 8
        let ph: CGFloat = 10 + CGFloat(pulse) * 3

        let flashColor: Color? = pulse > 0.05 ? .green.opacity(0.3 * pulse) : nil
        drawPill(c, sz: sz, w: pw, h: ph, op: 1.0, flashColor: flashColor)

        // × suppress indicator
        let xOp1 = (cycle > 0.3 && cycle < 0.48) ? sin((cycle - 0.3) / 0.18 * .pi) : 0.0
        let xOp2 = (cycle > 0.68 && cycle < 0.82) ? sin((cycle - 0.68) / 0.14 * .pi) : 0.0
        let xOp = max(xOp1, xOp2)
        if xOp > 0.01 {
            c.draw(Text("✕").font(.system(size: 9, weight: .bold))
                    .foregroundColor(.orange.opacity(0.7 * xOp)),
                   at: CGPoint(x: sz.width / 2, y: 18))
        }
    }

    // 4) Mouse leave: cursor enters → expand → cursor leaves → collapse
    private func drawMouseLeave(_ c: GraphicsContext, sz: CGSize, t: Double) {
        let cycle = t.truncatingRemainder(dividingBy: 3.5) / 3.5
        // Expand amount: 0→1→0
        let expand: Double = cycle < 0.12 ? 0 :
            cycle < 0.25 ? (cycle - 0.12) / 0.13 :
            cycle < 0.5 ? 1.0 :
            cycle < 0.65 ? 1.0 - (cycle - 0.5) / 0.15 : 0

        let pw = lerp(28, 64, expand)
        let ph = lerp(10, 34, expand)
        drawPill(c, sz: sz, w: pw, h: ph, op: 1.0)

        // Mouse cursor
        let cursorPhase = cycle
        let cursorVis = cursorPhase > 0.05 && cursorPhase < 0.68
        if cursorVis {
            let cx: CGFloat, cy: CGFloat
            if cursorPhase < 0.12 {
                // Moving toward notch
                let t = (cursorPhase - 0.05) / 0.07
                cx = lerp(sz.width / 2 + 15, sz.width / 2 + 2, t)
                cy = lerp(sz.height - 5, 8, t)
            } else if cursorPhase < 0.5 {
                // Hovering near notch
                cx = sz.width / 2 + 2
                cy = lerp(8, 6, expand)
            } else {
                // Moving away
                let t = (cursorPhase - 0.5) / 0.18
                cx = lerp(sz.width / 2 + 2, sz.width - 2, min(1, t))
                cy = lerp(6, sz.height - 2, min(1, t))
            }
            // Draw cursor arrow
            var arrow = Path()
            arrow.move(to: CGPoint(x: cx, y: cy))
            arrow.addLine(to: CGPoint(x: cx, y: cy + 8))
            arrow.addLine(to: CGPoint(x: cx + 2.5, y: cy + 6))
            arrow.addLine(to: CGPoint(x: cx + 5.5, y: cy + 6))
            arrow.closeSubpath()
            c.fill(arrow, with: .color(.white.opacity(0.9)))
            c.stroke(arrow, with: .color(.black.opacity(0.4)), lineWidth: 0.5)
        }
    }

    // 5) Click jump: panel starts expanded -> cursor clicks with ring -> collapse hold -> seamless loop
    private func drawClickJumpCollapse(_ c: GraphicsContext, sz: CGSize, t: Double) {
        let cycle = t.truncatingRemainder(dividingBy: 3.5) / 3.5
        let timeline = clickJumpCollapsePreviewTimeline(progress: cycle)

        let pw = lerp(28, 64, timeline.expand)
        let ph = lerp(10, 34, timeline.expand)
        drawPill(c, sz: sz, w: pw, h: ph, op: 1.0)

        if timeline.showClickRing {
            let r = timeline.ringRadius
            let circle = Path(ellipseIn: CGRect(
                x: sz.width / 2 - r,
                y: timeline.clickPointY - r / 2,
                width: r * 2,
                height: r * 2
            ))
            c.stroke(circle, with: .color(.white.opacity(0.45 * timeline.ringOpacity)), lineWidth: 1)
        }

        if timeline.showSuccessArrow {
            c.draw(
                Text("↗").font(.system(size: 10, weight: .bold)).foregroundColor(.green.opacity(0.75 * timeline.successArrowOpacity)),
                at: CGPoint(x: sz.width / 2 + 13, y: timeline.clickPointY + 10)
            )
        }

        let cx = sz.width / 2 + 2 + timeline.cursorX
        let cy = timeline.clickPointY + timeline.cursorY
        var arrow = Path()
        arrow.move(to: CGPoint(x: cx, y: cy))
        arrow.addLine(to: CGPoint(x: cx, y: cy + 8))
        arrow.addLine(to: CGPoint(x: cx + 2.5, y: cy + 6))
        arrow.addLine(to: CGPoint(x: cx + 5.5, y: cy + 6))
        arrow.closeSubpath()
        c.fill(arrow, with: .color(.white.opacity(0.9)))
        c.stroke(arrow, with: .color(.black.opacity(0.4)), lineWidth: 0.5)
    }

    // 6) Haptic: cursor enters → notch shakes briefly (vibration effect)
    private func drawHaptic(_ c: GraphicsContext, sz: CGSize, t: Double) {
        let cycle = t.truncatingRemainder(dividingBy: 2.5) / 2.5

        // Cursor approaches and hovers
        let cursorIn = cycle > 0.05 && cycle < 0.55
        // Shake phase: short burst when cursor first arrives
        let shakePhase = (cycle > 0.15 && cycle < 0.35)
        let shakeOffset: CGFloat = shakePhase
            ? CGFloat(sin(cycle * 180)) * 2.5
            : 0

        drawPill(c, sz: CGSize(width: sz.width + shakeOffset, height: sz.height),
                 w: 28, h: 10, op: 1.0)

        // Vibration lines (radiating from notch during shake)
        if shakePhase {
            let lineOp = sin((cycle - 0.15) / 0.2 * .pi)
            let cx = sz.width / 2
            for dx: CGFloat in [-10, -6, 6, 10] {
                let x = cx + dx + shakeOffset / 2
                c.fill(Path(CGRect(x: x, y: 13, width: 0.8, height: 3)),
                       with: .color(orange.opacity(0.6 * lineOp)))
            }
        }

        // Mouse cursor
        if cursorIn {
            let cx: CGFloat, cy: CGFloat
            if cycle < 0.15 {
                let p = (cycle - 0.05) / 0.1
                cx = lerp(sz.width / 2 + 15, sz.width / 2 + 2, p)
                cy = lerp(sz.height - 5, 8, p)
            } else {
                cx = sz.width / 2 + 2
                cy = 8
            }
            var arrow = Path()
            arrow.move(to: CGPoint(x: cx, y: cy))
            arrow.addLine(to: CGPoint(x: cx, y: cy + 8))
            arrow.addLine(to: CGPoint(x: cx + 2.5, y: cy + 6))
            arrow.addLine(to: CGPoint(x: cx + 5.5, y: cy + 6))
            arrow.closeSubpath()
            c.fill(arrow, with: .color(.white.opacity(0.9)))
            c.stroke(arrow, with: .color(.black.opacity(0.4)), lineWidth: 0.5)
        }
    }
}

// MARK: - App Logo

struct AppLogoView: View {
    var size: CGFloat = 100
    var showBackground: Bool = true
    private let orange = Color(red: 0.96, green: 0.65, blue: 0.14)

    var body: some View {
        Canvas { ctx, sz in
            // macOS icon standard: ~10% padding on each side
            let inset = sz.width * 0.1
            let contentRect = CGRect(x: inset, y: inset, width: sz.width - inset * 2, height: sz.height - inset * 2)
            let px = contentRect.width / 16
            if showBackground {
                let bgPath = Path(roundedRect: contentRect, cornerRadius: contentRect.width * 0.22, style: .continuous)
                ctx.fill(bgPath, with: .color(.white))
            }
            // Notch pill
            let pillColor = showBackground ? Color(white: 0.1) : Color(white: 0.5)
            let pillRect = CGRect(x: contentRect.minX + px * 3, y: contentRect.minY + px * 6, width: px * 10, height: px * 4)
            ctx.fill(Path(roundedRect: pillRect, cornerRadius: px * 2, style: .continuous), with: .color(pillColor))
            // Eyes
            ctx.fill(Path(CGRect(x: contentRect.minX + px * 5, y: contentRect.minY + px * 7, width: px * 2, height: px * 2)), with: .color(orange))
            ctx.fill(Path(CGRect(x: contentRect.minX + px * 9, y: contentRect.minY + px * 7, width: px * 2, height: px * 2)), with: .color(orange))
            // Pupils
            ctx.fill(Path(CGRect(x: contentRect.minX + px * 6, y: contentRect.minY + px * 7, width: px, height: px)), with: .color(.white))
            ctx.fill(Path(CGRect(x: contentRect.minX + px * 10, y: contentRect.minY + px * 7, width: px, height: px)), with: .color(.white))
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(showBackground ? 0.15 : 0), radius: size * 0.12, y: size * 0.04)
    }
}

// MARK: - Shortcuts Page

private struct ShortcutsPage: View {
    @ObservedObject private var l10n = L10n.shared
    @State private var recordingAction: ShortcutAction?
    @State private var eventMonitor: Any?
    @State private var refreshKey = 0

    var body: some View {
        Form {
            Section {
                ForEach(ShortcutAction.allCases) { action in
                    ShortcutRow(
                        action: action,
                        isRecording: recordingAction == action,
                        onStartRecording: { startRecording(action) },
                        onClear: { clearBinding(action) }
                    )
                    .id("\(action.rawValue)-\(refreshKey)")
                }
            }
        }
        .formStyle(.grouped)
        .onDisappear { stopRecording() }
    }

    private func startRecording(_ action: ShortcutAction) {
        stopRecording()
        recordingAction = action
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Escape — cancel
                self.stopRecording()
                return nil
            }
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard mods.contains(.command) || mods.contains(.control) || mods.contains(.option) else {
                return nil
            }
            action.setBinding(keyCode: event.keyCode, modifiers: mods)
            if !action.isEnabled { action.setEnabled(true) }
            self.stopRecording()
            self.refreshKey += 1
            self.notifyChange()
            return nil
        }
    }

    private func clearBinding(_ action: ShortcutAction) {
        action.setEnabled(false)
        refreshKey += 1
        notifyChange()
    }

    private func stopRecording() {
        if let m = eventMonitor {
            NSEvent.removeMonitor(m)
            eventMonitor = nil
        }
        recordingAction = nil
    }

    private func notifyChange() {
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.setupGlobalShortcut()
        }
    }
}

private struct ShortcutRow: View {
    let action: ShortcutAction
    let isRecording: Bool
    let onStartRecording: () -> Void
    let onClear: () -> Void
    @ObservedObject private var l10n = L10n.shared

    private var conflict: ShortcutAction? { action.conflictingAction() }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(l10n["shortcut_\(action.rawValue)"])
                Text(l10n["shortcut_\(action.rawValue)_desc"])
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let conflict {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text("\(l10n["shortcut_conflict"]) \(l10n["shortcut_\(conflict.rawValue)"])")
                            .font(.caption)
                    }
                    .foregroundStyle(.orange)
                }
            }
            Spacer()
            if isRecording {
                Text(l10n["shortcut_recording"])
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).stroke(.orange, lineWidth: 1))
            } else if action.isEnabled {
                HStack(spacing: 6) {
                    Text(action.binding.displayString)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary))
                        .onTapGesture { onStartRecording() }

                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text(l10n["shortcut_none"])
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary))
                    .onTapGesture { onStartRecording() }
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - CLI Page

private enum CLIInstallPaths {
    static let primaryCLIName = "notchagent"
    static let legacyCLIName = "notchagent-cli"

    static var installDir: String {
        "\(NSHomeDirectory())/.notchagent"
    }

    static var primaryInstallPath: String {
        "\(installDir)/\(primaryCLIName)"
    }

    static var legacyInstallPath: String {
        "\(installDir)/\(legacyCLIName)"
    }

    static func bundledExecutablePath(fileManager fm: FileManager = .default) -> String? {
        var candidates: [String] = []
        if let path = Bundle.main.path(forAuxiliaryExecutable: legacyCLIName) {
            candidates.append(path)
        }

        candidates.append(Bundle.main.bundlePath + "/Contents/Helpers/\(legacyCLIName)")
        if let executablePath = Bundle.main.executablePath {
            candidates.append((executablePath as NSString).deletingLastPathComponent + "/\(legacyCLIName)")
        }

        return candidates.first { fm.isExecutableFile(atPath: $0) }
    }
}

private struct CLIPage: View {
    @ObservedObject private var l10n = L10n.shared
    @State private var installStatus = ""
    @State private var isInstalled = false

    private let cliCommands: [(name: String, desc: String)] = [
        ("status", "Show current surface, active sessions, and pending approvals/questions"),
        ("list", "List all sessions with source, project, status, and estimated cost"),
        ("toggle", "Toggle panel between collapsed and session-list"),
        ("approve", "Approve the first pending permission request"),
        ("deny", "Deny the first pending permission request"),
        ("collapse", "Collapse the panel immediately"),
    ]

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(l10n["cli_desc"])
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Button {
                            installCLI()
                        } label: {
                            Label(l10n["cli_install_button"], systemImage: "terminal.fill")
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            copyCLIPath()
                        } label: {
                            Label(l10n["cli_copy_path"], systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                    }

                    HStack(spacing: 12) {
                        Button {
                            addToPath()
                        } label: {
                            Label(l10n["cli_add_to_path"], systemImage: "folder.badge.plus")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            installCompletions()
                        } label: {
                            Label(l10n["cli_install_completions"], systemImage: "checkmark.circle.badge.questionmark.fill")
                        }
                        .buttonStyle(.bordered)
                    }

                    if !installStatus.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: isInstalled ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(isInstalled ? .green : .red)
                            Text(installStatus)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section(l10n["cli_commands_title"]) {
                ForEach(cliCommands, id: \.name) { cmd in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(cmd.name)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.green)
                            Spacer()
                        }
                        Text(cmd.desc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section(l10n["cli_usage_title"]) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("notchagent status")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor)))
                    Text("notchagent toggle")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor)))
                    Text("notchagent approve")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor)))
                }
            }
        }
        .formStyle(.grouped)
    }

    private func installCLI() {
        let fm = FileManager.default
        let targetDir = CLIInstallPaths.installDir
        let targetBin = CLIInstallPaths.primaryInstallPath
        let legacyTargetBin = CLIInstallPaths.legacyInstallPath

        do {
            try? fm.createDirectory(atPath: targetDir, withIntermediateDirectories: true)

            let sourceBin = CLIInstallPaths.bundledExecutablePath(fileManager: fm)
                ?? (!fm.fileExists(atPath: targetBin) && fm.fileExists(atPath: legacyTargetBin) ? legacyTargetBin : nil)

            guard let sourceBin else {
                if fm.fileExists(atPath: targetBin) {
                    try ensureLegacyCLIAlias(fileManager: fm)
                    installStatus = l10n["cli_install_success"]
                    isInstalled = true
                    return
                }
                installStatus = l10n["cli_install_missing_binary"]
                isInstalled = false
                return
            }

            if fm.fileExists(atPath: targetBin), sourceBin != targetBin {
                try fm.removeItem(atPath: targetBin)
            }
            if sourceBin != targetBin {
                try fm.copyItem(atPath: sourceBin, toPath: targetBin)
            }
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: targetBin)
            try ensureLegacyCLIAlias(fileManager: fm)
            installStatus = l10n["cli_install_success"]
            isInstalled = true
        } catch {
            installStatus = "\(l10n["cli_install_failed"]): \(error.localizedDescription)"
            isInstalled = false
        }
    }

    private func ensureLegacyCLIAlias(fileManager fm: FileManager) throws {
        let targetBin = CLIInstallPaths.primaryInstallPath
        let legacyTargetBin = CLIInstallPaths.legacyInstallPath
        if fm.fileExists(atPath: legacyTargetBin) {
            try fm.removeItem(atPath: legacyTargetBin)
        }
        do {
            try fm.createSymbolicLink(atPath: legacyTargetBin, withDestinationPath: targetBin)
        } catch {
            try fm.copyItem(atPath: targetBin, toPath: legacyTargetBin)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: legacyTargetBin)
        }
    }

    private func copyCLIPath() {
        let path = CLIInstallPaths.primaryInstallPath
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
    }

    private func addToPath() {
        let home = NSHomeDirectory()
        let fm = FileManager.default
        guard fm.fileExists(atPath: CLIInstallPaths.primaryInstallPath) else {
            installStatus = l10n["cli_add_path_not_installed"]
            isInstalled = false
            return
        }

        // Detect shell and config file
        let shell = (ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh").lowercased()
        let configPath: String
        if shell.contains("zsh") {
            configPath = "\(home)/.zshrc"
        } else if shell.contains("bash") {
            configPath = "\(home)/.bash_profile"
        } else if shell.contains("fish") {
            configPath = "\(home)/.config/fish/config.fish"
        } else {
            configPath = "\(home)/.profile"
        }

        let exportLine = "export PATH=\"$HOME/.notchagent:$PATH\""

        do {
            var existing = ""
            if fm.fileExists(atPath: configPath) {
                existing = (try? String(contentsOfFile: configPath, encoding: .utf8)) ?? ""
            }
            if existing.contains("$HOME/.notchagent") || existing.contains("\\.notchagent") {
                installStatus = l10n["cli_add_path_already"]
                isInstalled = true
                return
            }
            let updated = existing.isEmpty ? "\(exportLine)\n" : "\(existing)\n# Added by NotchAgent\n\(exportLine)\n"
            try updated.write(toFile: configPath, atomically: true, encoding: .utf8)
            installStatus = String(format: l10n["cli_add_path_success"], configPath)
            isInstalled = true
        } catch {
            installStatus = "\(l10n["cli_add_path_failed"]): \(error.localizedDescription)"
            isInstalled = false
        }
    }

    private func installCompletions() {
        let home = NSHomeDirectory()
        let fm = FileManager.default
        guard fm.fileExists(atPath: CLIInstallPaths.primaryInstallPath) else {
            installStatus = l10n["cli_completions_not_installed"]
            isInstalled = false
            return
        }

        // Bash completions
        let bashDir = "\(home)/.bash_completion.d"
        let bashPath = "\(bashDir)/notchagent"
        let bashScript = """
        #!/bin/bash
        _notchagent() {
            local cur prev opts
            COMPREPLY=()
            cur="${COMP_WORDS[COMP_CWORD]}"
            prev="${COMP_WORDS[COMP_CWORD-1]}"
            opts="status list toggle approve deny collapse completion help"
            COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            return 0
        }
        complete -F _notchagent notchagent notchagent-cli
        """
        do {
            try? fm.createDirectory(atPath: bashDir, withIntermediateDirectories: true)
            try bashScript.write(toFile: bashPath, atomically: true, encoding: .utf8)
        } catch {
            installStatus = "\(l10n["cli_completions_failed"]): \(error.localizedDescription)"
            isInstalled = false
            return
        }

        // Zsh completions
        let zshDir = "\(home)/.zsh/completions"
        let zshPath = "\(zshDir)/_notchagent"
        let zshScript = """
        #compdef notchagent notchagent-cli

        _notchagent() {
            local -a commands
            commands=(
                'status:Show current surface and active sessions'
                'list:List all sessions'
                'toggle:Toggle panel visibility'
                'approve:Approve pending permission'
                'deny:Deny pending permission'
                'collapse:Collapse the panel'
                'completion:Print shell completion script'
                'help:Show help'
            )
            _describe -t commands 'notchagent commands' commands
        }

        compdef _notchagent notchagent notchagent-cli
        """
        do {
            try? fm.createDirectory(atPath: zshDir, withIntermediateDirectories: true)
            try zshScript.write(toFile: zshPath, atomically: true, encoding: .utf8)
        } catch {
            installStatus = "\(l10n["cli_completions_failed"]): \(error.localizedDescription)"
            isInstalled = false
            return
        }

        installStatus = l10n["cli_completions_success"]
        isInstalled = true
    }
}
