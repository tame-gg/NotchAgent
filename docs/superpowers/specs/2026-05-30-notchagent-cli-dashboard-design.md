# NotchAgent CLI Dashboard Design

Date: 2026-05-30

## Goal

Make bare `notchagent` open a live dashboard-style terminal UI for monitoring and controlling running NotchAgent sessions. Existing one-shot commands remain available for scripts and shell automation.

The first version is dashboard-first, closer to `top`/`htop`/`btop` than to a chat REPL. It borrows Claude Code CLI ideas only where they fit: a concise status line, keyboard-driven controls, and a command/help overlay.

## Non-Goals

- Do not replace the macOS menu bar app or notch panel.
- Do not remove existing CLI commands such as `status`, `list`, `approve`, `deny`, `toggle`, or `collapse`.
- Do not build a full chat prompt or transcript editor in the first version.
- Do not require third-party services or network access.

## User Experience

Running `notchagent` with no arguments enters an alternate-screen terminal dashboard. The UI exits cleanly on `q`, `Ctrl-C`, or terminal close, restoring cursor visibility and terminal mode.

The layout is:

```text
NotchAgent                                                     connected  8 sessions  2 pending
-----------------------------------------------------------------------------------------------
Source       Project              Status          Tool              Cost       Last Activity
> codex      NotchAgent           waiting         apply_patch       $0.23      5s
  claude     tame-stats           processing      Edit              $1.08      42s
  opencode   keila                idle            -                 $0.04      8m

-----------------------------------------------------------------------------------------------
Session
id: 019...      source: codex      cwd: /Users/andrew/Code/NotchAgent
status: waiting approval           model: gpt-5-codex
current tool: apply_patch          approvals: 2 total, 0 denied

Recent tools
17:42 apply_patch  success  Sources/NotchAgentCLI/main.swift
17:41 read         success  Sources/NotchAgent/AppState.swift

q quit  j/k move  enter jump  a approve  d deny  r refresh  / filter  ? help
```

The main table always stays usable on narrower terminals. When space is limited, the detail panel is reduced before the table is reduced. If the terminal is below the minimum practical size, the CLI shows a clear resize message and keeps listening for resize events.

## Keyboard Controls

- `q` or `Ctrl-C`: exit dashboard.
- `j` / `k` and arrow keys: move selection.
- `g` / `G`: first or last row.
- `r`: refresh immediately.
- `a`: approve the selected session's first pending permission, or the global first pending permission when no row-specific permission is available.
- `d`: deny the selected session's first pending permission, or the global first pending permission when no row-specific permission is available.
- `Enter`: activate or jump to the selected session's terminal when the app has terminal metadata; otherwise toggle the NotchAgent panel to that session if supported.
- `/`: open a lightweight filter prompt for source/project/status/session id.
- `Esc`: close filter/help overlays.
- `?`: show help overlay.

## CLI Compatibility

Existing subcommands keep their current behavior. Bare `notchagent` changes from printing usage to launching the dashboard.

Automation-safe output stays under explicit subcommands:

- `notchagent status`
- `notchagent list`
- `notchagent approve`
- `notchagent deny`
- `notchagent toggle`
- `notchagent collapse`
- `notchagent completion`
- `notchagent help`

## App Socket Protocol

The first implementation should reuse the existing Unix socket path and command envelope. It adds richer commands instead of introducing a second server:

- `snapshot`: returns all data needed to draw the dashboard.
- `activate <sessionId>`: asks the app to focus the terminal/session represented by the selected row.
- `approve <sessionId>`: approves a pending permission for that session when present.
- `deny <sessionId>`: denies a pending permission for that session when present.

The existing global `approve` and `deny` commands remain valid.

The `snapshot` response contains:

- connection/app state: surface, active session id, pending permission count, pending question count.
- sessions: id, source, project display name, status, current tool, tool description, cost, cwd, model, permission mode, start time, last activity, total tool count.
- recent context: recent messages and recent tool history for each session, capped to keep socket responses small.
- pending state: whether each session has a pending permission or question.

Polling every second is acceptable for the first version. The renderer should also refresh immediately after actions. A future version can add push updates if polling becomes visibly stale.

## CLI Architecture

Add a small terminal UI layer to `Sources/NotchAgentCLI`:

- `CLIClient`: Unix socket request/response wrapper around the existing send logic.
- `DashboardModel`: decoded snapshot state plus selection/filter state.
- `TerminalController`: raw mode, alternate screen, cursor hide/show, signal cleanup, resize detection.
- `DashboardRenderer`: pure rendering from model and terminal size to text buffers.
- `InputLoop`: reads keypresses, updates model, invokes socket actions, triggers redraws.

Keep rendering code independent from socket code so table formatting can be tested without a running app.

## Error Handling

If the app is not running, bare `notchagent` shows a full-screen connection panel with the socket path and retry instructions. It keeps retrying until the user exits.

If an action fails, the dashboard shows a one-line status message at the bottom and keeps running.

If terminal setup fails, the CLI prints a plain text error and exits without changing terminal state.

Terminal mode must be restored on normal exit, `Ctrl-C`, socket errors, rendering errors, and resize events.

## Testing

Unit coverage should focus on pure code:

- snapshot decoding tolerates missing optional fields.
- renderer preserves table alignment and truncates long fields.
- filter logic matches source, project, status, and session id.
- key handling maps expected keys to actions.

Manual verification:

- `swift build -c release`
- existing subcommands still work.
- bare `notchagent` opens the dashboard and exits cleanly.
- dashboard shows a useful disconnected state when the app is closed.
- active sessions from Codex, Claude, and OpenCode appear when the app reports them.
- approve/deny actions still resolve permission prompts.

## Rollout

Implement in phases:

1. Add the richer `snapshot` app command and typed CLI decoding.
2. Add alternate-screen dashboard with polling, table, detail panel, and clean exit.
3. Add keyboard actions for approve, deny, refresh, selection, help, and filter.
4. Add session activation once the app command is wired to existing terminal activation behavior.
5. Preserve and verify all existing one-shot commands.

