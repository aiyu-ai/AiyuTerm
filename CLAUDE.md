# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

AiyuTerm is a native macOS terminal workspace app (Swift, AppKit + SwiftUI) for developers working across multiple repositories and git worktrees. It provides a single window with a sidebar, persistent split-pane terminal layouts per worktree, and support for local shell, SSH, and agent-backed sessions. The terminal engine is a vendored Ghostty (libghostty) runtime.

- Min platform: macOS 14.6 (Universal: arm64 + x86_64)
- License: Apache 2.0
- Author: wuwenrui

## Commands

```bash
# Debug build
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -configuration Debug -destination 'platform=macOS' build

# Run all tests
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -destination 'platform=macOS' test

# Run a specific test class
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -destination 'platform=macOS' test -only-testing:AiyuTermTests/<TestClassName>

# Run debug build
open ~/Library/Developer/Xcode/DerivedData/AiyuTerm-*/Build/Products/Debug/AiyuTerm.app

# Release build (universal, signed)
scripts/build_macos_app.sh

# Full deploy (bump, build, sign, notarize, publish)
./deploy.sh
```

Release builds require: `xcodebuild -downloadComponent MetalToolchain`

## Architecture

AppKit + SwiftUI hybrid. AppKit handles the outer window shell, sidebar (`NSOutlineView` bridge), and terminal surface hosting. SwiftUI handles content views via `@EnvironmentObject`-based state injection from `WorkspaceStore`.

**Core data flow:**
```
main.swift -> AppDelegate -> AiyuTermDesktopApplication -> WorkspaceStore -> WorkspaceModel
                                                              |
                                                     WorkspaceSessionController -> ShellSession
                                                              |                        |
                                                     PaneLayout (tree)        TerminalSurfaceController
                                                                                       |
                                                                              AiyuTermGhosttyController
                                                                                       |
                                                                              AiyuTermGhosttyRuntime (shared)
```

**Key patterns:**
- **Single-window multi-workspace:** `AiyuTermDesktopApplication` manages one or more `WindowContext` objects, each with its own `WorkspaceStore`.
- **Recursive split tree:** `SessionLayoutNode` is an indirect enum (`pane | split`) modeling arbitrary binary split pane layouts. Pane operations are pure functions on this tree.
- **Action dispatch:** `WorkspaceStore.dispatch(_ action:)` handles command palette actions and UI events.
- **Per-worktree session persistence:** Each worktree maintains independent tab states with layout trees and pane snapshots, enabling layout restoration on worktree switch or app relaunch.
- **In-process localization:** No .lproj bundles. All strings in compile-time `L10n.swift` table, supporting English and Simplified Chinese.
- **Data storage:** JSON in `~/.aiyuterm/` (debug: `~/.aiyuterm-debug/`).

## Tech Stack

| Category | Technology |
|----------|-----------|
| Language | Swift (primary), C (Ghostty headers) |
| UI | AppKit + SwiftUI |
| Terminal | libghostty (vendored `GhosttyKit.xcframework`) |
| Auto-updates | Sparkle 2.7.3 |
| Crash reporting | Sentry 9.8.0 |
| Build | Xcode 16+ / xcodebuild |
| Dependencies | Swift Package Manager |
| Signing | Apple Developer ID + notarytool |
| Distribution | GitHub Releases, Homebrew cask (`aiyu-ai/tap/aiyuterm`), Sparkle appcast |

## Key Files

| File | Role |
|------|------|
| `AiyuTerm/App/WorkspaceStore.swift` | Main orchestration: repo refresh, worktree switching, pane/tab management, action dispatch |
| `AiyuTerm/App/AiyuTermDesktopApplication.swift` | Window management, hot key window, app lifecycle |
| `AiyuTerm/Domain/WorkspaceRuntime.swift` | `WorkspaceModel`: runtime state for workspace including worktrees, tabs, layout |
| `AiyuTerm/Domain/PaneLayout.swift` | `SessionLayoutNode` recursive split tree |
| `AiyuTerm/Domain/AppSettings.swift` | All app-level settings (keyboard shortcuts, themes, terminal prefs) |
| `AiyuTerm/Services/Git/GitRepositoryService.swift` | Git status parsing, branch info, worktree inspection |
| `AiyuTerm/Services/Terminal/ShellSession.swift` | Single terminal session lifecycle |
| `AiyuTerm/Services/Terminal/Ghostty/AiyuTermGhosttyController.swift` | Ghostty surface bridge to AppKit |
| `AiyuTerm/UI/Sidebar/WorkspaceSidebarView.swift` | Sidebar tree, search, multi-selection, context menus, drag reordering |

## Versioning

Semantic versioning. The bump script (`scripts/bump_version.sh`) skips any version containing the digit 4 in any component. Build numbers follow the same rule.

## Bug Fix Discipline

1. **Diagnose before code** — When a bug is reported, the FIRST action must be a diagnostic tool call (Grep, Read, Bash to reproduce/verify), NOT an Edit. No exceptions.
2. **Verify assumptions** — Never trust surface symptoms as root cause. "Screenshot says X is broken" -> run a command to verify X is actually broken vs something upstream causing X to appear broken.
3. **Fix at the right layer** — Trace the data path from source to display. Fix the layer where the problem originates (data/service), not the layer where it manifests (UI). If a fix hides the failure rather than explaining why it failed, the fix is wrong.

## macOS GUI App Considerations

- GUI apps launched from Finder do NOT inherit the user's full shell PATH. `/opt/homebrew/bin` and `/usr/local/bin` are typically missing.
- When locating external tools (tmux, git, etc.), check common absolute paths first, use `which`/`env` as fallback only.
- Release builds use `CODE_SIGNING_ALLOWED=NO` by default. Ad-hoc sign (`codesign --force --deep --sign -`) before distributing to avoid repeated TCC permission dialogs.

## Agent Status Badge System

Sidebar badges show the real-time status of Claude Code agent sessions. **Read this section before modifying any agent status code.**

### Status Lifecycle

```
AgentSessionStatus: .none -> .working -> .permissionNeeded / .taskCompleted / .error -> .none
```

### Badge Display States

| AgentSessionStatus | Unread (isUnread=true) | Read (isUnread=false) | Cleared by |
|--------------------|----------------------|----------------------|------------|
| `.working` | spinner (rotating) | spinner | title idle + 1s debounce, or poller delivers new status |
| `.permissionNeeded` | large pulsing pink badge | small pink dot (0.6x, no icon) | `.working` resumes (user approved) or `Stop` hook |
| `.taskCompleted` | large pulsing green badge | small green dot (0.6x, no icon) | `.working` resumes (new prompt) |
| `.error` | pulsing red badge | -- | keyboard activity dismisses to `.none` |

### Key Design Rules

1. **Only `UserPromptSubmit` writes "working"** -- `PostToolUse` was removed from the hook script because Claude Code's "dreaming" background process fires `PostToolUse` events that cause false working spinners after task completion.

2. **Permission prompt has idle title** -- When Claude Code shows "Do you want to proceed?", the terminal title prefix is `✳` (idle), NOT braille animation. Therefore `onTitleChange` must NEVER clear `.permissionNeeded` based on idle title detection. Only `.working` can be cleared this way.

3. **Keyboard activity behavior by status:**
   - `.permissionNeeded` / `.taskCompleted` -> mark as "read" (shrink badge), do NOT dismiss
   - `.error` -> dismiss to `.none`
   - `.working` / `.none` -> no action

4. **Unread/read tracking** -- Two separate `Set<String>` on `WorkspaceModel`:
   - `unreadCompletedWorktrees` -- set when poller reads "completed", cleared when `.working` resumes
   - `unreadPermissionWorktrees` -- set when poller reads "permission", cleared when `.working` resumes
   - Both cleared by `onStatusRead` callback on keyboard activity (shrinks badge)

5. **Stale working detection** -- Two mechanisms:
   - `onTitleChange`: when `.working` + title goes idle -> 1s debounce then clear (gives poller time to deliver `.taskCompleted`)
   - `agentStatus.didSet`: when `.working` is set -> 2s delayed check if title is still busy; clears if idle (handles poller setting `.working` after agent already stopped)

6. **Poller iterates ALL worktrees** -- `AgentStatusFilePoller.poll()` iterates `workspace.worktrees` (not just `activeWorktreePath`) and updates sessions via `setAgentStatus(_:forWorktreePath:)` which reaches all controllers in `worktreeControllers[path]`.

### Data Flow

```
Hook script (bash)                    Terminal title (Ghostty)
    |                                       |
    v                                       v
/tmp/aiyuterm-agent-status/{md5}     onTitleChange callback
    |                                       |
    v                                       v
AgentStatusFilePoller.poll()         ShellSession.agentStatus
    |                                       |
    v                                       v
WorkspaceModel.setAgentStatus()      AgentSessionStatusDetector
    |                                       |
    +--------->  ShellSession.agentStatus  <+
                         |
                         v
                onAgentStatusChange -> WorkspaceModel.objectWillChange
                         |
                         v
                Sidebar badge (SwiftUI)
```

### Key Files for Agent Status

| File | Role |
|------|------|
| `ClaudeCodeHooksService.swift` | Hook script content and settings.json injection |
| `AgentStatusFilePoller.swift` | Reads status files, updates sessions per worktree |
| `AgentSessionStatusDetector.swift` | Title prefix detection (braille=working) and notification keyword matching |
| `ShellSession.swift` | `agentStatus` property with didSet verification, `onTitleChange`/`onKeyboardActivity` handlers |
| `WorkspaceRuntime.swift` | `unreadCompletedWorktrees`/`unreadPermissionWorktrees` tracking, `setAgentStatus` |
| `WorkspaceModels.swift` | `AgentSessionStatus` enum, `AgentBadgeDisplayState` enum, `isUserDismissible`/`isReadableOnInteraction` |
| `WorkspaceSidebarView.swift` | `AgentStatusOverlayBadge` view, badge rendering and animation |

## Related Documentation

- `AGENTS.md` -- AI collaboration guide with layout, hotspots, conventions (read before making changes)
- `DEVELOP.md` -- Developer setup, build/test commands, release process
- `docs/terminal-architecture.md` -- Terminal code layering and design rules (read before terminal changes)
- `docs/testing.md` -- Unit test philosophy and scope guidelines
- `docs/build_ghostty.md` -- How to rebuild vendored GhosttyKit.xcframework
