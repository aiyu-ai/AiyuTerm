# Tmux Sidebar Panel

## Overview

Add a collapsible panel to the bottom of the sidebar that manages all local tmux sessions. Users can view, create, delete, rename, detach, and kill sessions and windows. Clicking a window opens a new terminal pane attached to that tmux session and window.

## Requirements

- Display all local tmux sessions and their windows in a collapsible sidebar bottom panel
- Support full session lifecycle: create, rename, kill, detach
- Support full window lifecycle: create, rename, kill, move to another session
- Click a window to open a new terminal pane attached to that session/window
- Manual refresh via button (no auto-polling)
- Hover to reveal inline action buttons
- Inline rename via double-click or edit button
- Handle tmux-not-installed gracefully
- Persist panel collapsed/expanded state

## Data Model

```swift
struct TmuxSession: Identifiable, Equatable {
    let name: String
    let isAttached: Bool
    let windowCount: Int
    var id: String { name }
}

struct TmuxWindow: Identifiable, Equatable {
    let sessionName: String
    let index: Int
    let name: String
    let isActive: Bool
    var id: String { "\(sessionName):\(index)" }
}
```

## TmuxService

Stateless utility enum wrapping tmux CLI calls. Uses `Process` to shell out, parses output via tmux `-F` format strings.

### Query Methods

```swift
static func isTmuxAvailable() async -> Bool
// Runs: which tmux

static func listSessions() async throws -> [TmuxSession]
// Runs: tmux list-sessions -F "#{session_name}\t#{session_attached}\t#{session_windows}"

static func listWindows(session: String) async throws -> [TmuxWindow]
// Runs: tmux list-windows -t <session> -F "#{window_index}\t#{window_name}\t#{window_active}"
```

### Session Operations

```swift
static func createSession(name: String) async throws
// Runs: tmux new-session -d -s <name>

static func killSession(name: String) async throws
// Runs: tmux kill-session -t <name>

static func renameSession(oldName: String, newName: String) async throws
// Runs: tmux rename-session -t <oldName> <newName>

static func detachSession(name: String) async throws
// Runs: tmux detach-client -t <name>
```

### Window Operations

```swift
static func createWindow(session: String, name: String?) async throws
// Runs: tmux new-window -t <session> [-n <name>]

static func killWindow(session: String, index: Int) async throws
// Runs: tmux kill-window -t <session>:<index>

static func renameWindow(session: String, index: Int, newName: String) async throws
// Runs: tmux rename-window -t <session>:<index> <newName>

static func moveWindow(session: String, index: Int, targetSession: String) async throws
// Runs: tmux move-window -s <session>:<index> -t <targetSession>
```

### Error Handling

All methods throw a `TmuxError` enum:

```swift
enum TmuxError: LocalizedError {
    case notInstalled
    case commandFailed(String)
    case parseError(String)
}
```

## TmuxPanelStore

`@MainActor ObservableObject` that manages panel state and orchestrates operations.

### State

```swift
@Published var sessions: [TmuxSession] = []
@Published var windowsBySession: [String: [TmuxWindow]] = [:]
@Published var expandedSessions: Set<String> = []
@Published var isAvailable: Bool = false
@Published var isLoading: Bool = false
@Published var errorMessage: String?
```

### Actions

```swift
func refresh()                    // Reload all sessions and windows of expanded sessions
func toggleSession(_ name: String) // Expand/collapse session (loads windows on first expand)

// Session operations
func createSession(name: String)
func killSession(name: String)
func renameSession(oldName: String, newName: String)
func detachSession(name: String)

// Window operations
func createWindow(session: String, name: String?)
func killWindow(session: String, index: Int)
func renameWindow(session: String, index: Int, newName: String)
func moveWindow(session: String, index: Int, targetSession: String)
```

All mutation operations call `refresh()` after completion to update the list.

### Attach Command

When user clicks a window, the store provides a `SessionBackendConfiguration`:

```swift
func attachConfiguration(session: String, windowIndex: Int) -> SessionBackendConfiguration {
    var config = LocalShellSessionConfiguration()
    config.shellArguments = ["-lc", "tmux attach -t \(session) \\; select-window -t \(windowIndex)"]
    return SessionBackendConfiguration(kind: .localShell, localShell: config, ssh: nil, agent: nil)
}
```

This is passed to `WorkspaceStore.createSession(in:configuration:)` to open a new pane.

## UI: TmuxPanelView

SwiftUI view embedded at the bottom of `WorkspaceSidebarView`, below the workspace list.

### Layout Structure

```
TmuxPanelView
  ├── Header (collapsible toggle + "TMUX" label + session count badge + refresh/new-session buttons)
  └── Content (when expanded)
       └── ForEach sessions
            ├── TmuxSessionRow (expand toggle + attached indicator + name + hover actions)
            └── ForEach windows (when session expanded)
                 └── TmuxWindowRow (active indicator + "index: name" + hover actions)
```

### Panel States

1. **Collapsed**: Header only, shows "TMUX" + session count badge
2. **Expanded**: Full session/window tree
3. **No tmux**: Shows "tmux not installed" with `brew install tmux` hint
4. **Loading**: Subtle spinner on refresh button
5. **Error**: Inline error message below header

### Hover Actions

**Session row** (visible on hover):
- `+` New window in this session
- `✎` Rename session (inline edit)
- `⏏` Detach all clients from session
- `✕` Kill session (with confirmation)

**Window row** (visible on hover):
- `↗` Open in new pane (same as click)
- `✎` Rename window (inline edit)
- `↔` Move window (shows session picker popover)
- `✕` Kill window

### Inline Rename

Double-click on session/window name or click `✎` button:
- Name text replaced with a text field
- Enter to confirm, Escape to cancel
- Calls `TmuxService.renameSession/renameWindow` then refreshes

### Destructive Action Confirmation

Kill session shows a confirmation popover: "Kill session 'name'? This will terminate all windows and processes."

Kill window does NOT require confirmation (single window, low risk).

### Visual Style

- Session attached indicator: green dot (attached) / gray dot (detached)
- Window active indicator: `*` suffix on active window
- Purple accent color for tmux elements (consistent with the "T" branding)
- Follows existing sidebar styling: `LineyTheme` colors, same font sizes and spacing

## Integration Points

### WorkspaceSidebarView

Add `TmuxPanelView` at the bottom of the sidebar, between workspace list and "Open Folder..." button:

```swift
VStack(spacing: 0) {
    // Existing workspace list
    workspaceListView
    
    // Tmux panel
    TmuxPanelView(store: tmuxPanelStore, workspaceStore: store)
    
    // Existing open folder button
    openFolderButton
}
```

### WorkspaceStore

- Hold a `TmuxPanelStore` instance
- Provide method to create a session pane from tmux attach configuration:

```swift
func createTmuxPane(in workspace: WorkspaceModel, configuration: SessionBackendConfiguration)
```

### AppSettings

Add panel collapsed state persistence:

```swift
var tmuxPanelCollapsed: Bool = true
```

## Files to Create

| File | Purpose |
|------|---------|
| `Liney/Services/Tmux/TmuxService.swift` | CLI wrapper and output parser |
| `Liney/Services/Tmux/TmuxModels.swift` | TmuxSession, TmuxWindow, TmuxError |
| `Liney/App/TmuxPanelStore.swift` | Panel state management |
| `Liney/UI/Sidebar/TmuxPanelView.swift` | Sidebar bottom panel view |
| `Tests/TmuxServiceTests.swift` | Output parsing tests |
| `Tests/TmuxPanelStoreTests.swift` | Store logic tests |

## Files to Modify

| File | Change |
|------|--------|
| `Liney/UI/Sidebar/WorkspaceSidebarView.swift` | Embed TmuxPanelView at sidebar bottom |
| `Liney/App/WorkspaceStore.swift` | Hold TmuxPanelStore, add createTmuxPane method |
| `Liney/Domain/AppSettings.swift` | Add tmuxPanelCollapsed setting |

## Tests

| Test File | Coverage |
|-----------|----------|
| `Tests/TmuxServiceTests.swift` | Parse list-sessions output, parse list-windows output, handle empty output, handle malformed output, handle tmux not installed |
| `Tests/TmuxPanelStoreTests.swift` | Refresh updates state, toggle session loads windows, attach configuration format, error handling |

## Out of Scope

- Remote SSH tmux management
- Tmux pane-level management (only sessions and windows)
- Auto-refresh / polling
- Modifying existing tmux detection/restore logic in ShellSession
- Tmux configuration file editing
