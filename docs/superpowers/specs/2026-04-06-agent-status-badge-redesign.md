# Agent Status Badge Redesign

**Date:** 2026-04-06
**Status:** Draft (post cross-check round 2)
**Scope:** Sidebar agent status indicators with lifecycle animations

## Summary

Redesign the sidebar agent status badges to provide richer visual feedback across the full agent lifecycle: working (spinner), task completed (large green pulse -> small green dot after entering workspace), permission needed (large red pulse -> removed after resolved), and error (large orange-red pulse).

## Requirements

1. **Agent Working**: Blue spinner (rotating ring) on the workspace/worktree icon while agent is executing
2. **Task Completed (unread)**: Large green pulsing badge with checkmark icon to attract attention
3. **Task Completed (read)**: Small static green dot after user clicks into the workspace; no animation
4. **Permission Needed**: Large red pulsing badge with exclamation icon; faster pulse rate to signal urgency
5. **Permission Resolved**: Badge removed entirely (transitions back to spinner if agent continues, or to none)
6. **Error**: Large orange-red pulsing badge with X icon

### Lifecycle Transitions

```
none -> working (agent starts via hook "working" status)
working -> taskCompleted/unread (hook writes "completed")
working -> permissionNeeded (hook writes "permission")
working -> error (hook writes "error")

taskCompleted/unread -> taskCompleted/read (user clicks workspace in sidebar)
taskCompleted/read -> working (agent starts new task via hook)
taskCompleted/read -> none (agent starts new task, clears old status)

permissionNeeded -> working (hook writes "working" after permission granted)
permissionNeeded -> none (permission resolved, agent not continuing)

error -> none (user clicks into workspace, status cleared)
error -> working (agent retries via hook)
```

## Approach

**Approach A (selected):** Extend existing `AgentSessionStatus` enum inline, modify existing badge views in `WorkspaceSidebarView.swift`.

## Design

### 1. Status Model Extension

**File:** `WorkspaceModels.swift`

Extend the existing enum:

```swift
enum AgentSessionStatus: Equatable {
    case none
    case working           // NEW
    case permissionNeeded
    case taskCompleted
    case error
}
```

Priority for `highestPriority(in:)` aggregation:

| Status | Priority | Rationale |
|--------|----------|-----------|
| `permissionNeeded` | 4 (highest) | Requires user action, most urgent |
| `error` | 3 | Requires attention |
| `taskCompleted` | 2 | Informational, needs acknowledgment |
| `working` | 1 | Background activity, least urgent |
| `none` | 0 | No status |

**Property changes (CRITICAL):**

Do NOT rename `isActionable` to `isVisible`. Keep `isActionable` with its current semantics (returns `false` for `.none`). Add two new properties:

```swift
/// Whether the badge should be displayed in the sidebar.
var isVisible: Bool {
    self != .none
}

/// Whether user interaction (keyboard/notification) should auto-dismiss this status.
/// Working status must NOT be auto-dismissed by keyboard activity.
var isUserDismissible: Bool {
    switch self {
    case .permissionNeeded, .taskCompleted, .error: return true
    case .none, .working: return false
    }
}
```

**ShellSession.swift** must use `isUserDismissible` instead of `isActionable` for:
- Desktop notification clear handler (line 183)
- Keyboard activity auto-clear handler (lines 188, 192)

This prevents the 2-second keyboard timer from clearing `.working` spinner status.

### 2. Read/Unread Tracking

**File:** `WorkspaceRuntime.swift`

Add a `Set<String>` to `WorkspaceModel` tracking which worktree paths have unread completions:

```swift
/// Worktree paths with unread task completions.
/// Intentionally transient (not persisted). Agent status is ephemeral:
/// status files are deleted after reading, ShellSession.agentStatus resets on restart.
/// Completions lost on app restart are an accepted trade-off.
/// Must be @Published since WorkspaceModel is a class (ObservableObject),
/// so SwiftUI sidebar views react to changes.
@Published private(set) var unreadCompletedWorktrees: Set<String> = []
```

Methods:

- `markCompletionUnread(forWorktreePath:)` -- called by poller when status transitions to `.taskCompleted`
- `markCompletionRead(forWorktreePath:)` -- called by `selectWorkspace` / `switchToWorktree`

### 3. Badge Display State

**File:** `WorkspaceModels.swift` (new enum, next to `AgentSessionStatus`)

```swift
enum AgentBadgeDisplayState: Equatable {
    case hidden
    case spinner
    case completedUnread
    case completedRead
    case error
    case permissionNeeded
}
```

Factory method on `AgentSessionStatus`:

```swift
func badgeDisplayState(isUnread: Bool) -> AgentBadgeDisplayState {
    switch self {
    case .none: return .hidden
    case .working: return .spinner
    case .taskCompleted: return isUnread ? .completedUnread : .completedRead
    case .permissionNeeded: return .permissionNeeded
    case .error: return .error
    }
}
```

### 4. Hook Integration

**File:** `AgentStatusFilePoller.swift`

Add `"working"` to the status parser:

```swift
case "working": return .working
case "permission": return .permissionNeeded
case "completed": return .taskCompleted
case "error": return .error
```

When status transitions to `.taskCompleted`, call `workspace.markCompletionUnread(forWorktreePath:)`.

When status transitions to `.working`, call `workspace.markCompletionRead(forWorktreePath:)` (clears any stale unread flag from previous completion).

**File:** `AgentSessionStatusDetector.swift` (fallback detector)

No change needed for working detection -- the hook is the primary mechanism. The keyword detector only handles notification-based detection.

**File:** `TmuxAgentStatusPoller.swift`

Add `"working"` to the pane option status parsing to match.

### 5. UI Changes to AgentStatusOverlayBadge

**File:** `WorkspaceSidebarView.swift`

Replace the current `AgentStatusOverlayBadge` to handle all `AgentBadgeDisplayState` cases.

**Animation state management:** Use imperative `withAnimation` inside `onAppear`, never declarative `.animation(value:)` -- the latter can stall in `NSOutlineView` cell recycling. On state transition (`onChange(of: displayState)`), reset all animation state vars to non-animated first (bare assignment), then start new animation in fresh `withAnimation` block.

```swift
@State private var rotation: Double = 0     // spinner
@State private var isPulsing = false          // pulse badges
```

**Performance:** Apply `.drawingGroup()` on badge view body to flatten into Metal texture. Use blurred `Circle` behind badge for glow effect instead of `.shadow(radius:)` to avoid CPU shadow rasterization.

#### 5a. Spinner (working)

- 14px diameter (icon size * 0.48)
- `Circle().trim(from: 0, to: 0.65)` with `.rotationEffect(Angle(degrees: rotation))`
- Drive via: `onAppear { rotation = 0; withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) { rotation = 360 } }`
- Color: `Color(red: 0.31, green: 0.63, blue: 1.0)` (accent blue)
- Stroke width: 2px
- Background: `Circle().stroke(color.opacity(0.25))` for the unfilled portion

#### 5b. Completed Unread (large green pulse)

- 18px diameter (icon size * 0.6)
- Gradient: green `(0.19, 0.82, 0.35)` to `(0.15, 0.66, 0.27)`
- Checkmark SF Symbol: `checkmark`, white, bold
- Pulse: scale 1.0 -> 1.25, blurred backing circle opacity 0.3 -> 0.7, duration 1.5s, easeInOut, repeatForever
- Glow: blurred `Circle` behind badge, not `.shadow`

#### 5c. Completed Read (small green dot)

**IMPORTANT:** Do NOT use `.frame` change for the shrink transition. SwiftUI destroys and rebuilds the view when structural identity changes (icon present/absent).

Instead, keep badge always at 18px base, use `scaleEffect(0.444)` for the small dot (18 * 0.444 = 8px visual size). Fade icon opacity to 0 simultaneously. Animate with `.spring(response: 0.4, dampingFraction: 0.7)` on `scaleEffect` and `opacity`.

- Visual size: 8px (via scaleEffect)
- Solid green: `Color(red: 0.19, green: 0.82, blue: 0.35)`
- No icon (opacity 0), no animation after settling
- Subtle glow: blurred circle, 0.3 opacity

#### 5d. Permission Needed (large red pulse)

- 18px diameter
- Gradient: `(1.0, 0.18, 0.57)` to `(0.90, 0.0, 0.31)` (current colors preserved)
- Exclamation SF Symbol: `exclamationmark`, white, black weight
- Pulse: scale 1.0 -> 1.3, blurred backing 0.3 -> 0.8 opacity, duration 1.0s (faster than completed), easeInOut, repeatForever
- Glow: blurred `Circle`, red-pink

#### 5e. Error (large orange-red pulse)

- 18px diameter
- Gradient: `(1.0, 0.27, 0.23)` to `(0.84, 0.18, 0.13)` (current colors preserved)
- X SF Symbol: `xmark`, white, black weight
- Pulse: scale 1.0 -> 1.2, blurred backing 0.3 -> 0.6 opacity, duration 1.2s, easeInOut, repeatForever

### 6. Badge Parameter Change

**File:** `WorkspaceSidebarView.swift`

The badge view signature changes from:

```swift
AgentStatusOverlayBadge(status: AgentSessionStatus, size: CGFloat)
```

To:

```swift
AgentStatusOverlayBadge(displayState: AgentBadgeDisplayState, size: CGFloat)
```

Callers in `WorkspaceRowContent` and `WorktreeRowContent` compute the display state:

```swift
let displayState = agentStatus.badgeDisplayState(
    isUnread: workspace.unreadCompletedWorktrees.contains(worktreePath)
)
```

Visibility condition changes from `status.isActionable` to `displayState != .hidden`.

### 7. Clear on Select

**File:** `WorkspaceStore.swift`

#### selectWorkspace (line 746)

```swift
func selectWorkspace(_ workspace: WorkspaceModel) {
    selectedWorkspaceID = workspace.id
    workspace.bootstrapIfNeeded()
    // taskCompleted: mark as read (shrink badge, keep small dot)
    workspace.markCompletionRead(forWorktreePath: workspace.activeWorktreePath)
    // error: clear entirely (same as current behavior)
    workspace.clearErrorStatus(forWorktreePath: workspace.activeWorktreePath)
    // permissionNeeded: do NOT clear (user still needs to grant permission in terminal)
    // working: do NOT clear (agent is still running)
    ensureAgentFilePoller()
    persist()
}
```

#### openWorktree (line 2139) -- MUST ALSO UPDATE

```swift
private func openWorktree(_ workspace: WorkspaceModel, worktree: WorktreeModel, requestedAction: PendingWorktreeAction) {
    guard workspace.activeWorktreePath != worktree.path else {
        perform(requestedAction, in: workspace)
        selectWorkspace(workspace)
        // Remove the redundant clearAgentStatus call -- selectWorkspace already handles it
        return
    }
    activateWorktree(workspace: workspace, worktree: worktree, restartRunning: false, requestedAction: requestedAction)
}
```

#### switchToWorktree (WorkspaceRuntime.swift:412)

Same pattern: `markCompletionRead` + `clearErrorStatus` instead of `clearAgentStatus`.

The full `clearAgentStatus` method remains but is only called when agent starts new task (working status received) to reset stale completed/error states.

### 8. ShellSession Auto-Clear Fix

**File:** `ShellSession.swift`

Replace `isActionable` with `isUserDismissible` in the two auto-clear guards:

```swift
// Line 183: notification handler
} else if self.agentStatus.isUserDismissible && title.localizedCaseInsensitiveContains("claude") {
    self.agentStatus = .none
}

// Line 188: keyboard activity handler
guard let self, self.agentStatus.isUserDismissible else { return }
// ...
guard let self, self.agentStatus.isUserDismissible else { return }
```

This prevents keyboard activity from clearing `.working` spinner after 2 seconds.

### 9. Claude Code Hook Script Change

The existing hook scripts that write to `/tmp/aiyuterm-agent-status/` need to also write `"working"` status. This requires adding a hook trigger for agent session start.

Example hook addition (user configures in Claude Code `settings.json`):

```json
{
  "hooks": {
    "SessionStart": [{
      "command": "echo 'working:'$(date +%s) > /tmp/aiyuterm-agent-status/$(echo -n $PWD | md5 | head -c 16)"
    }]
  }
}
```

## Files Changed

| File | Change |
|------|--------|
| `AiyuTerm/Domain/WorkspaceModels.swift` | Add `.working` case, `AgentBadgeDisplayState` enum, priority update, `isVisible` + `isUserDismissible` properties |
| `AiyuTerm/Domain/WorkspaceRuntime.swift` | Add `unreadCompletedWorktrees` set, `markCompletionUnread/Read` methods, update `switchToWorktree` |
| `AiyuTerm/Services/Terminal/AgentStatusFilePoller.swift` | Parse `"working"` status, trigger unread marking |
| `AiyuTerm/Services/Terminal/AgentSessionStatusDetector.swift` | No change (hook-only for working) |
| `AiyuTerm/Services/Terminal/ShellSession.swift` | Replace `isActionable` with `isUserDismissible` in auto-clear guards |
| `AiyuTerm/Services/Tmux/TmuxAgentStatusPoller.swift` | Parse `"working"` in pane option |
| `AiyuTerm/UI/Sidebar/WorkspaceSidebarView.swift` | Rewrite `AgentStatusOverlayBadge` for all display states, `.drawingGroup()` |
| `AiyuTerm/App/WorkspaceStore.swift` | Change `selectWorkspace` + `openWorktree` clear logic |
| `AiyuTerm/Services/Terminal/WorkspaceSessionController.swift` | Add `clearErrorStatus` method |
| `AiyuTerm/UI/Sidebar/TmuxPanelView.swift` | Update `TmuxSessionRow` badge call to use `displayState:` signature |

### clearErrorStatus Implementation

**File:** `WorkspaceSessionController.swift`

Must filter on `.error` only to avoid clearing `.working` or `.permissionNeeded`:

```swift
func clearErrorStatus(using path: String) {
    for session in sessions.values where session.isUsing(pathPrefix: path) && session.agentStatus == .error {
        session.agentStatus = .none
    }
}
```

**File:** `WorkspaceRuntime.swift`

```swift
func clearErrorStatus(forWorktreePath path: String) {
    worktreeControllers[path]?.values.forEach { controller in
        controller.clearErrorStatus(using: path)
    }
}
```

### TmuxPanelView Badge Update

**File:** `TmuxPanelView.swift` (line ~203)

`TmuxSessionRow` currently calls `AgentStatusOverlayBadge(status:size:)`. Must update to use `displayState:` signature. Since tmux sessions don't have access to `unreadCompletedWorktrees`, always treat tmux completions as unread:

```swift
let displayState = agentStatus.badgeDisplayState(isUnread: true)
if displayState != .hidden {
    AgentStatusOverlayBadge(displayState: displayState, size: 16)
}
```

### agentGlowColor Switch Update

**File:** `WorkspaceSidebarView.swift` (line ~1893)

The `agentGlowColor` computed property on `SidebarItemIconView` switches on `AgentSessionStatus`. Add `.working` case:

```swift
case .working: return Color(red: 0.31, green: 0.63, blue: 1.0) // accent blue
```

### Implementation Order

To avoid intermediate build breaks, implement in this order:

1. **WorkspaceModels.swift** -- enum + all properties + AgentBadgeDisplayState (all switches compile)
2. **WorkspaceSidebarView.swift** -- add `.working` to agentGlowColor switch, then rewrite badge
3. **WorkspaceSessionController.swift** -- add `clearErrorStatus`
4. **WorkspaceRuntime.swift** -- add unreadCompletedWorktrees, markCompletion methods, update switchToWorktree
5. **AgentStatusFilePoller.swift** + **TmuxAgentStatusPoller.swift** -- parse "working"
6. **ShellSession.swift** -- isUserDismissible swap
7. **WorkspaceStore.swift** -- selectWorkspace + openWorktree changes
8. **TmuxPanelView.swift** -- badge signature update
9. **Tests** -- new unit tests

## Known Limitations

1. **Rapid status transitions within a single poll interval (3s) use last-writer-wins.** If "completed" is written and then "working" overwrites it within 3s, the completion is never displayed. This is an accepted trade-off of the file-based polling mechanism. For most real-world agent workflows, status transitions are seconds to minutes apart.

2. **`unreadCompletedWorktrees` is intentionally transient.** Completions are lost on app restart. This is consistent with `ShellSession.agentStatus` which is also in-memory only.

3. **`.working` status has no persistence.** The hook writes a one-shot file that is consumed by the poller. The `.working` value persists only in `ShellSession.agentStatus` (in-memory). If the app restarts while an agent is running, the spinner disappears until the agent writes its next status.

## Testing

| Test | Coverage |
|------|----------|
| `AgentSessionStatus.highestPriority` with `.working` | Unit: verify working(1) < taskCompleted(2) < error(3) < permissionNeeded(4) |
| `AgentSessionStatus.isUserDismissible` | Unit: `.working` returns false, `.taskCompleted`/`.permissionNeeded`/`.error` return true |
| `badgeDisplayState(isUnread:)` | Unit: all combinations of status + isUnread flag |
| `markCompletionUnread/Read` | Unit: set operations on `unreadCompletedWorktrees` |
| `AgentStatusFilePoller.parseStatusValue("working")` | Unit: parser returns `.working` |
| Badge animation states | Manual: verify spinner, pulse, shrink transitions in sidebar |
| Lifecycle flow | Integration: working -> completed(unread) -> click -> completed(read) -> working -> spinner |
| Keyboard activity during working | Manual: verify typing does NOT dismiss spinner |

## Out of Scope

- macOS system notifications for status changes (existing behavior unchanged)
- Badge on Dock icon
- Sound effects on status change
- Customizable animation speed/colors in settings
