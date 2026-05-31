# NotchAgent CLI Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make bare `notchagent` open a live dashboard-style terminal UI while preserving existing one-shot CLI commands.

**Architecture:** Reuse the existing Unix socket command channel. Add a richer `snapshot` command on the app side, then split the CLI into focused files for socket IO, decoded dashboard data, pure rendering, terminal raw-mode control, and the interactive loop.

**Tech Stack:** Swift Package Manager, Swift 5.9, Foundation, Darwin termios/poll APIs, XCTest where the local toolchain supports it.

---

## File Structure

- Modify `Sources/NotchAgent/AppState.swift`: extend `handleCommand(_:)` with `snapshot`, session-scoped `approve` / `deny`, and `activate`.
- Create `Sources/NotchAgentCLI/CLIClient.swift`: reusable Unix socket request/response client moved out of `main.swift`.
- Create `Sources/NotchAgentCLI/DashboardTypes.swift`: `Codable` models for snapshot responses and small formatting helpers.
- Create `Sources/NotchAgentCLI/DashboardModel.swift`: selection, filtering, and decoded-state helpers.
- Create `Sources/NotchAgentCLI/DashboardRenderer.swift`: pure string-buffer renderer with no socket or terminal side effects.
- Create `Sources/NotchAgentCLI/TerminalController.swift`: alternate screen, raw mode, resize, cursor cleanup.
- Create `Sources/NotchAgentCLI/DashboardApp.swift`: polling loop, key handling, action dispatch, redraw scheduling.
- Modify `Sources/NotchAgentCLI/main.swift`: keep subcommands, launch `DashboardApp` when no args are passed.
- Add tests if SwiftPM XCTest is usable in the active developer environment. If XCTest remains blocked by CommandLineTools, verify with `swift build -c release` and targeted CLI smoke commands.

## Task 1: App Snapshot Protocol

**Files:**
- Modify: `Sources/NotchAgent/AppState.swift`

- [ ] **Step 1: Add a snapshot branch to `handleCommand(_:)`**

Implement `case "snapshot"` in `handleCommand(_:)`. The payload must include:

```swift
[
    "surface": String(describing: surface),
    "activeSessionId": activeSessionId ?? NSNull(),
    "totalSessions": sessions.count,
    "activeSessions": sessions.values.filter { $0.status != .idle }.count,
    "pendingPermissions": permissionQueue.count,
    "pendingQuestions": questionQueue.count,
    "sessions": sessions.map { id, session in
        [
            "id": id,
            "source": session.source,
            "sourceLabel": session.sourceLabel,
            "project": session.projectDisplayName,
            "status": String(describing: session.status),
            "tool": session.currentTool ?? NSNull(),
            "toolDescription": session.toolDescription ?? NSNull(),
            "cost": session.estimatedCost,
            "cwd": session.cwd ?? NSNull(),
            "model": session.model ?? NSNull(),
            "permissionMode": session.permissionMode ?? NSNull(),
            "startTime": session.startTime.timeIntervalSince1970,
            "lastActivity": session.lastActivity.timeIntervalSince1970,
            "toolCallCount": session.totalToolCallCount,
            "hasPendingPermission": permissionQueue.contains { $0.event.sessionId == id },
            "hasPendingQuestion": questionQueue.contains { $0.event.sessionId == id },
            "recentTools": session.toolHistory.suffix(8).map { entry in
                [
                    "tool": entry.tool,
                    "description": entry.description ?? NSNull(),
                    "success": entry.success,
                    "agentType": entry.agentType ?? NSNull(),
                    "timestamp": entry.timestamp.timeIntervalSince1970,
                ] as [String: Any]
            },
            "recentMessages": session.recentMessages.suffix(3).map { msg in
                [
                    "role": msg.role,
                    "text": msg.text,
                    "timestamp": msg.timestamp.timeIntervalSince1970,
                ] as [String: Any]
            },
        ] as [String: Any]
    }
]
```

- [ ] **Step 2: Add session-scoped actions**

Extend `approve` and `deny` command parsing so `approve <sessionId>` and `deny <sessionId>` prefer the first matching queued permission for that session. Existing `approve` and `deny` without arguments still call the global behavior.

- [ ] **Step 3: Add `activate <sessionId>`**

When a session id exists, call `TerminalActivator.activate(session:sessionId:)` and return `{"ok":true}`. For missing ids return `{"error":"session_not_found"}`.

- [ ] **Step 4: Build**

Run: `swift build -c release`

Expected: build succeeds. If XCTest is blocked by CommandLineTools, note that and continue with build verification.

- [ ] **Step 5: Commit**

Run:

```bash
git add Sources/NotchAgent/AppState.swift
git commit --no-gpg-sign -m "Add CLI dashboard snapshot command"
```

## Task 2: CLI Client and Dashboard Models

**Files:**
- Create: `Sources/NotchAgentCLI/CLIClient.swift`
- Create: `Sources/NotchAgentCLI/DashboardTypes.swift`
- Create: `Sources/NotchAgentCLI/DashboardModel.swift`
- Modify: `Sources/NotchAgentCLI/main.swift`

- [ ] **Step 1: Move socket code to `CLIClient`**

Create a `CLIClient` type with:

```swift
struct CLIClient {
    func sendCommand(_ command: String) -> Data?
    func decodedJSONCommand(_ command: String) -> [String: Any]?
}
```

Move the existing Unix socket implementation from `main.swift` without changing behavior.

- [ ] **Step 2: Add typed snapshot models**

Create `DashboardSnapshot`, `DashboardSession`, `DashboardTool`, and `DashboardMessage` as `Decodable` structs. Use optional fields for any app value that can be absent or `null`.

- [ ] **Step 3: Add dashboard state**

Create `DashboardModel` with:

```swift
struct DashboardModel {
    var snapshot: DashboardSnapshot?
    var selectedIndex: Int = 0
    var filter: String = ""
    var statusMessage: String?
    var isFiltering: Bool = false

    var visibleSessions: [DashboardSession] { get }
    mutating func moveSelection(delta: Int)
    mutating func clampSelection()
    var selectedSession: DashboardSession? { get }
}
```

Filtering must match source label, source id, project, status, and session id case-insensitively.

- [ ] **Step 4: Wire old commands through `CLIClient`**

Replace `sendCommand(_:)` in `main.swift` with `CLIClient().sendCommand(_:)`. Existing command output must remain JSON.

- [ ] **Step 5: Build**

Run: `swift build -c release`

Expected: build succeeds.

- [ ] **Step 6: Commit**

Run:

```bash
git add Sources/NotchAgentCLI/CLIClient.swift Sources/NotchAgentCLI/DashboardTypes.swift Sources/NotchAgentCLI/DashboardModel.swift Sources/NotchAgentCLI/main.swift
git commit --no-gpg-sign -m "Add CLI dashboard models"
```

## Task 3: Pure Dashboard Renderer

**Files:**
- Create: `Sources/NotchAgentCLI/DashboardRenderer.swift`

- [ ] **Step 1: Implement renderer API**

Create:

```swift
struct TerminalSize {
    var columns: Int
    var rows: Int
}

struct DashboardRenderer {
    func render(model: DashboardModel, size: TerminalSize, now: Date = Date()) -> String
}
```

- [ ] **Step 2: Implement table rendering**

Render a header, table rows, detail panel for selected session, and footer. Truncate columns with an ellipsis-free ASCII strategy so output remains ASCII.

- [ ] **Step 3: Implement disconnected and tiny-terminal states**

When `model.snapshot == nil`, render a disconnected panel with the socket path and `q quit  r retry`.

When `size.columns < 72 || size.rows < 16`, render `Resize terminal to at least 72x16` plus the current size.

- [ ] **Step 4: Build**

Run: `swift build -c release`

Expected: build succeeds.

- [ ] **Step 5: Commit**

Run:

```bash
git add Sources/NotchAgentCLI/DashboardRenderer.swift
git commit --no-gpg-sign -m "Render CLI dashboard"
```

## Task 4: Terminal Controller and Input Loop

**Files:**
- Create: `Sources/NotchAgentCLI/TerminalController.swift`
- Create: `Sources/NotchAgentCLI/DashboardApp.swift`
- Modify: `Sources/NotchAgentCLI/main.swift`

- [ ] **Step 1: Add terminal control**

Implement raw mode using `termios`, alternate screen with `\u{001B}[?1049h`, cursor hide/show, clear screen, and guaranteed restore through `defer`.

- [ ] **Step 2: Add key reading**

Implement key decoding for:

```swift
enum DashboardKey {
    case quit
    case up
    case down
    case first
    case last
    case refresh
    case approve
    case deny
    case activate
    case filter
    case help
    case escape
    case backspace
    case printable(Character)
    case unknown
}
```

Support `j/k`, arrow keys, `g/G`, `r`, `a`, `d`, `Enter`, `/`, `?`, `Esc`, backspace, `q`, and `Ctrl-C`.

- [ ] **Step 3: Add dashboard app loop**

`DashboardApp.run()` should:

- enter alternate screen and raw mode.
- poll `snapshot` immediately and every second.
- redraw after snapshots, resize, and key actions.
- keep a disconnected state instead of exiting when the app socket is unavailable.
- refresh immediately after `approve`, `deny`, and `activate`.

- [ ] **Step 4: Launch dashboard for bare command**

In `main.swift`, if `CommandLine.arguments.count == 1`, run `DashboardApp(client: CLIClient()).run()` and exit with its return code.

- [ ] **Step 5: Build and smoke test**

Run:

```bash
swift build -c release
.build/release/notchagent-cli status
```

Expected: build succeeds; `status` either prints JSON from a running app or the existing connection error.

- [ ] **Step 6: Commit**

Run:

```bash
git add Sources/NotchAgentCLI/TerminalController.swift Sources/NotchAgentCLI/DashboardApp.swift Sources/NotchAgentCLI/main.swift
git commit --no-gpg-sign -m "Launch interactive CLI dashboard"
```

## Task 5: Verification and Polish

**Files:**
- Review: `Sources/NotchAgentCLI/CLIClient.swift`
- Review: `Sources/NotchAgentCLI/DashboardApp.swift`
- Review: `Sources/NotchAgentCLI/DashboardModel.swift`
- Review: `Sources/NotchAgentCLI/DashboardRenderer.swift`
- Review: `Sources/NotchAgentCLI/DashboardTypes.swift`
- Review: `Sources/NotchAgentCLI/TerminalController.swift`
- Review: `Sources/NotchAgentCLI/main.swift`
- Review: `Sources/NotchAgent/AppState.swift`

- [ ] **Step 1: Verify existing commands**

Run:

```bash
swift build -c release
.build/release/notchagent-cli help
.build/release/notchagent-cli completion zsh
```

Expected: help and completion still print plain text.

- [ ] **Step 2: Verify dashboard manually**

Run:

```bash
.build/release/notchagent-cli
```

Expected: dashboard enters alternate screen, shows connected or disconnected state, responds to `?`, `r`, movement keys, and exits cleanly with `q`.

- [ ] **Step 3: Verify package build**

Run:

```bash
swift build -c release
```

Expected: build succeeds.

- [ ] **Step 4: Final commit**

Run:

```bash
git status --short
git add Sources/NotchAgent Sources/NotchAgentCLI
git commit --no-gpg-sign -m "Polish CLI dashboard"
```

Only create this final commit if there are additional polish changes after Task 4.
