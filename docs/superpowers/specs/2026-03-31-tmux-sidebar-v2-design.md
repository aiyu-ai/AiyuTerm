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
- Session name validation: reject names containing shell metacharacters

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
- `+` Create new session (prompts for name, validates no shell metacharacters)

## Terminal Attach

When user clicks a tmux session:

1. Look up the session's stable ID (`sessionID`) in the app-level attach registry
2. If already attached (ShellSession exists and is alive), switch focus to it (don't create duplicate)
3. Otherwise, create a new pane in the current workspace using:
   - Engine: `TerminalEngineKind.libghosttyPreferred` (Ghostty)
   - Backend: argv-based invocation, NOT shell string interpolation (see Security section)
4. Register the mapping: tmux session ID → ShellSession ID in the app-level coordinator
5. The terminal runs the same Ghostty engine as all workspace terminals

### Security: Safe Command Construction

Session names are user-controlled input. To prevent shell injection:

1. **Validation on create/rename**: reject session names containing shell metacharacters (`;`, `|`, `&`, `$`, `` ` ``, `(`, `)`, `{`, `}`, `'`, `"`, `\`, newlines). Only allow alphanumeric, `-`, `_`, `.`.
2. **Attach command**: use argv-style invocation instead of `-lc` string interpolation:
   ```swift
   // WRONG: shell string interpolation
   .local(shellArguments: ["-lc", "tmux attach -t \(session)"])
   
   // CORRECT: direct tmux invocation via /usr/bin/env
   SessionBackendConfiguration(
       kind: .localShell,
       localShell: LocalShellSessionConfiguration(
           shellPath: "/usr/bin/env",
           shellArguments: ["tmux", "attach", "-t", sessionName]
       ),
       ssh: nil, agent: nil
   )
   ```
3. **TmuxService CLI calls**: already use argv-style via `ShellCommandRunner` (safe by construction)

## Session Identity: Stable tmux IDs

### Problem

Tmux session names are mutable (rename) and can change outside Liney. Using names as mapping keys causes:
- Broken mappings after rename
- Duplicate attaches
- Agent badges on wrong rows

### Solution

Use tmux's immutable session ID (`#{session_id}`, format: `$0`, `$1`, `$2`, ...) as the primary identity:

```swift
struct TmuxSession: Identifiable, Equatable {
    let sessionID: String      // immutable, e.g. "$0", "$1"
    let name: String           // display name, mutable
    let isAttached: Bool
    let windowCount: Int
    var id: String { sessionID }
}
```

Parsing format updated:
```
tmux list-sessions -F "#{session_id}\t#{session_name}\t#{session_attached}\t#{session_windows}"
```

All mappings and operations use `sessionID`:
- Attach registry: `[sessionID: ShellSessionID]`
- Rename: `tmux rename-session -t $0 new-name` (target by ID)
- Kill/detach: target by ID

## App-Level Attach Coordinator

### Problem

Each Liney window has its own `WorkspaceStore`. If tmux attach tracking is per-store, cross-window dedup fails.

### Solution

A singleton `TmuxAttachCoordinator` shared across all window contexts:

```swift
@MainActor
final class TmuxAttachCoordinator {
    static let shared = TmuxAttachCoordinator()
    
    // sessionID → (workspaceStoreID, shellSessionID)
    private var attachments: [String: (UUID, UUID)] = []
    
    func isAttached(_ sessionID: String) -> Bool
    func register(sessionID: String, storeID: UUID, shellSessionID: UUID)
    func unregister(sessionID: String)
    func shellSessionID(for sessionID: String) -> UUID?
}
```

- On attach click: check coordinator first, if already attached anywhere, switch focus
- On terminal close: unregister from coordinator
- On app quit: coordinator is cleared (tmux sessions persist independently)

## Agent Status Badge on Tmux Sessions

### Detection Chain
```
Claude Code (inside tmux) → OSC 9 passthrough → Ghostty → ShellSession.agentStatus
```

Requires `set -g allow-passthrough on` in user's tmux config.

### Mapping via TmuxAttachCoordinator

- Coordinator holds `sessionID → shellSessionID` mapping
- Tmux session row reads agentStatus via: `coordinator.shellSessionID(for:)` → find ShellSession → read `.agentStatus`
- When ShellSession's agentStatus changes, `onAgentStatusChange` fires → `objectWillChange.send()` propagates to sidebar

### Badge Rendering

Same `AgentStatusOverlayBadge` view used for workspace icons:
- Permission needed: hot magenta glow + pulse
- Task completed: green glow
- Error: red glow
- Clearing: keyboard activity (2s delay) + notification

## Refresh Behavior

- **Auto-refresh**: when tmux section becomes visible (first expand or app launch with non-collapsed state)
- **Manual refresh**: click ↻ button in TMUX header
- **After operations**: refresh after create/rename/detach/kill session
- **No polling**: no auto-refresh timer

## Data Model Changes

### TmuxSession (updated)

```swift
struct TmuxSession: Identifiable, Equatable {
    let sessionID: String      // immutable tmux ID ($0, $1, ...)
    let name: String           // display name
    let isAttached: Bool
    let windowCount: Int
    var id: String { sessionID }
}
```

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
```

Methods:
- `checkAvailability()`
- `refresh()`
- `createSession(name:)` -- validates name
- `killSession(sessionID:)`
- `renameSession(sessionID:newName:)` -- validates new name
- `detachSession(sessionID:)`
- `attachConfiguration(sessionName:) -> SessionBackendConfiguration` -- argv-based, safe

### Session Name Validation

```swift
static func isValidSessionName(_ name: String) -> Bool {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
    return !name.isEmpty && name.unicodeScalars.allSatisfy { allowed.contains($0) }
}
```

## Files to Create

| File | Purpose |
|------|---------|
| `Liney/App/TmuxAttachCoordinator.swift` | App-level singleton for cross-window attach tracking |

## Files to Modify (from v1)

| File | Change |
|------|--------|
| `Liney/Services/Tmux/TmuxModels.swift` | Add `sessionID` to TmuxSession, update TmuxError |
| `Liney/Services/Tmux/TmuxService.swift` | Update parsing format to include session_id, add name validation, remove window methods, argv-based attach |
| `Liney/App/TmuxPanelStore.swift` | Remove window methods, use sessionID for operations, delegate attach tracking to coordinator |
| `Liney/UI/Sidebar/TmuxPanelView.swift` | Rewrite as session-only list with workspace-style rows, agent status badge |
| `Liney/UI/Sidebar/WorkspaceSidebarView.swift` | Replace bottom panel embedding with split layout + draggable divider |
| `Liney/Domain/AppSettings.swift` | Add `tmuxSidebarSplitRatio` property |
| `Liney/App/WorkspaceStore.swift` | Wire attach click through coordinator |
| `Tests/TmuxServiceTests.swift` | Update parsing tests for sessionID, add name validation tests, remove window tests |

## Files to Keep (from v1, no changes)

| File | Reason |
|------|--------|
| (none -- all v1 files need updates for sessionID) | |

## New Tests

| Test | Coverage |
|------|----------|
| Parse sessions with sessionID field | TmuxService |
| Session name validation accepts valid names | TmuxService |
| Session name validation rejects shell metacharacters | TmuxService |
| Attach configuration uses argv not shell string | TmuxService |
| Coordinator register/unregister/lookup | TmuxAttachCoordinator |
| Coordinator isAttached returns correct state | TmuxAttachCoordinator |
| agentStatus lookup via coordinator | TmuxPanelStore |
| Split ratio persistence | AppSettings |

## Out of Scope

- Tmux window-level management (use tmux native shortcuts)
- Tab mapping to tmux windows
- Window sub-nodes in sidebar
- Remote SSH tmux
- Auto-polling refresh
- Tmux pane management
