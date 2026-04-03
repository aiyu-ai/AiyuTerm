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
xcodebuild -project Liney.xcodeproj -scheme Liney -configuration Debug -destination 'platform=macOS' build

# Run all tests
xcodebuild -project Liney.xcodeproj -scheme Liney -destination 'platform=macOS' test

# Run a specific test class
xcodebuild -project Liney.xcodeproj -scheme Liney -destination 'platform=macOS' test -only-testing:LineyTests/<TestClassName>

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
- **Data storage:** JSON in `~/.aiyuterm/` (debug: `~/.aiyuterm-debug/`). Legacy reads from `~/Library/Application Support/Liney/`.

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
| `Liney/App/WorkspaceStore.swift` | Main orchestration: repo refresh, worktree switching, pane/tab management, action dispatch |
| `Liney/App/AiyuTermDesktopApplication.swift` | Window management, hot key window, app lifecycle |
| `Liney/Domain/WorkspaceRuntime.swift` | `WorkspaceModel`: runtime state for workspace including worktrees, tabs, layout |
| `Liney/Domain/PaneLayout.swift` | `SessionLayoutNode` recursive split tree |
| `Liney/Domain/AppSettings.swift` | All app-level settings (keyboard shortcuts, themes, terminal prefs) |
| `Liney/Services/Git/GitRepositoryService.swift` | Git status parsing, branch info, worktree inspection |
| `Liney/Services/Terminal/ShellSession.swift` | Single terminal session lifecycle |
| `Liney/Services/Terminal/Ghostty/AiyuTermGhosttyController.swift` | Ghostty surface bridge to AppKit |
| `Liney/UI/Sidebar/WorkspaceSidebarView.swift` | Sidebar tree, search, multi-selection, context menus, drag reordering |

## Versioning

Semantic versioning. The bump script (`scripts/bump_version.sh`) skips any version containing the digit 4 in any component. Build numbers follow the same rule.

## Related Documentation

- `AGENTS.md` -- AI collaboration guide with layout, hotspots, conventions (read before making changes)
- `DEVELOP.md` -- Developer setup, build/test commands, release process
- `docs/terminal-architecture.md` -- Terminal code layering and design rules (read before terminal changes)
- `docs/testing.md` -- Unit test philosophy and scope guidelines
- `docs/build_ghostty.md` -- How to rebuild vendored GhosttyKit.xcframework
