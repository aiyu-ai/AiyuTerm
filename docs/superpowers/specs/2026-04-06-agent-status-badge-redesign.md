# Agent Status Badge Redesign

**Date:** 2026-04-06
**Status:** Draft
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

New computed property on `AgentSessionStatus`:

```swift
var isVisible: Bool {
    self != .none
}
```

Rename existing `isActionable` to `isVisible` since `working` is visible but not "actionable" in the original sense.

### 2. Read/Unread Tracking

**File:** `WorkspaceRuntime.swift`

Add a `Set<String>` to `WorkspaceModel` tracking which worktree paths have unread completions:

```swift
/// Worktree paths with unread task completions.
/// Cleared when user selects the workspace (enters it).
private(set) var unreadCompletedWorktrees: Set<String> = []
```

Methods:

- `markCompletionUnread(forWorktreePath:)` — called by poller when status transitions to `.taskCompleted`
- `markCompletionRead(forWorktreePath:)` — called by `selectWorkspace` / `switchToWorktree`

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

No change needed for working detection — the hook is the primary mechanism. The keyword detector only handles notification-based detection.

**File:** `TmuxAgentStatusPoller.swift`

Add `"working"` to the pane option status parsing to match.

### 5. UI Changes to AgentStatusOverlayBadge

**File:** `WorkspaceSidebarView.swift`

Replace the current `AgentStatusOverlayBadge` to handle all `AgentBadgeDisplayState` cases:

#### 5a. Spinner (working)

- 14px diameter (icon size * 0.48)
- Blue spinner ring: `border-top` trick equivalent in SwiftUI = `RotationEffect` on a trimmed `Circle().trim(from: 0, to: 0.65)` with `.rotationEffect` animated linearly
- Color: `Color(red: 0.31, green: 0.63, blue: 1.0)` (matching current accent blue)
- Duration: 0.9s per rotation, linear, infinite

#### 5b. Completed Unread (large green pulse)

- 18px diameter (icon size * 0.6)
- Gradient: green `(0.19, 0.82, 0.35)` to `(0.15, 0.66, 0.27)`
- Checkmark SF Symbol: `checkmark`, white, bold
- Pulse: scale 1.0 -> 1.25, glow radius 6 -> 16px, duration 1.5s, easeInOut, repeatForever
- Shadow: green with 0.5 opacity

#### 5c. Completed Read (small green dot)

- 8px diameter (icon size * 0.28)
- Solid green: `Color(red: 0.19, green: 0.82, blue: 0.35)`
- No icon, no animation
- Subtle shadow: 4px radius, 0.3 opacity
- Transition from large: `.spring(response: 0.4, dampingFraction: 0.7)` on size change

#### 5d. Permission Needed (large red pulse)

- 18px diameter
- Gradient: `(1.0, 0.18, 0.57)` to `(0.90, 0.0, 0.31)` (current colors preserved)
- Exclamation SF Symbol: `exclamationmark`, white, black weight
- Pulse: scale 1.0 -> 1.3, glow 6 -> 20px, duration 1.0s (faster than completed), easeInOut, repeatForever
- Shadow: pink/red with 0.7 opacity at peak

#### 5e. Error (large orange-red pulse)

- 18px diameter
- Gradient: `(1.0, 0.27, 0.23)` to `(0.84, 0.18, 0.13)` (current colors preserved)
- X SF Symbol: `xmark`, white, black weight
- Pulse: scale 1.0 -> 1.2, glow 6 -> 14px, duration 1.2s, easeInOut, repeatForever

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

`selectWorkspace(_:)` at line 746 already calls `clearAgentStatus`. Change to handle each status differently:

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

Similarly for `switchToWorktree` in `WorkspaceRuntime.swift:415`.

The full `clearAgentStatus` method remains but is only called when agent starts new task (working status received) to reset stale completed/error states.

### 8. Claude Code Hook Script Change

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
| `AiyuTerm/Domain/WorkspaceModels.swift` | Add `.working` case, `AgentBadgeDisplayState` enum, priority update |
| `AiyuTerm/Domain/WorkspaceRuntime.swift` | Add `unreadCompletedWorktrees` set, `markCompletionUnread/Read` methods |
| `AiyuTerm/Services/Terminal/AgentStatusFilePoller.swift` | Parse `"working"` status, trigger unread marking |
| `AiyuTerm/Services/Terminal/AgentSessionStatusDetector.swift` | No change (hook-only for working) |
| `AiyuTerm/Services/Tmux/TmuxAgentStatusPoller.swift` | Parse `"working"` in pane option |
| `AiyuTerm/UI/Sidebar/WorkspaceSidebarView.swift` | Rewrite `AgentStatusOverlayBadge` for all display states |
| `AiyuTerm/App/WorkspaceStore.swift` | Change `selectWorkspace` to mark read instead of clear |
| `AiyuTerm/Services/Terminal/WorkspaceSessionController.swift` | Adjust `clearAgentStatus` usage |

## Testing

| Test | Coverage |
|------|----------|
| `AgentSessionStatus.highestPriority` with `.working` | Unit test: verify working < taskCompleted < error < permissionNeeded |
| `badgeDisplayState(isUnread:)` | Unit test: all combinations of status + isUnread flag |
| `markCompletionUnread/Read` | Unit test: set operations on `unreadCompletedWorktrees` |
| `AgentStatusFilePoller.parseStatusValue("working")` | Unit test: parser returns `.working` |
| Badge animation states | Manual: verify spinner, pulse, shrink transitions in sidebar |
| Lifecycle flow | Integration: working -> completed(unread) -> click -> completed(read) -> working -> spinner |

## Out of Scope

- macOS system notifications for status changes (existing behavior unchanged)
- Badge on Dock icon
- Sound effects on status change
- Customizable animation speed/colors in settings
