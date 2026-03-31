# Tmux Session Manager - Sidebar Split Design (v2)

## Overview

Redesign the tmux integration from a small bottom panel to a first-class sidebar section. The sidebar splits vertically into two areas: workspaces (top) and tmux sessions (bottom), separated by a draggable divider. Tmux sessions render with the same visual style as workspaces. Clicking a session opens a Ghostty terminal attached to that session. Agent status badges (permission needed, task completed, error) propagate to tmux session rows.

## Requirements

- Split sidebar vertically: workspaces (top) / tmux sessions (bottom)
- Draggable divider to adjust split ratio, persisted across restarts
- Tmux sessions rendered with workspace-style icons (purple "T" gradient icon)
- Display attached/detached status indicator (green/gray dot)
- Click session → open Ghostty terminal with `tmux attach -t <session>`
- Session-level operations: create, rename, detach, kill (hover action buttons)
- Manual refresh button + auto-refresh when tmux section first becomes visible
- Agent status badges on tmux session rows (permission/completed/error)
- Handle tmux not installed gracefully
- Kill session requires confirmation

## Sidebar Layout

```
+---------------------------+
|  Q Filter workspaces      |
|                           |
|  [workspace rows...]      |
|  Open Folder...           |
+===== drag divider ========+
|  TMUX  [2]      [↻] [+]  |
|                           |
|  [T] caiwu    ● attached  |
|  [T] monitoring  detached |
|  [T] dev-tools   detached |
+---------------------------+
```

- Divider: 5px purple-tinted bar with centered handle pill, draggable
- Top section: existing workspace outline view + "Open Folder" button
- Bottom section: TMUX header + scrollable session list
- Default split ratio: 60% workspaces / 40% tmux
- Persist split ratio in AppSettings

## Session Row Rendering

Each tmux session row matches workspace row visual style:

- **Icon**: 18pt rounded rect, purple gradient (#8B5CF6 → #6D28D9), white "T" letter
- **Primary label**: session name (same font as workspace name)
- **Secondary label**: "attached" or "detached" (same font as branch name)
- **Status dot**: green (attached) / gray (detached), right-aligned
- **Selection**: purple highlight with border (matching workspace blue selection)
- **Agent status badge**: overlay on icon when agentStatus is actionable (same as workspace badges)

## Hover Actions

Visible on hover, same button style as existing `SidebarInlineIconButton`:

| Button | Icon | Action |
|--------|------|--------|
| Rename | `pencil` | Inline text field rename |
| Detach | `eject` | Detach all clients (only shown when attached) |
| Kill | `xmark` | Kill session with confirmation alert |

Header actions (always visible):
- `↻` Refresh session list
- `+` Create new session (prompts for name)

## Terminal Attach

When user clicks a tmux session:

1. If a terminal is already attached to this session, switch focus to it (don't create duplicate)
2. Otherwise, create a new pane in the current workspace using:
   - Engine: `TerminalEngineKind.libghosttyPreferred` (Ghostty)
   - Backend: `SessionBackendConfiguration.local(shellArguments: ["-lc", "tmux attach -t <session>"])`
3. Record the mapping: tmux session name → ShellSession ID
4. The terminal runs the same Ghostty engine as all workspace terminals

## Agent Status Badge on Tmux Sessions

For agent status badges to work inside tmux terminals:

### Detection Chain
```
Claude Code (inside tmux) → OSC 9 passthrough → Ghostty → ShellSession.agentStatus
```

Requires `set -g allow-passthrough on` in user's tmux config (documented in setup guide).

### Mapping: TmuxSession → ShellSession

- `TmuxPanelStore` maintains a dictionary: `[String: UUID]` mapping tmux session name to ShellSession ID
- When user clicks a session, store the ShellSession ID in this mapping
- When rendering tmux session rows, look up the ShellSession via this mapping and read its `agentStatus`
- When ShellSession terminates or is closed, remove the mapping entry

### Badge Rendering

Same `AgentStatusOverlayBadge` view used for workspace icons:
- Permission needed: hot magenta glow + pulse
- Task completed: green glow
- Error: red glow
- Clearing: keyboard activity (2s delay) + notification + worktree switch

## Refresh Behavior

- **Auto-refresh**: when tmux section becomes visible (first expand or app launch with non-collapsed state)
- **Manual refresh**: click ↻ button in TMUX header
- **After operations**: refresh after create/rename/detach/kill session
- **No polling**: no auto-refresh timer

## Data Model Changes

### AppSettings additions

```swift
var tmuxSidebarSplitRatio: Double  // 0.0-1.0, default 0.6 (60% workspaces)
```

Note: `tmuxPanelCollapsed` already exists from v1 implementation.

### TmuxPanelStore changes

Remove all window-related methods and state. Simplify to session-only:

```swift
@Published var sessions: [TmuxSession] = []
@Published var isAvailable: Bool = false
@Published var isLoading: Bool = false
@Published var errorMessage: String?
var sessionToShellSession: [String: UUID] = [:]  // tmux name → ShellSession ID
```

Methods:
- `checkAvailability()`
- `refresh()`
- `createSession(name:)`
- `killSession(name:)`
- `renameSession(oldName:newName:)`
- `detachSession(name:)`
- `attachConfiguration(session:) -> SessionBackendConfiguration`
- `registerShellSession(tmuxSession:shellSessionID:)`
- `unregisterShellSession(tmuxSession:)`
- `agentStatus(for tmuxSession:, in workspaceStore:) -> AgentSessionStatus`

## Files to Modify (from v1)

| File | Change |
|------|--------|
| `Liney/App/TmuxPanelStore.swift` | Remove window methods, add session→ShellSession mapping, add agentStatus lookup |
| `Liney/UI/Sidebar/TmuxPanelView.swift` | Rewrite as session-only list with workspace-style rows, remove window tree |
| `Liney/UI/Sidebar/WorkspaceSidebarView.swift` | Replace bottom panel embedding with split layout + draggable divider |
| `Liney/Domain/AppSettings.swift` | Add `tmuxSidebarSplitRatio` property |
| `Liney/App/WorkspaceStore.swift` | Wire attach click to register session→ShellSession mapping |

## Files to Keep (from v1, no changes)

| File | Reason |
|------|--------|
| `Liney/Services/Tmux/TmuxModels.swift` | TmuxSession, TmuxError still needed |
| `Liney/Services/Tmux/TmuxService.swift` | CLI wrapper still used (session operations) |
| `Tests/TmuxServiceTests.swift` | Parsing tests still valid |

## Files to Clean Up (from v1)

Remove window-related parsing tests from `TmuxServiceTests.swift` if window methods are removed from TmuxService.

## New Tests

| Test | Coverage |
|------|----------|
| Session→ShellSession mapping register/unregister | TmuxPanelStore |
| agentStatus lookup returns correct status | TmuxPanelStore |
| agentStatus returns .none when no mapping | TmuxPanelStore |
| Split ratio persistence | AppSettings |

## Out of Scope

- Tmux window-level management (use tmux native shortcuts)
- Tab mapping to tmux windows
- Window sub-nodes in sidebar
- Remote SSH tmux
- Auto-polling refresh
- Tmux pane management
