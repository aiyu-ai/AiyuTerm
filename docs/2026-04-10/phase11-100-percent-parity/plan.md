# Phase 11 — 100% CodeIsland Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Achieve 100% feature + visual + test parity with upstream CodeIsland (https://github.com/wxtsky/CodeIsland) in the AiyuTerm `feat/codeisland-integration` branch, closing all gaps identified in the Phase 10 audit and eliminating every dead code island.

**Architecture:** The port is organized into 11 subphases. Phase 11.0 salvages work-in-progress from 4 rate-limited Wave 3 sub-agents. Phases 11.1–11.9 fill every remaining gap (settings, sounds, pixel kit, mascots, controller reactivity, tests, L10n). Phase 11.10 is final verification with evidence gates. Every task follows TDD (red → green → refactor → commit) and must produce passing tests + a successful `xcodebuild ... build` before the commit.

**Tech Stack:** Swift 6, AppKit + SwiftUI, XCTest, Xcode 16, `xcodebuild` CLI, git worktrees, conventional commits.

**Current baseline (HEAD `d229a74`):**
- Main app source: 8,104 LOC
- Upstream total: 15,889 LOC
- Weighted completion from Phase 10 audit: **~82%**
- Target: **100%** (both functional + visual + L10n + test parity)

**Upstream file inventory (every file that needs parity):**

| Upstream path | LOC | Category | Current status |
|---|---|---|---|
| `Sources/CodeIsland/AppState.swift` | 3103 | App state hub | Distributed across AgentSessionSnapshot/Mapper/Store ✅ |
| `Sources/CodeIsland/NotchPanelView.swift` | 2045 | UI root | Simplified port 714 LOC → needs sub-component integration |
| `Sources/CodeIsland/SettingsView.swift` | 1310 | Settings UI | Partial — only notch section in General tab |
| `Sources/CodeIsland/ConfigInstaller.swift` | 856 | CLI hooks | Over-delivered at 1307 LOC ✅ |
| `Sources/CodeIslandCore/SessionSnapshot.swift` | 721 | Reducer | Ported 763 LOC ✅ |
| `Sources/CodeIsland/TerminalActivator.swift` | 638 | Tab switch | Ported 752 LOC ✅ |
| `Sources/CodeIsland/PanelWindowController.swift` | 596 | NSPanel host | Simplified 279 LOC → needs reactive wiring |
| `Sources/CodeIsland/DebugHarness.swift` | 523 | Dev tool | Skip (internal-only, not user-facing) ⏭ |
| `Sources/CodeIsland/L10n.swift` | 411 | Strings | Only 2 keys ported → needs full parity |
| `Sources/CodeIsland/PixelCharacterView.swift` | 379 | Pixel art | 397 LOC committed to phase11/pixel-kit ✅ |
| `Sources/CodeIslandBridge/main.swift` | 338 | Hook binary | Ported 405 LOC ✅ |
| `Sources/CodeIsland/Settings.swift` | 332 | Settings store | 10/29 keys mapped → 19 keys still missing |
| `Sources/CodeIsland/DexView.swift` | 319 | Codex mascot | 12 mascot files WIP in phase11/cli-mascots (uncommitted) |
| `Sources/CodeIsland/CursorView.swift` | 306 | Cursor mascot | WIP (uncommitted) |
| `Sources/CodeIsland/CopilotView.swift` | 306 | Copilot mascot | WIP (uncommitted) |
| `Sources/CodeIsland/BuddyView.swift` | 305 | CodeBuddy mascot | WIP (uncommitted) |
| `Sources/CodeIsland/TerminalVisibilityDetector.swift` | 302 | Smart suppress | Ported 370 LOC ✅ |
| `Sources/CodeIsland/OpenCodeView.swift` | 294 | OpenCode mascot | WIP (uncommitted) |
| `Sources/CodeIsland/DroidView.swift` | 284 | Factory mascot | WIP (uncommitted) |
| `Sources/CodeIsland/UpdateChecker.swift` | 278 | Sparkle wrap | Skip (we use Sparkle directly) ⏭ |
| `Sources/CodeIsland/QoderView.swift` | 275 | Qoder mascot | WIP (uncommitted) |
| `Sources/CodeIsland/GeminiView.swift` | 272 | Gemini mascot | WIP (uncommitted) |
| `Sources/CodeIsland/HookServer.swift` | 210 | Unix socket | Ported 316 LOC ✅ |
| `Sources/CodeIsland/DiagnosticsExporter.swift` | 205 | Bug bundle | Ported 381 LOC ✅ |
| `Sources/CodeIsland/AppDelegate.swift` | 185 | App lifecycle | Partial — needs StatusItem wiring |
| `Sources/CodeIsland/ScreenDetector.swift` | 178 | Notch geometry | Ported 262 LOC ✅ |
| `Sources/CodeIslandCore/Models.swift` | 161 | Core models | Ported 225 LOC ✅ |
| `Sources/CodeIsland/SessionTitleStore.swift` | 149 | Title resolver | Ported 220 LOC ✅ |
| `Sources/CodeIsland/SoundManager.swift` | 96 | Audio | Partial 136 LOC → needs full 5-entry table |
| `Sources/CodeIsland/StatusItemController.swift` | 88 | Menu bar | 242 LOC committed to phase11/controller-reactive ✅ |
| `Sources/CodeIsland/NotchAnimation.swift` | 78 | Springs | Committed to phase11/pixel-kit ✅ |
| `Sources/CodeIsland/SessionPersistence.swift` | 77 | Disk state | Ported 152 LOC ✅ |
| `Sources/CodeIsland/SettingsWindowController.swift` | 66 | Settings window | Skip (AiyuTerm uses sheet) ⏭ |
| `Sources/CodeIsland/MascotView.swift` | 49 | Mascot wrapper | Committed to phase11/pixel-kit ✅ |
| `Sources/CodeIslandCore/ChatMessageTextFormatter.swift` | 34 | Markdown | Ported 65 LOC ✅ |
| `Sources/CodeIslandCore/EventNormalizer.swift` | 33 | Event names | Ported 52 LOC ✅ |
| `Sources/CodeIsland/IslandSurface.swift` | 23 | Helper | Integrate inline during 11.9 |
| `Sources/CodeIsland/Models.swift` | 22 | Helper | Already covered by our models ✅ |
| `Sources/CodeIsland/BundleExtension.swift` | 18 | Bundle helper | Port inline during 11.8 |
| `Sources/CodeIsland/CodeIslandApp.swift` | 13 | App entry | N/A (we're embedded) ⏭ |
| `Sources/CodeIslandCore/SocketPath.swift` | 11 | Path helper | Ported 79 LOC ✅ |

**Upstream test inventory:**

| Upstream test path | LOC | Current status |
|---|---|---|
| `Tests/CodeIslandTests/AppStateCodexTranscriptTests.swift` | 92 | Not ported |
| `Tests/CodeIslandTests/SessionPersistenceTests.swift` | 78 | Different tests, 6 ours ≠ upstream |
| `Tests/CodeIslandTests/ScreenDetectorTests.swift` | 71 | Partial — we have 15 ours |
| `Tests/CodeIslandCoreTests/SessionSnapshotTitleTests.swift` | 61 | Not ported |
| `Tests/CodeIslandTests/ConfigInstallerTests.swift` | 48 | Different tests, ours 30+14+16+21 |
| `Tests/CodeIslandTests/PanelWindowControllerTests.swift` | 33 | Partial — 7 ours |
| `Tests/CodeIslandTests/SessionTitleStoreTests.swift` | 32 | Different tests, 19 ours |
| `Tests/CodeIslandCoreTests/DerivedSessionStateTests.swift` | 25 | Not ported |
| `Tests/CodeIslandCoreTests/ChatMessageTextFormatterTests.swift` | 22 | Different tests, 4 ours |

**Acceptance criteria for "100%":**

1. Every upstream file either has an equivalent ported (status ✅) OR is explicitly tagged `⏭ Skip` with justification.
2. Every upstream settings key exists in `AppSettings` (29 total — 10 mapped today, 19 to add).
3. Every upstream L10n string has a zh-Hans + en + zh-Hant translation in `L10n.swift`.
4. Every upstream test is ported OR superseded by an AiyuTerm-specific test covering the same behavior.
5. `xcodebuild ... build` exits 0.
6. Full P9+P10+P11 test suite passes with 0 failures.
7. Four dead-code modules (`AgentSessionPersistence`, `AgentSessionTitleStore`, `AgentTerminalVisibilityDetector`, `AgentDiagnosticsExporter`) have non-zero external callers (already done in Phase 10.1, re-verify in 11.10).
8. Notch panel renders with: per-CLI mascot, inverse-radius shape, pixel kit components, reactive fullscreen/mouseLeave/emptyHide behavior, menu bar status item, all 5 sound events, and in-card approval/question bars.
9. Debug .app rebuilds successfully and launches without crashing.
10. Honest completion report with evidence artifacts (test counts, LOC delta, screenshot equivalent from `get_page_text` style inspection).

---

## Risk Register

| Risk | Mitigation |
|---|---|
| Rate-limited agents leave uncommitted work that gets lost | Phase 11.0.1/11.0.2 commit WIP immediately as first step |
| Merging 4 worktrees produces conflicts in `AgentHookEventMapper.swift`, `AppSettings.swift`, `WorkspaceStore.swift`, `AgentNotchPanelView.swift` | Serialize merges: smallest diff first, resolve on each step, build-verify between merges |
| Pixel-art sub-components reference upstream types (`AppState`, `SettingsKey`) we don't have | Every missing reference gets a `// TODO(integration)` stub that still compiles |
| `notchMascotSpeed` env key collision between `AgentMascotEnvironment.swift` (from 3a) and `AgentPixelKitEnvironment.swift` (from 3c) | Phase 11.1.5 unifies both into a single canonical env key |
| `AgentNotchPanelView.swift` is edited by two streams (mascot integration + pixel kit) | Only the mascot stream touches it during Wave 3; pixel kit stays in its own files; post-merge integration is Phase 11.9 |
| Build succeeds but tests fail after merging | Every merge step has `xcodebuild ... build` AND a targeted `xcodebuild ... test` as mandatory gates |
| Swift 6 strict concurrency traps in new `@Observable` types (we hit this in Phase 8) | Follow Phase 8 precedent: use `@unchecked Sendable` + NSLock or drop to `@Observable` without MainActor |
| 29-key AppSettings codable chain breaks legacy JSON decode | Every new key uses `decodeIfPresent ?? default`; a dedicated test decodes a fresh `{}` JSON and asserts every new key defaults |
| SwiftUI view smoke tests can crash at runtime due to missing environment values | Every smoke test wraps the view in a `UIHostingController`-like eager eval; absent env keys fall back to `.default` |

---

## File Structure

All new files land under these directories (created where missing):

```
AiyuTerm/
├── Domain/
│   └── AppSettings.swift                          # extended w/ 19 new keys (11.3)
├── Services/Agent/
│   ├── Sound/
│   │   └── AgentSoundManager.swift                # extended w/ full entry table (11.4)
│   ├── StatusItem/
│   │   └── AgentStatusItemController.swift        # already committed in 3d ✅
│   ├── HookProtocol/                              # no changes
│   ├── Mapping/                                   # no changes (Phase 10.1 wired)
│   └── Notifications/                             # already Phase 10.1 ✅
├── UI/NotchPanel/
│   ├── AgentNotchPanelView.swift                  # integrates mascots + pixel kit (11.9)
│   ├── AgentNotchPanelController.swift            # reactive wiring (11.6)
│   ├── AgentNotchScreenDetector.swift             # no changes
│   ├── Mascots/                                   # 12 files, salvaged from 3a
│   │   ├── AgentBuddyView.swift                   # (11.0.1)
│   │   ├── AgentClaudeMascotView.swift            # (11.0.1)
│   │   ├── AgentCopilotView.swift                 # (11.0.1)
│   │   ├── AgentCursorView.swift                  # (11.0.1)
│   │   ├── AgentDexView.swift                     # (11.0.1)
│   │   ├── AgentDroidView.swift                   # (11.0.1)
│   │   ├── AgentGeminiView.swift                  # (11.0.1)
│   │   ├── AgentGenericMascotView.swift           # (11.0.1)
│   │   ├── AgentMascotEnvironment.swift           # (11.0.1)
│   │   ├── AgentMascotFactory.swift               # (11.0.1)
│   │   ├── AgentOpenCodeView.swift                # (11.0.1)
│   │   └── AgentQoderView.swift                   # (11.0.1)
│   └── PixelKit/                                  # 4 files committed in 3c + 14 new
│       ├── AgentNotchAnimations.swift             # ✅ (3c)
│       ├── AgentPixelCharacterView.swift          # ✅ (3c)
│       ├── AgentMascotViewShell.swift             # ✅ (3c)
│       ├── AgentPixelKitEnvironment.swift         # ✅ (3c)
│       ├── AgentPixelText.swift                   # 🆕 (11.5.1)
│       ├── AgentClaudeLogoShape.swift             # 🆕 (11.5.2)
│       ├── AgentMiniAgentIcon.swift               # 🆕 (11.5.3)
│       ├── AgentTypingIndicator.swift             # 🆕 (11.5.4)
│       ├── AgentSessionTag.swift                  # 🆕 (11.5.5)
│       ├── AgentTerminalBadge.swift               # 🆕 (11.5.6)
│       ├── AgentPixelButton.swift                 # 🆕 (11.5.7)
│       ├── AgentIdleIndicatorBar.swift            # 🆕 (11.5.8)
│       ├── AgentNotchIconButton.swift             # 🆕 (11.5.9)
│       ├── AgentCompactToolStatus.swift           # 🆕 (11.5.10)
│       ├── AgentCompactWings.swift                # 🆕 (11.5.11)
│       ├── AgentThinScrollView.swift              # 🆕 (11.5.12)
│       ├── AgentSessionListView.swift             # 🆕 (11.5.13)
│       ├── AgentSessionIdentityLine.swift         # 🆕 (11.5.14)
│       └── AgentSessionCardLegacy.swift           # 🆕 (11.5.15)
├── UI/Sheets/
│   └── SettingsSheet.swift                        # expanded w/ 4 new sections (11.3.2)
├── Support/
│   └── L10n.swift                                 # full string parity (11.8)
└── AppDelegate.swift                              # StatusItem hookup (11.1.4)

Tests/
├── AgentMascotFactoryTests.swift                  # 🆕 (11.2.3)
├── AgentPixelKitSmokeTests.swift                  # 🆕 (11.5.16)
├── AppSettingsFullParityTests.swift               # 🆕 (11.3.3)
├── AgentSoundManagerTableTests.swift              # 🆕 (11.4.4)
├── AgentNotchControllerReactivityTests.swift      # 🆕 (11.6.5)
├── AgentCodexTranscriptTests.swift                # 🆕 (11.7.1)
├── AgentSessionSnapshotTitleTests.swift           # 🆕 (11.7.2)
├── AgentDerivedSessionStateTests.swift            # 🆕 (11.7.3)
├── AgentScreenDetectorParityTests.swift           # 🆕 (11.7.4)
├── AgentStatusItemControllerTests.swift           # ✅ (3d, 115 LOC)
└── L10nParityTests.swift                          # 🆕 (11.8.2)
```

---

# Phase 11.0 — Salvage Work-In-Progress from Rate-Limited Agents

Two Wave 3 agents were interrupted by the rate limit with uncommitted work still in their worktrees. Commit that work first so it isn't lost, then proceed.

## Task 11.0.1: Commit mascot files in `phase11/cli-mascots` worktree

**Files:**
- Worktree: `/Users/wuwenrui/Desktop/code/junfeng/AiyuTerm/.worktrees/p11-3a-mascots`
- Commit: 12 files under `AiyuTerm/UI/NotchPanel/Mascots/`

- [ ] **Step 1: Inspect uncommitted files in the mascot worktree**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm/.worktrees/p11-3a-mascots
git status --short
ls AiyuTerm/UI/NotchPanel/Mascots/
```

Expected: 12 untracked files (`AgentBuddyView.swift`, `AgentClaudeMascotView.swift`, `AgentCopilotView.swift`, `AgentCursorView.swift`, `AgentDexView.swift`, `AgentDroidView.swift`, `AgentGeminiView.swift`, `AgentGenericMascotView.swift`, `AgentMascotEnvironment.swift`, `AgentMascotFactory.swift`, `AgentOpenCodeView.swift`, `AgentQoderView.swift`).

- [ ] **Step 2: Run the build to verify the raw WIP compiles**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm/.worktrees/p11-3a-mascots
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`. If it fails, read the error, fix it minimally in the affected mascot file only (no cross-file changes), and re-run until it builds.

- [ ] **Step 3: Commit the mascot files**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm/.worktrees/p11-3a-mascots
git add AiyuTerm/UI/NotchPanel/Mascots/
git commit -m "feat(notch): salvage 12 CLI mascot files from rate-limited Wave 3A [P11.0.1]

Commits the work-in-progress from the phase11/cli-mascots agent
that was interrupted mid-task by the daily token limit. Covers:
- 8 per-CLI mascots (Buddy, Copilot, Cursor, Dex, Droid, Gemini,
  OpenCode, Qoder)
- AgentClaudeMascotView (Claude-specific sunburst)
- AgentGenericMascotView (unknown-source fallback)
- AgentMascotEnvironment (@Environment key for animation speed)
- AgentMascotFactory (source-tag → view dispatcher)

The factory is not yet integrated into SessionCardView — that
lands in Phase 11.2 after the branch is merged into main."
```

- [ ] **Step 4: Verify commit landed**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm/.worktrees/p11-3a-mascots
git log --oneline -1
git diff --stat HEAD~1 HEAD | tail
```

Expected: 1 new commit with 12 files added.

## Task 11.0.2: Commit WIP settings modifications in `phase11/full-settings` worktree

**Files:**
- Worktree: `/Users/wuwenrui/Desktop/code/junfeng/AiyuTerm/.worktrees/p11-3b-settings`
- 5 modified files: `WorkspaceStore.swift`, `AppDelegate.swift`, `AppSettings.swift`, `AgentSoundManager.swift`, `SettingsSheet.swift`

- [ ] **Step 1: Inspect modifications in the settings worktree**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm/.worktrees/p11-3b-settings
git status --short
git diff --stat
```

Expected: 5 modified files, no untracked. Check the diff scope matches the task (settings + sound fields + UI).

- [ ] **Step 2: Run the build to verify the WIP compiles**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm/.worktrees/p11-3b-settings
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`. If it fails (the agent was interrupted), read the last error and fix ONLY the broken spot — don't restructure the WIP.

- [ ] **Step 3: Commit the settings WIP**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm/.worktrees/p11-3b-settings
git add AiyuTerm/App/WorkspaceStore.swift AiyuTerm/AppDelegate.swift AiyuTerm/Domain/AppSettings.swift AiyuTerm/Services/Agent/Sound/AgentSoundManager.swift AiyuTerm/UI/Sheets/SettingsSheet.swift
git commit -m "feat(settings): salvage WIP from rate-limited Wave 3B [P11.0.2]

Commits the work-in-progress from the phase11/full-settings agent
that was interrupted mid-task by the daily token limit. Partial
coverage of:
- Expanded AppSettings key set
- AgentSoundManager table expansion
- SettingsSheet UI extensions
- WorkspaceStore + AppDelegate wire-up

Phase 11.3 + 11.4 will fill remaining gaps (20 keys total, full
sound entry table with volume slider, new settings tabs) after
merge."
```

- [ ] **Step 4: Verify commit landed**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm/.worktrees/p11-3b-settings
git log --oneline -1
git diff --stat HEAD~1 HEAD | tail -10
```

## Task 11.0.3: Confirm WIP already committed in pixel kit + controller worktrees

**Files:**
- `/Users/wuwenrui/Desktop/code/junfeng/AiyuTerm/.worktrees/p11-3c-pixelkit`
- `/Users/wuwenrui/Desktop/code/junfeng/AiyuTerm/.worktrees/p11-3d-controller`

- [ ] **Step 1: Confirm pixel kit worktree is clean**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm/.worktrees/p11-3c-pixelkit
git status --short
git log --oneline ^d229a74 2>&1 | head -5
```

Expected: clean working dir, 1 commit (`feat(pixelkit): port standalone pixel files ...`) on top of `d229a74`.

- [ ] **Step 2: Confirm controller worktree is clean**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm/.worktrees/p11-3d-controller
git status --short
git log --oneline ^d229a74 2>&1 | head -5
```

Expected: clean working dir, 1 commit (`feat(statusitem): port AgentStatusItemController ...`) on top of `d229a74`.

---

# Phase 11.1 — Merge All Four Wave 3 Branches

Merge order chosen to minimize conflict surface: smallest diff first, largest last.

## Task 11.1.1: Merge `phase11/pixel-kit` (4 new files, no overlap)

**Files:**
- Merge target: `feat/codeisland-integration` (in main worktree)

- [ ] **Step 1: Switch to main worktree**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
git worktree list | head
```

Confirm you are in the main tree (shown in `git worktree list` without `.worktrees/` prefix).

- [ ] **Step 2: Merge pixel-kit**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
git merge phase11/pixel-kit --no-ff -m "Phase 11.1.1: merge pixel-kit standalone files

Adds 4 files from the phase11/pixel-kit Wave 3C agent:
- AgentNotchAnimations.swift
- AgentPixelCharacterView.swift
- AgentMascotViewShell.swift
- AgentPixelKitEnvironment.swift

Phase 11.5 will extend this kit with 14 more sub-components
extracted from NotchPanelView.swift." 2>&1 | tail -10
```

Expected: clean merge. If conflict occurs, abort, document, then retry with manual conflict resolution (no files on main should overlap).

- [ ] **Step 3: Verify build after merge**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -configuration Debug -destination 'platform=macOS' build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head
```

Expected: `** BUILD SUCCEEDED **`.

## Task 11.1.2: Merge `phase11/controller-reactive` (status item + tests)

- [ ] **Step 1: Merge**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
git merge phase11/controller-reactive --no-ff -m "Phase 11.1.2: merge AgentStatusItemController

Adds from phase11/controller-reactive Wave 3D:
- AgentStatusItemController.swift (menu bar item)
- AgentStatusItemControllerTests.swift (115 LOC)
- WorkspaceStore wire-up hook

Phase 11.6 will add reactive fullscreen + collapseOnMouseLeave
+ hideWhenNoSession behavior. Phase 11.7 will port upstream
test parity (Codex transcript, derived state, screen detector)." 2>&1 | tail -15
```

- [ ] **Step 2: Resolve any `WorkspaceStore.swift` conflict**

If git reports a conflict in `WorkspaceStore.swift`, open it and merge both sides:
- Keep the Phase 10.1/10.2 lifecycle additions from HEAD
- Keep the StatusItem wire-up from `phase11/controller-reactive`

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
grep -n "<<<<<<< \|======= \|>>>>>>> " AiyuTerm/App/WorkspaceStore.swift
```

For each conflict block, keep BOTH additions (both sides are non-destructive adds), then:

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
git add AiyuTerm/App/WorkspaceStore.swift
git commit --no-edit
```

- [ ] **Step 3: Build verification**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -configuration Debug -destination 'platform=macOS' build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head
```

## Task 11.1.3: Merge `phase11/cli-mascots` (12 mascot files + 1 SessionCardView edit)

- [ ] **Step 1: Merge**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
git merge phase11/cli-mascots --no-ff -m "Phase 11.1.3: merge 12 CLI mascot files

Adds from phase11/cli-mascots Wave 3A:
- 8 per-CLI mascot views (Buddy, Copilot, Cursor, Dex, Droid,
  Gemini, OpenCode, Qoder)
- AgentClaudeMascotView
- AgentGenericMascotView
- AgentMascotEnvironment (env key for animation speed)
- AgentMascotFactory (source → view dispatcher)

Integration into SessionCardView lands in Phase 11.9 so it can
coordinate with the pixel-kit integration." 2>&1 | tail -10
```

- [ ] **Step 2: Resolve conflicts on `AgentNotchPanelView.swift`** (likely)

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
grep -n "<<<<<<< \|======= \|>>>>>>> " AiyuTerm/UI/NotchPanel/AgentNotchPanelView.swift
```

The 3a agent was supposed to integrate mascot into SessionCardView. Keep both sides where possible (the 3a changes add a `mascotView` computed property, the HEAD changes add `display` parameter). If truly incompatible, favor HEAD (it's already tested) and defer mascot integration to Phase 11.9.

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
git add AiyuTerm/UI/NotchPanel/AgentNotchPanelView.swift
git commit --no-edit
```

- [ ] **Step 3: Build verification**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -configuration Debug -destination 'platform=macOS' build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head
```

## Task 11.1.4: Merge `phase11/full-settings` (5 files, likely conflicts)

- [ ] **Step 1: Merge**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
git merge phase11/full-settings --no-ff -m "Phase 11.1.4: merge Wave 3B settings WIP

Merges the work-in-progress from phase11/full-settings. Partial
coverage of new settings + sound entries. Phase 11.3 and 11.4
will complete the parity." 2>&1 | tail -15
```

- [ ] **Step 2: Resolve conflicts**

Expected conflicts on `AppSettings.swift`, `AgentSoundManager.swift`, `WorkspaceStore.swift`.

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
git diff --name-only --diff-filter=U
```

For each conflicted file:
- Read the conflict markers
- Preserve all HEAD additions (they are tested/committed)
- Preserve all settings WIP additions (keys, entries, UI sections)
- When both sides define the same field, keep the HEAD version

Mark resolved + commit:

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
git add -u
git commit --no-edit
```

- [ ] **Step 3: Build verification**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -configuration Debug -destination 'platform=macOS' build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head
```

Expected: `** BUILD SUCCEEDED **`.

## Task 11.1.5: Unify duplicate `mascotSpeed` env keys

**Files:**
- Modify: `AiyuTerm/UI/NotchPanel/Mascots/AgentMascotEnvironment.swift`
- Modify: `AiyuTerm/UI/NotchPanel/PixelKit/AgentPixelKitEnvironment.swift`

Two agents both defined env keys for mascot speed. Keep ONE canonical definition.

- [ ] **Step 1: Read both files**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
cat AiyuTerm/UI/NotchPanel/Mascots/AgentMascotEnvironment.swift
cat AiyuTerm/UI/NotchPanel/PixelKit/AgentPixelKitEnvironment.swift
```

- [ ] **Step 2: Canonicalize in `AgentMascotEnvironment.swift`**

Keep `AgentMascotEnvironment.swift` as the canonical definition (it's in the Mascots directory, semantically correct). Replace `AgentPixelKitEnvironment.swift` with a re-export comment:

```swift
//
// AgentPixelKitEnvironment.swift
// AiyuTerm
//
// This file previously declared a duplicate
// `pixelKitMascotSpeed` environment key. It has been unified
// with the canonical `agentMascotSpeed` key defined in
// `AgentMascotEnvironment.swift`. Consumers of the old key
// can continue using it via the typealias below.
//

import SwiftUI

typealias AgentPixelKitMascotSpeed = AgentMascotSpeed

extension EnvironmentValues {
    /// Deprecated alias for `agentMascotSpeed`. Kept so the
    /// pixel-kit files written before unification still compile.
    var pixelKitMascotSpeed: AgentMascotSpeed {
        get { agentMascotSpeed }
        set { agentMascotSpeed = newValue }
    }
}
```

- [ ] **Step 3: Build**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -configuration Debug -destination 'platform=macOS' build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head
```

- [ ] **Step 4: Commit**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
git add AiyuTerm/UI/NotchPanel/PixelKit/AgentPixelKitEnvironment.swift
git commit -m "refactor(notch): unify mascot speed env keys to AgentMascotEnvironment

Two Wave 3 agents independently created env keys for mascot
animation speed. This consolidates them:

- AgentMascotEnvironment.swift is the canonical definition
  (typed enum AgentMascotSpeed + agentMascotSpeed key)
- AgentPixelKitEnvironment.swift becomes a thin compat shim
  that exposes pixelKitMascotSpeed as a typealias/forwarder
  so the pixel-kit files keep compiling

Phase 11.5 will migrate the pixel-kit files to call
agentMascotSpeed directly and remove the shim."
```

## Task 11.1.6: Cleanup worktrees after successful merges

- [ ] **Step 1: Remove merged worktrees**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
git worktree remove .worktrees/p11-3a-mascots --force
git worktree remove .worktrees/p11-3b-settings --force
git worktree remove .worktrees/p11-3c-pixelkit --force
git worktree remove .worktrees/p11-3d-controller --force
git worktree list
```

Expected: only `AiyuTerm` main worktree + `.claude/worktrees/funny-zhukovsky` remain.

---

# Phase 11.2 — Integrate Mascots into Session Cards (TDD)

Phase 11.1.3 merged the mascot files but did not wire them into the UI. Integrate now.

## Task 11.2.1: Write failing test for mascot dispatch in SessionCardView

**Files:**
- Test: `Tests/AgentMascotFactoryTests.swift` (create)

- [ ] **Step 1: Write the test file**

```swift
//
// AgentMascotFactoryTests.swift
// AiyuTermTests
//
// Phase 11.2: ensure AgentMascotFactory returns a non-nil
// concrete view for every supported CLI source, plus a sane
// fallback for unknown sources.
//

import Foundation
import SwiftUI
import XCTest
@testable import AiyuTerm

final class AgentMascotFactoryTests: XCTestCase {

    func testFactoryReturnsViewForEveryKnownSource() {
        let knownSources = [
            "claude", "codex", "gemini", "cursor", "copilot",
            "qoder", "codebuddy", "droid", "opencode",
        ]
        for source in knownSources {
            let view = AgentMascotFactory.mascot(
                for: source,
                status: .none,
                size: 27
            )
            // Force body evaluation so any crashing initializer
            // shows up as a test failure instead of a silent nil.
            _ = AnyView(view)
        }
    }

    func testFactoryFallsBackForUnknownSource() {
        let view = AgentMascotFactory.mascot(
            for: "totally-made-up-cli",
            status: .none,
            size: 27
        )
        _ = AnyView(view)
    }

    func testMascotSpeedHasDistinctFrameIntervals() {
        let intervals: [TimeInterval] = AgentMascotSpeed.allCases.map { $0.frameInterval }
        let unique = Set(intervals)
        XCTAssertEqual(unique.count, AgentMascotSpeed.allCases.count)
    }

    func testMascotSpeedIsCodable() throws {
        let original = AgentMascotSpeed.fast
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AgentMascotSpeed.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }
}
```

Write the file to `Tests/AgentMascotFactoryTests.swift`.

- [ ] **Step 2: Run the test, expect compile error**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -destination 'platform=macOS' test -only-testing:AiyuTermTests/AgentMascotFactoryTests 2>&1 | grep -E "error:|Test case|BUILD (SUCCEEDED|FAILED)" | head -10
```

Expected: may compile (the files merged from 3a already exist) — check if build succeeds. If it does, that means the factory + all mascots compile and the test passes. If it fails, read the error and proceed to Step 3.

- [ ] **Step 3: If the factory was incomplete, fix it**

Open `AiyuTerm/UI/NotchPanel/Mascots/AgentMascotFactory.swift`. Confirm it has a switch that covers all 9 sources. If any are missing, add them. If `AgentMascotSpeed` isn't `CaseIterable` or `Codable`, add conformance in `AgentMascotEnvironment.swift`:

```swift
enum AgentMascotSpeed: Int, CaseIterable, Codable, Sendable {
    case slow = 0
    case normal = 1
    case fast = 2

    var frameInterval: TimeInterval {
        switch self {
        case .slow: return 0.8
        case .normal: return 0.5
        case .fast: return 0.25
        }
    }
}
```

- [ ] **Step 4: Re-run test, expect PASS**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -destination 'platform=macOS' test -only-testing:AiyuTermTests/AgentMascotFactoryTests 2>&1 | grep -cE "^Test case .* passed"
```

Expected: `4`.

- [ ] **Step 5: Commit**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
git add Tests/AgentMascotFactoryTests.swift
git add AiyuTerm/UI/NotchPanel/Mascots/AgentMascotEnvironment.swift AiyuTerm/UI/NotchPanel/Mascots/AgentMascotFactory.swift 2>/dev/null
git commit -m "test(mascot): AgentMascotFactory covers all 9 sources + fallback [P11.2.1]"
```

## Task 11.2.2: Wire mascot into SessionCardView titleRow

**Files:**
- Modify: `AiyuTerm/UI/NotchPanel/AgentNotchPanelView.swift` (`SessionCardView.titleRow`)

- [ ] **Step 1: Locate the current titleRow definition**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
grep -n "private var titleRow:" AiyuTerm/UI/NotchPanel/AgentNotchPanelView.swift
```

- [ ] **Step 2: Replace the current `statusDot` with a mascot + keep the status dot as an overlay indicator**

Find this block in `SessionCardView`:

```swift
private var titleRow: some View {
    HStack(spacing: 8) {
        statusDot
        VStack(alignment: .leading, spacing: 0) {
```

Replace with:

```swift
private var titleRow: some View {
    HStack(spacing: 8) {
        // Phase 11.2: mascot + small status dot in bottom-right
        ZStack(alignment: .bottomTrailing) {
            AgentMascotFactory.mascot(
                for: snapshot.source,
                status: snapshot.status,
                size: 27
            )
            .frame(width: 27, height: 27)
            statusDot
                .offset(x: 3, y: 3)
        }
        VStack(alignment: .leading, spacing: 0) {
```

Do not modify the rest of `titleRow`.

- [ ] **Step 3: Build**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -configuration Debug -destination 'platform=macOS' build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head
```

- [ ] **Step 4: Run existing notch tests to verify no regression**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -destination 'platform=macOS' test \
  -only-testing:AiyuTermTests/AgentNotchPanelViewModelTests \
  -only-testing:AiyuTermTests/AgentNotchPanelShapeTests \
  -only-testing:AiyuTermTests/AgentMascotFactoryTests 2>&1 | grep -cE "^Test case .* passed"
```

Expected: at least 38 (13 + 21 + 4).

- [ ] **Step 5: Commit**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
git add AiyuTerm/UI/NotchPanel/AgentNotchPanelView.swift
git commit -m "feat(notch): integrate AgentMascotFactory into SessionCardView titleRow [P11.2.2]

The card now shows a 27px per-CLI mascot next to the workspace
name, with the existing 8px status dot overlaid in the
bottom-right corner as a secondary indicator. Unknown sources
fall back to AgentGenericMascotView."
```

## Task 11.2.3: Thread `agentMascotSpeed` from settings into the view tree

**Files:**
- Modify: `AiyuTerm/App/WorkspaceStore.swift` (notch view model bootstrap)

- [ ] **Step 1: Verify `notchMascotSpeed` exists in AppSettings**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
grep -n "notchMascotSpeed" AiyuTerm/Domain/AppSettings.swift
```

If absent, add it in Phase 11.3 — for now leave as a static default.

- [ ] **Step 2: Set env value in `AgentNotchPanelController.swift` when building hosting view**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
grep -n "NSHostingView\|NSHostingController" AiyuTerm/UI/NotchPanel/AgentNotchPanelController.swift
```

Wrap the SwiftUI root with `.environment(\.agentMascotSpeed, …)` — since we don't have `notchMascotSpeed` in settings yet, default to `.normal`:

```swift
let rootView = AgentNotchPanelView(viewModel: viewModel)
    .environment(\.agentMascotSpeed, .normal)
```

Replace the existing hosting-view instantiation to use `rootView`.

- [ ] **Step 3: Build**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -configuration Debug -destination 'platform=macOS' build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head
```

- [ ] **Step 4: Commit**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
git add AiyuTerm/UI/NotchPanel/AgentNotchPanelController.swift
git commit -m "feat(notch): inject agentMascotSpeed env into notch hosting view [P11.2.3]

Phase 11.3 will replace the hardcoded .normal with a value read
from AppSettings.notchMascotSpeed."
```

---

# Phase 11.3 — Complete Settings Key Parity (19 remaining keys / 17 new fields)

Upstream has 29 settings keys. After Phase 10 + Wave 3B salvage we have at most 10 — still missing 19. This phase adds 17 NEW `AppSettings` fields; the remaining 2 keys (`shortcutKeyCode`, `shortcutModifiers`) reuse the existing `keyboardShortcutOverrides: [String: KeyboardShortcutOverride]` storage and only need new action keys registered (handled in Task 11.3.1).

## Task 11.3.1: Audit current AppSettings and list the exact 19 missing keys

- [ ] **Step 1: Grep current fields**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
grep -E "^    var (notch|agentSound)" AiyuTerm/Domain/AppSettings.swift
```

- [ ] **Step 2: Cross-reference against upstream `Settings.swift`**

```bash
grep -oE "SettingsKey\.[a-zA-Z]+" /tmp/codeisland-research/Sources/CodeIsland/Settings.swift | sort -u | sed 's/^SettingsKey\.//'
```

Known target list (19 keys total):

| Upstream name | Our name | Type | Default | Clamp |
|---|---|---|---|---|
| `displayChoice` | `notchDisplayChoice` | String | `"auto"` | enum values: `"auto"`, `"builtin"`, `"external"` |
| `allowHorizontalDrag` | `notchAllowHorizontalDrag` | Bool | `false` | — |
| `panelHorizontalOffset` | `notchPanelHorizontalOffset` | Double | `0` | `-200...200` |
| `maxPanelHeight` | `notchMaxPanelHeight` | Double | `520` | `240...1200` |
| `contentFontSize` | `notchContentFontSize` | Double | `11` | `9...16` |
| `rotationInterval` | `notchRotationInterval` | Int | `5` | `2...60` |
| `maxToolHistory` | `notchMaxToolHistory` | Int | `20` | `5...100` |
| `sessionGroupingMode` | `notchSessionGroupingMode` | String | `"byWorkspace"` | `"byWorkspace"`, `"flat"` |
| `showAgentDetails` | `notchShowAgentDetails` | Bool | `true` | — |
| `mascotSpeed` | `notchMascotSpeed` | Int | `1` | `0...2` |
| `soundVolume` | `agentSoundVolume` | Double | `0.7` | `0.0...1.0` |
| `soundSessionStart` | `agentSoundSessionStart` | Bool | `true` | — |
| `soundTaskComplete` | `agentSoundTaskComplete` | Bool | `true` | — |
| `soundTaskError` | `agentSoundTaskError` | Bool | `true` | — |
| `soundApprovalNeeded` | `agentSoundApprovalNeeded` | Bool | `true` | — |
| `soundPromptSubmit` | `agentSoundPromptSubmit` | Bool | `false` | — |
| `soundBoot` | `agentSoundBoot` | Bool | `true` | — |
| `shortcutEnabled` | `notchShortcutOverrides` | `[String: KeyboardShortcutOverride]` (reuse existing) | `[:]` | — |
| (Keyboard modifiers collapsed into existing dict) | — | — | — | — |

Verify the list matches what Wave 3B already added — any already present is dropped from this task.

## Task 11.3.2: Add 17 new fields + tests (TDD)

**Files:**
- Test: `Tests/AppSettingsFullParityTests.swift` (create)
- Modify: `AiyuTerm/Domain/AppSettings.swift`

- [ ] **Step 1: Write the failing test**

```swift
//
// AppSettingsFullParityTests.swift
// AiyuTermTests
//
// Phase 11.3: verify every one of the 19 remaining upstream
// settings keys exists on our AppSettings with the documented
// default, decodes from legacy empty JSON with that default, and
// survives a full encode → decode round-trip. Also verify clamps.
//

import Foundation
import XCTest
@testable import AiyuTerm

final class AppSettingsFullParityTests: XCTestCase {

    // MARK: - Defaults

    func testFreshAppSettingsHasAllPhase11Defaults() {
        let s = AppSettings()
        XCTAssertEqual(s.notchDisplayChoice, "auto")
        XCTAssertEqual(s.notchAllowHorizontalDrag, false)
        XCTAssertEqual(s.notchPanelHorizontalOffset, 0)
        XCTAssertEqual(s.notchMaxPanelHeight, 520)
        XCTAssertEqual(s.notchContentFontSize, 11)
        XCTAssertEqual(s.notchRotationInterval, 5)
        XCTAssertEqual(s.notchMaxToolHistory, 20)
        XCTAssertEqual(s.notchSessionGroupingMode, "byWorkspace")
        XCTAssertEqual(s.notchShowAgentDetails, true)
        XCTAssertEqual(s.notchMascotSpeed, 1)
        XCTAssertEqual(s.agentSoundVolume, 0.7, accuracy: 0.0001)
        XCTAssertEqual(s.agentSoundSessionStart, true)
        XCTAssertEqual(s.agentSoundTaskComplete, true)
        XCTAssertEqual(s.agentSoundTaskError, true)
        XCTAssertEqual(s.agentSoundApprovalNeeded, true)
        XCTAssertEqual(s.agentSoundPromptSubmit, false)
        XCTAssertEqual(s.agentSoundBoot, true)
    }

    // MARK: - Legacy empty JSON

    func testLegacyEmptyJSONDecodesAllPhase11Defaults() throws {
        let data = Data("{}".utf8)
        let s = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(s.notchDisplayChoice, "auto")
        XCTAssertEqual(s.notchMaxPanelHeight, 520)
        XCTAssertEqual(s.notchMascotSpeed, 1)
        XCTAssertEqual(s.agentSoundVolume, 0.7, accuracy: 0.0001)
        XCTAssertEqual(s.agentSoundPromptSubmit, false)
    }

    // MARK: - Round-trip

    func testEncodeDecodeRoundTripPreservesAllPhase11Keys() throws {
        var s = AppSettings()
        s.notchDisplayChoice = "external"
        s.notchAllowHorizontalDrag = true
        s.notchPanelHorizontalOffset = 42
        s.notchMaxPanelHeight = 800
        s.notchContentFontSize = 13
        s.notchRotationInterval = 10
        s.notchMaxToolHistory = 50
        s.notchSessionGroupingMode = "flat"
        s.notchShowAgentDetails = false
        s.notchMascotSpeed = 2
        s.agentSoundVolume = 0.3
        s.agentSoundSessionStart = false
        s.agentSoundTaskComplete = false
        s.agentSoundTaskError = false
        s.agentSoundApprovalNeeded = false
        s.agentSoundPromptSubmit = true
        s.agentSoundBoot = false

        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(decoded.notchDisplayChoice, "external")
        XCTAssertTrue(decoded.notchAllowHorizontalDrag)
        XCTAssertEqual(decoded.notchPanelHorizontalOffset, 42)
        XCTAssertEqual(decoded.notchMaxPanelHeight, 800)
        XCTAssertEqual(decoded.notchContentFontSize, 13)
        XCTAssertEqual(decoded.notchRotationInterval, 10)
        XCTAssertEqual(decoded.notchMaxToolHistory, 50)
        XCTAssertEqual(decoded.notchSessionGroupingMode, "flat")
        XCTAssertFalse(decoded.notchShowAgentDetails)
        XCTAssertEqual(decoded.notchMascotSpeed, 2)
        XCTAssertEqual(decoded.agentSoundVolume, 0.3, accuracy: 0.0001)
        XCTAssertFalse(decoded.agentSoundSessionStart)
        XCTAssertFalse(decoded.agentSoundTaskComplete)
        XCTAssertFalse(decoded.agentSoundTaskError)
        XCTAssertFalse(decoded.agentSoundApprovalNeeded)
        XCTAssertTrue(decoded.agentSoundPromptSubmit)
        XCTAssertFalse(decoded.agentSoundBoot)
    }

    // MARK: - Clamps

    func testClampsPanelHorizontalOffset() {
        var s = AppSettings()
        s.notchPanelHorizontalOffset = 9999
        // Re-run the clamping by going through the designated init
        let re = AppSettings(notchPanelHorizontalOffset: 9999)
        XCTAssertLessThanOrEqual(re.notchPanelHorizontalOffset, 200)
    }

    func testClampsMaxPanelHeight() {
        let re = AppSettings(notchMaxPanelHeight: 10000)
        XCTAssertLessThanOrEqual(re.notchMaxPanelHeight, 1200)
    }

    func testClampsContentFontSize() {
        let low = AppSettings(notchContentFontSize: 2)
        XCTAssertGreaterThanOrEqual(low.notchContentFontSize, 9)
        let high = AppSettings(notchContentFontSize: 99)
        XCTAssertLessThanOrEqual(high.notchContentFontSize, 16)
    }

    func testClampsSoundVolume() {
        let low = AppSettings(agentSoundVolume: -0.5)
        XCTAssertGreaterThanOrEqual(low.agentSoundVolume, 0)
        let high = AppSettings(agentSoundVolume: 10)
        XCTAssertLessThanOrEqual(high.agentSoundVolume, 1)
    }

    func testClampsMascotSpeed() {
        let low = AppSettings(notchMascotSpeed: -5)
        XCTAssertGreaterThanOrEqual(low.notchMascotSpeed, 0)
        let high = AppSettings(notchMascotSpeed: 99)
        XCTAssertLessThanOrEqual(high.notchMascotSpeed, 2)
    }
}
```

Save to `Tests/AppSettingsFullParityTests.swift`.

- [ ] **Step 2: Run the test, expect compile fail**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -destination 'platform=macOS' test -only-testing:AiyuTermTests/AppSettingsFullParityTests 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head -10
```

Expected: build fails with undefined field errors.

- [ ] **Step 3: Add the 19 fields to AppSettings**

Open `AiyuTerm/Domain/AppSettings.swift`. Add the fields directly after the existing notch/agentSound block:

```swift
    // Phase 11.3: full CodeIsland settings parity (19 new keys)
    var notchDisplayChoice: String = "auto"
    var notchAllowHorizontalDrag: Bool = false
    var notchPanelHorizontalOffset: Double = 0
    var notchMaxPanelHeight: Double = 520
    var notchContentFontSize: Double = 11
    var notchRotationInterval: Int = 5
    var notchMaxToolHistory: Int = 20
    var notchSessionGroupingMode: String = "byWorkspace"
    var notchShowAgentDetails: Bool = true
    var notchMascotSpeed: Int = 1
    var agentSoundVolume: Double = 0.7
    var agentSoundSessionStart: Bool = true
    var agentSoundTaskComplete: Bool = true
    var agentSoundTaskError: Bool = true
    var agentSoundApprovalNeeded: Bool = true
    var agentSoundPromptSubmit: Bool = false
    var agentSoundBoot: Bool = true
```

- [ ] **Step 4: Add the 19 params to the designated init with clamps**

In the `init(...)` signature, add 17 new parameters (two-letter style:

```swift
notchDisplayChoice: String = "auto",
notchAllowHorizontalDrag: Bool = false,
notchPanelHorizontalOffset: Double = 0,
notchMaxPanelHeight: Double = 520,
notchContentFontSize: Double = 11,
notchRotationInterval: Int = 5,
notchMaxToolHistory: Int = 20,
notchSessionGroupingMode: String = "byWorkspace",
notchShowAgentDetails: Bool = true,
notchMascotSpeed: Int = 1,
agentSoundVolume: Double = 0.7,
agentSoundSessionStart: Bool = true,
agentSoundTaskComplete: Bool = true,
agentSoundTaskError: Bool = true,
agentSoundApprovalNeeded: Bool = true,
agentSoundPromptSubmit: Bool = false,
agentSoundBoot: Bool = true
```

In the body, assign with clamps:

```swift
self.notchDisplayChoice = ["auto", "builtin", "external"].contains(notchDisplayChoice) ? notchDisplayChoice : "auto"
self.notchAllowHorizontalDrag = notchAllowHorizontalDrag
self.notchPanelHorizontalOffset = max(-200, min(notchPanelHorizontalOffset, 200))
self.notchMaxPanelHeight = max(240, min(notchMaxPanelHeight, 1200))
self.notchContentFontSize = max(9, min(notchContentFontSize, 16))
self.notchRotationInterval = max(2, min(notchRotationInterval, 60))
self.notchMaxToolHistory = max(5, min(notchMaxToolHistory, 100))
self.notchSessionGroupingMode = ["byWorkspace", "flat"].contains(notchSessionGroupingMode) ? notchSessionGroupingMode : "byWorkspace"
self.notchShowAgentDetails = notchShowAgentDetails
self.notchMascotSpeed = max(0, min(notchMascotSpeed, 2))
self.agentSoundVolume = max(0, min(agentSoundVolume, 1))
self.agentSoundSessionStart = agentSoundSessionStart
self.agentSoundTaskComplete = agentSoundTaskComplete
self.agentSoundTaskError = agentSoundTaskError
self.agentSoundApprovalNeeded = agentSoundApprovalNeeded
self.agentSoundPromptSubmit = agentSoundPromptSubmit
self.agentSoundBoot = agentSoundBoot
```

- [ ] **Step 5: Add CodingKeys + decodeIfPresent**

Add to `CodingKeys`:

```swift
case notchDisplayChoice
case notchAllowHorizontalDrag
case notchPanelHorizontalOffset
case notchMaxPanelHeight
case notchContentFontSize
case notchRotationInterval
case notchMaxToolHistory
case notchSessionGroupingMode
case notchShowAgentDetails
case notchMascotSpeed
case agentSoundVolume
case agentSoundSessionStart
case agentSoundTaskComplete
case agentSoundTaskError
case agentSoundApprovalNeeded
case agentSoundPromptSubmit
case agentSoundBoot
```

In `init(from:)`, add `decodeIfPresent` calls for each:

```swift
notchDisplayChoice: try container.decodeIfPresent(String.self, forKey: .notchDisplayChoice) ?? "auto",
notchAllowHorizontalDrag: try container.decodeIfPresent(Bool.self, forKey: .notchAllowHorizontalDrag) ?? false,
notchPanelHorizontalOffset: try container.decodeIfPresent(Double.self, forKey: .notchPanelHorizontalOffset) ?? 0,
notchMaxPanelHeight: try container.decodeIfPresent(Double.self, forKey: .notchMaxPanelHeight) ?? 520,
notchContentFontSize: try container.decodeIfPresent(Double.self, forKey: .notchContentFontSize) ?? 11,
notchRotationInterval: try container.decodeIfPresent(Int.self, forKey: .notchRotationInterval) ?? 5,
notchMaxToolHistory: try container.decodeIfPresent(Int.self, forKey: .notchMaxToolHistory) ?? 20,
notchSessionGroupingMode: try container.decodeIfPresent(String.self, forKey: .notchSessionGroupingMode) ?? "byWorkspace",
notchShowAgentDetails: try container.decodeIfPresent(Bool.self, forKey: .notchShowAgentDetails) ?? true,
notchMascotSpeed: try container.decodeIfPresent(Int.self, forKey: .notchMascotSpeed) ?? 1,
agentSoundVolume: try container.decodeIfPresent(Double.self, forKey: .agentSoundVolume) ?? 0.7,
agentSoundSessionStart: try container.decodeIfPresent(Bool.self, forKey: .agentSoundSessionStart) ?? true,
agentSoundTaskComplete: try container.decodeIfPresent(Bool.self, forKey: .agentSoundTaskComplete) ?? true,
agentSoundTaskError: try container.decodeIfPresent(Bool.self, forKey: .agentSoundTaskError) ?? true,
agentSoundApprovalNeeded: try container.decodeIfPresent(Bool.self, forKey: .agentSoundApprovalNeeded) ?? true,
agentSoundPromptSubmit: try container.decodeIfPresent(Bool.self, forKey: .agentSoundPromptSubmit) ?? false,
agentSoundBoot: try container.decodeIfPresent(Bool.self, forKey: .agentSoundBoot) ?? true
```

- [ ] **Step 6: Run the test, expect all pass**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -destination 'platform=macOS' test -only-testing:AiyuTermTests/AppSettingsFullParityTests 2>&1 | grep -cE "^Test case .* passed"
```

Expected: `10`.

- [ ] **Step 7: Run the existing AppSettingsNotchKeysTests to verify no regression**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -destination 'platform=macOS' test -only-testing:AiyuTermTests/AppSettingsNotchKeysTests 2>&1 | grep -cE "^Test case .* passed"
```

Expected: `4` (the existing test count).

- [ ] **Step 8: Commit**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
git add AiyuTerm/Domain/AppSettings.swift Tests/AppSettingsFullParityTests.swift
git commit -m "feat(settings): add remaining 19 CodeIsland settings keys + parity tests [P11.3.2]

Completes AppSettings parity with upstream CodeIsland. All 29
upstream keys now have a mapped field on AppSettings, with
defaults, clamps, CodingKeys, and decodeIfPresent fallbacks for
legacy JSON migration.

New fields:
* Notch layout: displayChoice, allowHorizontalDrag,
  panelHorizontalOffset, maxPanelHeight, contentFontSize,
  rotationInterval, maxToolHistory, sessionGroupingMode,
  showAgentDetails, mascotSpeed
* Sound: soundVolume + 6 per-event toggles (sessionStart,
  taskComplete, taskError, approvalNeeded, promptSubmit, boot)

New tests (AppSettingsFullParityTests):
- testFreshAppSettingsHasAllPhase11Defaults
- testLegacyEmptyJSONDecodesAllPhase11Defaults
- testEncodeDecodeRoundTripPreservesAllPhase11Keys
- testClampsPanelHorizontalOffset / MaxPanelHeight /
  ContentFontSize / SoundVolume / MascotSpeed

10 new tests, all green. Preserves the 4 existing
AppSettingsNotchKeysTests cases."
```

## Task 11.3.3: Expand SettingsSheet with Notch-Layout / Sounds / Mascots / Shortcuts sections

**Files:**
- Modify: `AiyuTerm/UI/Sheets/SettingsSheet.swift`

- [ ] **Step 1: Find the current notch section**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
grep -n "notchPanelEnabled\|notchHideInFullscreen" AiyuTerm/UI/Sheets/SettingsSheet.swift
```

- [ ] **Step 2: Extend with four new GroupBox sections inside the existing notch panel gate**

Below the existing 8 toggles, add:

```swift
// Phase 11.3: CodeIsland parity — layout knobs
GroupBox("Notch Layout") {
    VStack(alignment: .leading, spacing: 8) {
        HStack {
            Text("Display")
            Spacer()
            Picker("", selection: $appSettings.wrappedValue.notchDisplayChoice) {
                Text("Auto").tag("auto")
                Text("Built-in").tag("builtin")
                Text("External").tag("external")
            }
            .labelsHidden()
            .frame(width: 140)
        }
        Toggle("Allow horizontal drag", isOn: $appSettings.wrappedValue.notchAllowHorizontalDrag)
        HStack {
            Text("Horizontal offset")
            Spacer()
            Slider(value: $appSettings.wrappedValue.notchPanelHorizontalOffset, in: -200...200, step: 5)
                .frame(width: 180)
            Text("\(Int(appSettings.wrappedValue.notchPanelHorizontalOffset))")
                .frame(width: 40, alignment: .trailing)
        }
        HStack {
            Text("Max panel height")
            Spacer()
            Stepper(value: $appSettings.wrappedValue.notchMaxPanelHeight, in: 240...1200, step: 20) {
                Text("\(Int(appSettings.wrappedValue.notchMaxPanelHeight))")
            }
            .frame(width: 160)
        }
        HStack {
            Text("Content font size")
            Spacer()
            Stepper(value: $appSettings.wrappedValue.notchContentFontSize, in: 9...16, step: 1) {
                Text("\(Int(appSettings.wrappedValue.notchContentFontSize))")
            }
            .frame(width: 140)
        }
        HStack {
            Text("Rotation interval (s)")
            Spacer()
            Stepper(value: $appSettings.wrappedValue.notchRotationInterval, in: 2...60, step: 1) {
                Text("\(appSettings.wrappedValue.notchRotationInterval)")
            }
            .frame(width: 140)
        }
        HStack {
            Text("Max tool history")
            Spacer()
            Stepper(value: $appSettings.wrappedValue.notchMaxToolHistory, in: 5...100, step: 5) {
                Text("\(appSettings.wrappedValue.notchMaxToolHistory)")
            }
            .frame(width: 140)
        }
        HStack {
            Text("Session grouping")
            Spacer()
            Picker("", selection: $appSettings.wrappedValue.notchSessionGroupingMode) {
                Text("By workspace").tag("byWorkspace")
                Text("Flat list").tag("flat")
            }
            .labelsHidden()
            .frame(width: 140)
        }
        Toggle("Show agent details", isOn: $appSettings.wrappedValue.notchShowAgentDetails)
    }
    .padding(6)
}

GroupBox("Mascots") {
    HStack {
        Text("Animation speed")
        Spacer()
        Picker("", selection: $appSettings.wrappedValue.notchMascotSpeed) {
            Text("Slow").tag(0)
            Text("Normal").tag(1)
            Text("Fast").tag(2)
        }
        .labelsHidden()
        .frame(width: 140)
    }
    .padding(6)
}

GroupBox("Sounds") {
    VStack(alignment: .leading, spacing: 8) {
        Toggle("Enable agent sounds", isOn: $appSettings.wrappedValue.agentSoundEnabled)
        HStack {
            Text("Volume")
            Spacer()
            Slider(value: $appSettings.wrappedValue.agentSoundVolume, in: 0...1, step: 0.05)
                .frame(width: 180)
        }
        .disabled(!appSettings.wrappedValue.agentSoundEnabled)
        Toggle("Session start", isOn: $appSettings.wrappedValue.agentSoundSessionStart)
            .disabled(!appSettings.wrappedValue.agentSoundEnabled)
        Toggle("Task complete", isOn: $appSettings.wrappedValue.agentSoundTaskComplete)
            .disabled(!appSettings.wrappedValue.agentSoundEnabled)
        Toggle("Task error", isOn: $appSettings.wrappedValue.agentSoundTaskError)
            .disabled(!appSettings.wrappedValue.agentSoundEnabled)
        Toggle("Permission request", isOn: $appSettings.wrappedValue.agentSoundApprovalNeeded)
            .disabled(!appSettings.wrappedValue.agentSoundEnabled)
        Toggle("Prompt submit", isOn: $appSettings.wrappedValue.agentSoundPromptSubmit)
            .disabled(!appSettings.wrappedValue.agentSoundEnabled)
        Toggle("Boot", isOn: $appSettings.wrappedValue.agentSoundBoot)
            .disabled(!appSettings.wrappedValue.agentSoundEnabled)
    }
    .padding(6)
}
```

- [ ] **Step 3: Build**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -configuration Debug -destination 'platform=macOS' build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head
```

- [ ] **Step 4: Commit**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
git add AiyuTerm/UI/Sheets/SettingsSheet.swift
git commit -m "feat(settings): surface 19 Phase 11.3 keys in SettingsSheet [P11.3.3]

Adds three new GroupBox sections (Notch Layout, Mascots, Sounds)
inside the existing notch panel gate. All 19 keys from Phase
11.3.2 now have a UI binding: Sliders for ranges (horizontal
offset, sound volume), Steppers for integer ranges, Pickers
for enums (display choice, session grouping, mascot speed),
and Toggles for booleans. Sound section is disabled when the
master agentSoundEnabled is off."
```

---

# Phase 11.4 — Complete AgentSoundManager (5-Entry Table + Per-Event Toggles + Volume)

## Task 11.4.1: Write failing test for entry table

**Files:**
- Test: `Tests/AgentSoundManagerTableTests.swift` (create)

- [ ] **Step 1: Write the test**

```swift
//
// AgentSoundManagerTableTests.swift
// AiyuTermTests
//
// Phase 11.4: AgentSoundManager must expose a full 5-entry
// table mapping hook event names to system sound names + per-
// event toggle key paths. Read/play flow must honor the master
// gate, per-event toggles, and volume setting.
//

import Foundation
import XCTest
@testable import AiyuTerm

final class AgentSoundManagerTableTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Reset to a known state so tests are independent.
        AgentSoundManager.updateSettings(AppSettings())
    }

    func testAllEntriesCoverFivePlusBoot() {
        XCTAssertEqual(AgentSoundManager.allEntries.count, 5)
        let names = Set(AgentSoundManager.allEntries.map(\.eventName))
        XCTAssertTrue(names.contains("SessionStart"))
        XCTAssertTrue(names.contains("Stop"))
        XCTAssertTrue(names.contains("PostToolUseFailure"))
        XCTAssertTrue(names.contains("PermissionRequest"))
        XCTAssertTrue(names.contains("UserPromptSubmit"))
    }

    func testEachEntryHasNonEmptyFields() {
        for entry in AgentSoundManager.allEntries {
            XCTAssertFalse(entry.eventName.isEmpty)
            XCTAssertFalse(entry.systemSoundName.isEmpty)
            XCTAssertFalse(entry.userFacingLabel.isEmpty)
        }
    }

    func testPlayWhenMasterDisabledIsNoOp() {
        var settings = AppSettings()
        settings.agentSoundEnabled = false
        AgentSoundManager.updateSettings(settings)
        // Should not crash and return fast.
        AgentSoundManager.play("Stop")
    }

    func testPlayWhenEventToggleOffIsNoOp() {
        var settings = AppSettings()
        settings.agentSoundEnabled = true
        settings.agentSoundTaskComplete = false
        AgentSoundManager.updateSettings(settings)
        AgentSoundManager.play("Stop")
    }

    func testPlayBootHonoursBootToggle() {
        var settings = AppSettings()
        settings.agentSoundEnabled = true
        settings.agentSoundBoot = false
        AgentSoundManager.updateSettings(settings)
        AgentSoundManager.playBoot()
    }

    func testUpdateSettingsPropagatesGate() {
        var settings = AppSettings()
        settings.agentSoundEnabled = false
        AgentSoundManager.updateSettings(settings)
        XCTAssertFalse(AgentSoundManager.isEnabled)

        settings.agentSoundEnabled = true
        AgentSoundManager.updateSettings(settings)
        XCTAssertTrue(AgentSoundManager.isEnabled)
    }
}
```

- [ ] **Step 2: Run test, expect compile fail**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -destination 'platform=macOS' test -only-testing:AiyuTermTests/AgentSoundManagerTableTests 2>&1 | grep -E "error:" | head
```

Expected: `allEntries` and `playBoot` undefined (Phase 10.2 only added `play` and `isEnabled`).

## Task 11.4.2: Add the entry table + playBoot + volume

**Files:**
- Modify: `AiyuTerm/Services/Agent/Sound/AgentSoundManager.swift`

- [ ] **Step 1: Add the entry struct and table**

Open `AgentSoundManager.swift` and add at the top inside the enum:

```swift
struct Entry: Sendable {
    let eventName: String
    let systemSoundName: String
    let toggleKeyPath: WritableKeyPath<AppSettings, Bool>
    let userFacingLabel: String
}

static let allEntries: [Entry] = [
    Entry(
        eventName: "SessionStart",
        systemSoundName: "Glass",
        toggleKeyPath: \.agentSoundSessionStart,
        userFacingLabel: "Session start"
    ),
    Entry(
        eventName: "Stop",
        systemSoundName: "Hero",
        toggleKeyPath: \.agentSoundTaskComplete,
        userFacingLabel: "Task complete"
    ),
    Entry(
        eventName: "PostToolUseFailure",
        systemSoundName: "Basso",
        toggleKeyPath: \.agentSoundTaskError,
        userFacingLabel: "Task error"
    ),
    Entry(
        eventName: "PermissionRequest",
        systemSoundName: "Funk",
        toggleKeyPath: \.agentSoundApprovalNeeded,
        userFacingLabel: "Permission request"
    ),
    Entry(
        eventName: "UserPromptSubmit",
        systemSoundName: "Tink",
        toggleKeyPath: \.agentSoundPromptSubmit,
        userFacingLabel: "Prompt submit"
    ),
]
```

- [ ] **Step 2: Update `play(_:)` to honor per-event toggle + volume**

Replace the existing body of `play(_:)` with:

```swift
static func play(_ eventName: String) {
    guard isEnabled else { return }
    guard let entry = allEntries.first(where: { $0.eventName == eventName }) else { return }
    guard let settings = currentSettings else { return }
    guard settings[keyPath: entry.toggleKeyPath] else { return }
    guard let sound = NSSound(named: NSSound.Name(entry.systemSoundName)) else { return }
    sound.volume = Float(settings.agentSoundVolume)
    sound.play()
}

static func playBoot() {
    guard isEnabled else { return }
    guard let settings = currentSettings, settings.agentSoundBoot else { return }
    guard let sound = NSSound(named: NSSound.Name("Submarine")) else { return }
    sound.volume = Float(settings.agentSoundVolume)
    sound.play()
}
```

- [ ] **Step 3: Update `updateSettings` to write `currentSettings`**

```swift
nonisolated(unsafe) static var isEnabled: Bool = true
nonisolated(unsafe) static var currentSettings: AppSettings?

static func updateSettings(_ s: AppSettings) {
    isEnabled = s.agentSoundEnabled
    currentSettings = s
}
```

- [ ] **Step 4: Run test, expect all pass**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -destination 'platform=macOS' test -only-testing:AiyuTermTests/AgentSoundManagerTableTests 2>&1 | grep -cE "^Test case .* passed"
```

Expected: `6`.

- [ ] **Step 5: Run Phase 10 sound tests to verify no regression**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -destination 'platform=macOS' test -only-testing:AiyuTermTests/AgentSoundManagerTests 2>&1 | grep -cE "^Test case .* passed"
```

Expected: `7` (preserved).

- [ ] **Step 6: Commit**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
git add AiyuTerm/Services/Agent/Sound/AgentSoundManager.swift Tests/AgentSoundManagerTableTests.swift
git commit -m "feat(sound): full 5-entry table + playBoot + volume control [P11.4.2]

Completes AgentSoundManager parity with upstream:
- AgentSoundManager.Entry struct (eventName / systemSoundName /
  toggleKeyPath / userFacingLabel)
- allEntries table covering SessionStart / Stop /
  PostToolUseFailure / PermissionRequest / UserPromptSubmit
- play(_:) now reads the per-event toggle via WritableKeyPath<AppSettings, Bool>
  and honors agentSoundVolume via NSSound.volume
- playBoot() plays Submarine gated on agentSoundBoot
- currentSettings static cache is updated via updateSettings(_:)

New tests: AgentSoundManagerTableTests (6 cases). Preserves all
7 existing AgentSoundManagerTests cases."
```

## Task 11.4.3: Wire playBoot on app startup

**Files:**
- Modify: `AiyuTerm/App/WorkspaceStore.swift` (`loadIfNeeded`) or `AiyuTerm/AppDelegate.swift` (`applicationDidFinishLaunching`)

- [ ] **Step 1: Find an appropriate hook**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
grep -n "applicationDidFinishLaunching\|loadIfNeeded" AiyuTerm/AppDelegate.swift AiyuTerm/App/WorkspaceStore.swift | head
```

- [ ] **Step 2: Add `AgentSoundManager.playBoot()` after settings update**

Find the line in `WorkspaceStore.loadIfNeeded` that calls `AgentSoundManager.updateSettings(appSettings)` (added in Phase 10.2). Right after it, add:

```swift
AgentSoundManager.playBoot()
```

- [ ] **Step 3: Build**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -configuration Debug -destination 'platform=macOS' build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head
```

- [ ] **Step 4: Commit**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
git add AiyuTerm/App/WorkspaceStore.swift
git commit -m "feat(sound): play boot sound on WorkspaceStore initial load [P11.4.3]"
```

---

# Phase 11.5 — Complete PixelKit Sub-Component Extraction (14 New Files)

The `phase11/pixel-kit` Wave 3C agent committed 4 standalone files. The 14 sub-components extracted from upstream `NotchPanelView.swift` are still pending.

For each of the 14 components below, follow a uniform 4-step pattern:
1. Read the upstream source lines
2. Port to `AiyuTerm/UI/NotchPanel/PixelKit/Agent<Name>.swift` with rename rules
3. Add one smoke test to `Tests/AgentPixelKitSmokeTests.swift`
4. Build verify

Since all 14 follow the same pattern, the plan lists the exact tasks in compact form.

## Task 11.5.0: Create `Tests/AgentPixelKitSmokeTests.swift` with shell

- [ ] **Step 1: Write shell**

```swift
//
// AgentPixelKitSmokeTests.swift
// AiyuTermTests
//
// Phase 11.5: smoke tests for every extracted pixel-kit
// sub-component. Each test instantiates the view type with
// sensible defaults and forces body evaluation. The goal is
// to catch compile regressions and runtime crashes; visual
// fidelity is verified by the manual verification guide.
//

import Foundation
import SwiftUI
import XCTest
@testable import AiyuTerm

final class AgentPixelKitSmokeTests: XCTestCase {
    // Tests added incrementally in Phase 11.5.1 .. 11.5.14
}
```

- [ ] **Step 2: Build + run empty test suite (should pass trivially)**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -destination 'platform=macOS' test -only-testing:AiyuTermTests/AgentPixelKitSmokeTests 2>&1 | grep -E "BUILD|Test Suite" | head
```

- [ ] **Step 3: Commit shell**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
git add Tests/AgentPixelKitSmokeTests.swift
git commit -m "test(pixelkit): add smoke test shell for Phase 11.5 extractions [P11.5.0]"
```

## Tasks 11.5.1 – 11.5.14: Extract 14 sub-components from NotchPanelView.swift

Each task below has its own 5-step block. **DO NOT** collapse into a template — every task must be actionable standalone.

**Shared rename rules applied to every port (apply inline during Step 2):**
- `private struct PixelText` → `struct AgentPixelText`
- `private struct ClaudeLogoShape` → `struct AgentClaudeLogoShape`
- `private struct MiniAgentIcon` → `struct AgentMiniAgentIcon`
- `SessionSnapshot` type reference → `AgentSessionSnapshot`
- `AgentStatus` type reference → `AgentSessionStatus`
- `@Environment(\.mascotSpeed)` → `@Environment(\.agentMascotSpeed)`
- `AppState.shared.sessions[...]` references → accept the snapshot as a constructor parameter instead
- `SettingsKey.*` references → inline the literal value from our `AppSettings` defaults
- Upstream uses `L10n.shared["..."]` → inline the English string as a literal + leave a `// TODO(L10n 11.8):` comment

### Task 11.5.1: Extract `AgentPixelText` + `Line: Shape`

**Files:**
- Read upstream: `/tmp/codeisland-research/Sources/CodeIsland/NotchPanelView.swift` lines 1736-1822
- Create: `AiyuTerm/UI/NotchPanel/PixelKit/AgentPixelText.swift`
- Modify: `Tests/AgentPixelKitSmokeTests.swift` (append 1 test method)

- [ ] **Step 1: Read the upstream source**

```bash
sed -n '1736,1822p' /tmp/codeisland-research/Sources/CodeIsland/NotchPanelView.swift
```

- [ ] **Step 2: Create `AgentPixelText.swift`**

Copy the upstream `private struct PixelText` and `private struct Line: Shape` verbatim into a new file, dropping `private`, adding `Agent` prefix, and adding the AiyuTerm adaptation header. No logic changes.

- [ ] **Step 3: Append a smoke test to `AgentPixelKitSmokeTests.swift`**

```swift
func testAgentPixelTextConstructs() {
    let view = AgentPixelText(text: "HELLO", size: 8, color: .white)
    _ = AnyView(view.body)
}
```

(If the upstream struct has different parameters, adapt to match — the goal is any valid construction.)

- [ ] **Step 4: Build + run smoke test**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -configuration Debug -destination 'platform=macOS' build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -destination 'platform=macOS' test -only-testing:AiyuTermTests/AgentPixelKitSmokeTests/testAgentPixelTextConstructs 2>&1 | grep -E "^Test case" | head
```

- [ ] **Step 5: Commit**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
git add AiyuTerm/UI/NotchPanel/PixelKit/AgentPixelText.swift Tests/AgentPixelKitSmokeTests.swift
git commit -m "feat(pixelkit): extract AgentPixelText + Line shape [P11.5.1]

Ports upstream NotchPanelView.swift lines 1736-1822."
```

### Task 11.5.2: Extract `AgentClaudeLogoShape` + `AgentClaudeLogo`

**Files:**
- Read upstream: `/tmp/codeisland-research/Sources/CodeIsland/NotchPanelView.swift` lines 1511-1629
- Create: `AiyuTerm/UI/NotchPanel/PixelKit/AgentClaudeLogoShape.swift`
- Modify: `Tests/AgentPixelKitSmokeTests.swift`

- [ ] **Step 1: Read the upstream source**

```bash
sed -n '1511,1629p' /tmp/codeisland-research/Sources/CodeIsland/NotchPanelView.swift
```

- [ ] **Step 2: Create `AgentClaudeLogoShape.swift`**

Port both `ClaudeLogo` (wrapper view) and `ClaudeLogoShape: Shape` (the actual sunburst geometry) into one file. Keep every coordinate and `path.move(to:)` / `addCurve(to:)` call identical — the geometry is the whole point.

- [ ] **Step 3: Append smoke test**

```swift
func testAgentClaudeLogoShapeConstructs() {
    let shape = AgentClaudeLogoShape()
    _ = shape.path(in: CGRect(x: 0, y: 0, width: 24, height: 24))
    let wrapper = AgentClaudeLogo(size: 24)
    _ = AnyView(wrapper.body)
}
```

- [ ] **Step 4: Build + test**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -configuration Debug -destination 'platform=macOS' build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -destination 'platform=macOS' test -only-testing:AiyuTermTests/AgentPixelKitSmokeTests/testAgentClaudeLogoShapeConstructs 2>&1 | grep -E "^Test case" | head
```

- [ ] **Step 5: Commit**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
git add AiyuTerm/UI/NotchPanel/PixelKit/AgentClaudeLogoShape.swift Tests/AgentPixelKitSmokeTests.swift
git commit -m "feat(pixelkit): extract AgentClaudeLogoShape + AgentClaudeLogo [P11.5.2]

Ports upstream NotchPanelView.swift lines 1511-1629."
```

### Task 11.5.3: Extract `AgentMiniAgentIcon`

**Files:**
- Read upstream: `/tmp/codeisland-research/Sources/CodeIsland/NotchPanelView.swift` lines 1928-1974
- Create: `AiyuTerm/UI/NotchPanel/PixelKit/AgentMiniAgentIcon.swift`
- Modify: `Tests/AgentPixelKitSmokeTests.swift`

- [ ] **Step 1:** `sed -n '1928,1974p' /tmp/codeisland-research/Sources/CodeIsland/NotchPanelView.swift`
- [ ] **Step 2:** Port `MiniAgentIcon` to `AgentMiniAgentIcon`, preserving the 8-bit robot head shapes.
- [ ] **Step 3:** Append `testAgentMiniAgentIconConstructs()` that constructs `AgentMiniAgentIcon(size: 12)` and forces body eval.
- [ ] **Step 4:** Build + run `-only-testing:AiyuTermTests/AgentPixelKitSmokeTests/testAgentMiniAgentIconConstructs`.
- [ ] **Step 5:** `git add AiyuTerm/UI/NotchPanel/PixelKit/AgentMiniAgentIcon.swift Tests/AgentPixelKitSmokeTests.swift && git commit -m "feat(pixelkit): extract AgentMiniAgentIcon [P11.5.3]"`

### Task 11.5.4: Extract `AgentTypingIndicator`

**Files:**
- Read: lines 1875-1925 of upstream `NotchPanelView.swift`
- Create: `AiyuTerm/UI/NotchPanel/PixelKit/AgentTypingIndicator.swift`
- Modify: `Tests/AgentPixelKitSmokeTests.swift`

- [ ] **Step 1:** `sed -n '1875,1925p' /tmp/codeisland-research/Sources/CodeIsland/NotchPanelView.swift`
- [ ] **Step 2:** Port the three-bouncing-dots animation. Preserve the `@State` animation phase and timing.
- [ ] **Step 3:** Append `testAgentTypingIndicatorConstructs()` constructing with defaults.
- [ ] **Step 4:** Build + run the smoke test.
- [ ] **Step 5:** `git add ... && git commit -m "feat(pixelkit): extract AgentTypingIndicator [P11.5.4]"`

### Task 11.5.5: Extract `AgentSessionTag`

**Files:**
- Read: lines 1851-1872 of upstream `NotchPanelView.swift`
- Create: `AiyuTerm/UI/NotchPanel/PixelKit/AgentSessionTag.swift`
- Modify: `Tests/AgentPixelKitSmokeTests.swift`

- [ ] **Step 1:** `sed -n '1851,1872p' /tmp/codeisland-research/Sources/CodeIsland/NotchPanelView.swift`
- [ ] **Step 2:** Port `SessionTag` (a small colored pill). Replace any `SessionSnapshot` reference with `AgentSessionSnapshot`.
- [ ] **Step 3:** Append `testAgentSessionTagConstructs()` that constructs with `text: "CLAUDE"`, `color: .orange`.
- [ ] **Step 4:** Build + test.
- [ ] **Step 5:** `git commit -m "feat(pixelkit): extract AgentSessionTag [P11.5.5]"`

### Task 11.5.6: Extract `AgentTerminalBadge`

**Files:**
- Read: lines 1694-1733 of upstream `NotchPanelView.swift`
- Create: `AiyuTerm/UI/NotchPanel/PixelKit/AgentTerminalBadge.swift`

- [ ] **Step 1:** `sed -n '1694,1733p' /tmp/codeisland-research/Sources/CodeIsland/NotchPanelView.swift`
- [ ] **Step 2:** Port `TerminalBadge` (small icon + label). If it uses `TERM_PROGRAM` lookups, inline a simple dispatch using our `AgentTerminalActivatorHelpers.canonicalAppName`.
- [ ] **Step 3:** Append `testAgentTerminalBadgeConstructs()`.
- [ ] **Step 4:** Build + test.
- [ ] **Step 5:** `git commit -m "feat(pixelkit): extract AgentTerminalBadge [P11.5.6]"`

### Task 11.5.7: Extract `AgentPixelButton`

**Files:**
- Read: lines 1028-1056 of upstream `NotchPanelView.swift`
- Create: `AiyuTerm/UI/NotchPanel/PixelKit/AgentPixelButton.swift`

- [ ] **Step 1:** `sed -n '1028,1056p' /tmp/codeisland-research/Sources/CodeIsland/NotchPanelView.swift`
- [ ] **Step 2:** Port `PixelButton` — a Button style with a pixelated border. Preserve hover + pressed states.
- [ ] **Step 3:** Append `testAgentPixelButtonConstructs()` that builds `Button("Test") {}.buttonStyle(AgentPixelButton())`.
- [ ] **Step 4:** Build + test.
- [ ] **Step 5:** `git commit -m "feat(pixelkit): extract AgentPixelButton [P11.5.7]"`

### Task 11.5.8: Extract `AgentIdleIndicatorBar`

**Files:**
- Read: lines 567-617 of upstream `NotchPanelView.swift`
- Create: `AiyuTerm/UI/NotchPanel/PixelKit/AgentIdleIndicatorBar.swift`

- [ ] **Step 1:** `sed -n '567,617p' /tmp/codeisland-research/Sources/CodeIsland/NotchPanelView.swift`
- [ ] **Step 2:** Port `IdleIndicatorBar` — the moon-phases / breathing animation shown when the panel is idle. Any `AppState` reference becomes a constructor parameter.
- [ ] **Step 3:** Append `testAgentIdleIndicatorBarConstructs()`.
- [ ] **Step 4:** Build + test.
- [ ] **Step 5:** `git commit -m "feat(pixelkit): extract AgentIdleIndicatorBar [P11.5.8]"`

### Task 11.5.9: Extract `AgentNotchIconButton`

**Files:**
- Read: lines 541-566 of upstream `NotchPanelView.swift`
- Create: `AiyuTerm/UI/NotchPanel/PixelKit/AgentNotchIconButton.swift`

- [ ] **Step 1:** `sed -n '541,566p' /tmp/codeisland-research/Sources/CodeIsland/NotchPanelView.swift`
- [ ] **Step 2:** Port `NotchIconButton` — icon-only tap target.
- [ ] **Step 3:** Append `testAgentNotchIconButtonConstructs()`.
- [ ] **Step 4:** Build + test.
- [ ] **Step 5:** `git commit -m "feat(pixelkit): extract AgentNotchIconButton [P11.5.9]"`

### Task 11.5.10: Extract `AgentCompactToolStatus`

**Files:**
- Read: lines 443-540 of upstream `NotchPanelView.swift`
- Create: `AiyuTerm/UI/NotchPanel/PixelKit/AgentCompactToolStatus.swift`

- [ ] **Step 1:** `sed -n '443,540p' /tmp/codeisland-research/Sources/CodeIsland/NotchPanelView.swift`
- [ ] **Step 2:** Port `CompactToolStatus`. This references upstream tool-status helpers (at lines 425-438) — inline those helpers at the top of the new file as private free functions.
- [ ] **Step 3:** Append `testAgentCompactToolStatusConstructs()` with a minimal snapshot.
- [ ] **Step 4:** Build + test.
- [ ] **Step 5:** `git commit -m "feat(pixelkit): extract AgentCompactToolStatus [P11.5.10]"`

### Task 11.5.11: Extract `AgentCompactWings` (left + right)

**Files:**
- Read: lines 263-424 of upstream `NotchPanelView.swift`
- Create: `AiyuTerm/UI/NotchPanel/PixelKit/AgentCompactWings.swift`

- [ ] **Step 1:** `sed -n '263,424p' /tmp/codeisland-research/Sources/CodeIsland/NotchPanelView.swift`
- [ ] **Step 2:** Port both `CompactLeftWing` and `CompactRightWing` into ONE file. They share state. Preserve the notch-level 32px height layout.
- [ ] **Step 3:** Append TWO smoke tests: `testAgentCompactLeftWingConstructs` and `testAgentCompactRightWingConstructs`.
- [ ] **Step 4:** Build + test.
- [ ] **Step 5:** `git commit -m "feat(pixelkit): extract AgentCompactLeftWing + AgentCompactRightWing [P11.5.11]"`

### Task 11.5.12: Extract `AgentThinScrollView` (NSViewRepresentable)

**Files:**
- Read: lines 1193-1227 of upstream `NotchPanelView.swift`
- Create: `AiyuTerm/UI/NotchPanel/PixelKit/AgentThinScrollView.swift`

- [ ] **Step 1:** `sed -n '1193,1227p' /tmp/codeisland-research/Sources/CodeIsland/NotchPanelView.swift`
- [ ] **Step 2:** Port `ThinScrollView<Content: View>: NSViewRepresentable`. This is AppKit wiring — keep coordinator + `makeNSView` + `updateNSView` exactly.
- [ ] **Step 3:** Append `testAgentThinScrollViewConstructs()` that builds `AgentThinScrollView { Text("x") }` and force-evaluates.
- [ ] **Step 4:** Build + test.
- [ ] **Step 5:** `git commit -m "feat(pixelkit): extract AgentThinScrollView [P11.5.12]"`

### Task 11.5.13: Extract `AgentSessionListView` + `AgentSessionIdentityLine` + `AgentProjectNameLink` + `AgentSessionsExpandLink`

**Files:**
- Read: lines 1057-1326 of upstream `NotchPanelView.swift`
- Create: `AiyuTerm/UI/NotchPanel/PixelKit/AgentSessionListView.swift`
- Create: `AiyuTerm/UI/NotchPanel/PixelKit/AgentSessionIdentityLine.swift`

- [ ] **Step 1:** `sed -n '1057,1326p' /tmp/codeisland-research/Sources/CodeIsland/NotchPanelView.swift`
- [ ] **Step 2:** Port `SessionListView` into `AgentSessionListView.swift`. Port `SessionIdentityLine` + `ProjectNameLink` + `SessionsExpandLink` into `AgentSessionIdentityLine.swift` (they share helpers). Upstream `SessionListView` iterates `AppState.shared.sessions` — replace with a constructor parameter `let sessions: [AgentSessionSnapshot]`.
- [ ] **Step 3:** Append TWO smoke tests: `testAgentSessionListViewConstructs` (with empty session array) and `testAgentSessionIdentityLineConstructs`.
- [ ] **Step 4:** Build + test both.
- [ ] **Step 5:** `git commit -m "feat(pixelkit): extract AgentSessionListView + AgentSessionIdentityLine [P11.5.13]"`

### Task 11.5.14: Extract `AgentSessionCardLegacy`

**Files:**
- Read: lines 1327-1510 of upstream `NotchPanelView.swift`
- Create: `AiyuTerm/UI/NotchPanel/PixelKit/AgentSessionCardLegacy.swift`

- [ ] **Step 1:** `sed -n '1327,1510p' /tmp/codeisland-research/Sources/CodeIsland/NotchPanelView.swift`
- [ ] **Step 2:** Port upstream `SessionCard`. Rename to `AgentSessionCardLegacy` (because our Phase 10.3 `SessionCardView` in `AgentNotchPanelView.swift` already uses the simpler name). Keep for future reference + if someone wants the upstream layout.
- [ ] **Step 3:** Append `testAgentSessionCardLegacyConstructs()` using a minimal `AgentSessionSnapshot`.
- [ ] **Step 4:** Build + test.
- [ ] **Step 5:** `git commit -m "feat(pixelkit): extract AgentSessionCardLegacy [P11.5.14]"`

## Task 11.5.15: Full smoke-test sweep

- [ ] **Step 1: Run the entire pixel kit smoke test suite**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -destination 'platform=macOS' test -only-testing:AiyuTermTests/AgentPixelKitSmokeTests 2>&1 | grep -cE "^Test case .* passed"
```

Expected: at least `16` (14 extracted + 2 bonus from 11.5.11 and 11.5.13).

- [ ] **Step 2: Full project build**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -3
```

---

# Phase 11.6 — Complete Controller-Side Reactive Wiring

The `phase11/controller-reactive` Wave 3D agent committed `AgentStatusItemController.swift` but did not implement the reactive notch panel behavior (fullscreen / mouseLeave / hideWhenNoSession).

## Task 11.6.1: Write failing tests for reactive behavior

**Files:**
- Test: `Tests/AgentNotchControllerReactivityTests.swift` (create)

- [ ] **Step 1: Write the test file**

```swift
//
// AgentNotchControllerReactivityTests.swift
// AiyuTermTests
//
// Phase 11.6: verify the notch panel controller reacts to the
// hideInFullscreen / collapseOnMouseLeave / hideWhenNoSession
// settings. These tests use the pure decision functions and
// notification posting; NSPanel show/hide is exercised by the
// manual verification guide.
//

import AppKit
import Foundation
import XCTest
@testable import AiyuTerm

final class AgentNotchControllerReactivityTests: XCTestCase {

    // MARK: - Pure decision helpers

    func testShouldHideInFullscreenWhenEnabled() {
        XCTAssertTrue(
            AgentNotchPanelController.shouldHideForFullscreen(
                isFullscreen: true,
                hideInFullscreen: true
            )
        )
    }

    func testShouldNotHideInFullscreenWhenDisabled() {
        XCTAssertFalse(
            AgentNotchPanelController.shouldHideForFullscreen(
                isFullscreen: true,
                hideInFullscreen: false
            )
        )
    }

    func testShouldNotHideInFullscreenWhenNotFullscreen() {
        XCTAssertFalse(
            AgentNotchPanelController.shouldHideForFullscreen(
                isFullscreen: false,
                hideInFullscreen: true
            )
        )
    }

    func testShouldHideWhenNoSessionAndEnabled() {
        XCTAssertTrue(
            AgentNotchPanelController.shouldHideForNoSession(
                hasAnyActivity: false,
                hideWhenNoSession: true
            )
        )
    }

    func testShouldNotHideWhenSessionExists() {
        XCTAssertFalse(
            AgentNotchPanelController.shouldHideForNoSession(
                hasAnyActivity: true,
                hideWhenNoSession: true
            )
        )
    }

    func testShouldNotHideWhenDisabled() {
        XCTAssertFalse(
            AgentNotchPanelController.shouldHideForNoSession(
                hasAnyActivity: false,
                hideWhenNoSession: false
            )
        )
    }

    // MARK: - Collapse notification

    func testCollapseNotificationName() {
        XCTAssertEqual(
            AgentNotchPanelController.collapseRequestedNotification.rawValue,
            "AgentNotchPanelCollapseRequested"
        )
    }
}
```

- [ ] **Step 2: Run test, expect compile fail**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -destination 'platform=macOS' test -only-testing:AiyuTermTests/AgentNotchControllerReactivityTests 2>&1 | grep -E "error:" | head
```

Expected: undefined methods.

## Task 11.6.2: Implement the 3 reactive behaviors

**Files:**
- Modify: `AiyuTerm/UI/NotchPanel/AgentNotchPanelController.swift`

- [ ] **Step 1: Add decision helpers and notification name**

Near the top of the controller class, add:

```swift
// MARK: - Phase 11.6 reactive decisions

static let collapseRequestedNotification = Notification.Name("AgentNotchPanelCollapseRequested")

/// Pure decision: should the panel be hidden because an app
/// has entered fullscreen and the user opted in?
static func shouldHideForFullscreen(
    isFullscreen: Bool,
    hideInFullscreen: Bool
) -> Bool {
    isFullscreen && hideInFullscreen
}

/// Pure decision: should the panel be hidden because there is
/// no agent activity and the user opted in?
static func shouldHideForNoSession(
    hasAnyActivity: Bool,
    hideWhenNoSession: Bool
) -> Bool {
    !hasAnyActivity && hideWhenNoSession
}
```

- [ ] **Step 2: Add `setDisplayOptions(_:)` and fullscreen observer**

```swift
// Phase 11.6: reactive settings
private var currentDisplayOptions: AgentNotchDisplayOptions = .default
private var fullscreenObserver: NSObjectProtocol?
private var trackingArea: NSTrackingArea?

func setDisplayOptions(_ opts: AgentNotchDisplayOptions) {
    currentDisplayOptions = opts
    applyReactiveVisibility()
    installFullscreenObserverIfNeeded(enabled: opts.hideInFullscreen)
    installMouseTrackingIfNeeded(enabled: opts.collapseOnMouseLeave)
}

private func installFullscreenObserverIfNeeded(enabled: Bool) {
    if enabled, fullscreenObserver == nil {
        fullscreenObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyReactiveVisibility()
        }
    } else if !enabled, let token = fullscreenObserver {
        NSWorkspace.shared.notificationCenter.removeObserver(token)
        fullscreenObserver = nil
    }
}

private var isAnyAppFullscreen: Bool {
    guard let screen = NSScreen.main else { return false }
    // When a window is fullscreen, the menu bar is hidden, so
    // visibleFrame equals frame. This is the safest cross-
    // version detection.
    return screen.visibleFrame == screen.frame
}

private func applyReactiveVisibility() {
    let hideForFullscreen = Self.shouldHideForFullscreen(
        isFullscreen: isAnyAppFullscreen,
        hideInFullscreen: currentDisplayOptions.hideInFullscreen
    )
    // hasAnyActivity requires the current view state — posting
    // a notification for the VM to answer is overkill; instead,
    // the WorkspaceStore calls this method AFTER updating the
    // view state, so we can read a stored flag.
    let hideForNoSession = Self.shouldHideForNoSession(
        hasAnyActivity: lastKnownHasActivity,
        hideWhenNoSession: currentDisplayOptions.hideWhenNoSession
    )

    if hideForFullscreen || hideForNoSession {
        panel?.orderOut(nil)
    } else if shouldBeVisible {
        panel?.orderFront(nil)
    }
}

var lastKnownHasActivity: Bool = false
var shouldBeVisible: Bool = false
```

- [ ] **Step 3: Add `installMouseTrackingIfNeeded` using an inner NSView tracker**

**IMPORTANT**: `AgentNotchPanelController` inherits from `NSObject`, not `NSResponder`, so we cannot override `mouseExited(with:)` on the controller itself. Instead, add a private inner NSView subclass that owns the tracking area and posts the collapse notification when the mouse exits.

At the bottom of `AgentNotchPanelController.swift` (outside the main class but in the same file), add:

```swift
/// Phase 11.6: private NSView subclass that owns the mouse
/// tracking area so the controller (an NSObject) can react
/// to cursor exits without inheriting from NSResponder.
private final class AgentNotchPanelMouseTrackerView: NSView {
    var onMouseExited: (() -> Void)?
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onMouseExited?()
    }
}
```

Then inside the controller class add the install helper that injects the tracker view into the panel's content view hierarchy:

```swift
private var mouseTrackerView: AgentNotchPanelMouseTrackerView?

private func installMouseTrackingIfNeeded(enabled: Bool) {
    guard let panelContentView = panel?.contentView else { return }
    if let existing = mouseTrackerView {
        existing.removeFromSuperview()
        mouseTrackerView = nil
    }
    guard enabled else { return }
    let tracker = AgentNotchPanelMouseTrackerView(frame: panelContentView.bounds)
    tracker.autoresizingMask = [.width, .height]
    tracker.onMouseExited = { [weak self] in
        guard let self = self,
              self.currentDisplayOptions.collapseOnMouseLeave else { return }
        NotificationCenter.default.post(
            name: Self.collapseRequestedNotification,
            object: self
        )
    }
    panelContentView.addSubview(tracker, positioned: .below, relativeTo: nil)
    mouseTrackerView = tracker
}
```

The tracker is a transparent NSView placed BELOW all other subviews (so it doesn't intercept clicks — only uses its tracking area to detect exits).

- [ ] **Step 4: Run the test, expect pass**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -destination 'platform=macOS' test -only-testing:AiyuTermTests/AgentNotchControllerReactivityTests 2>&1 | grep -cE "^Test case .* passed"
```

Expected: `7`.

- [ ] **Step 5: Commit**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
git add AiyuTerm/UI/NotchPanel/AgentNotchPanelController.swift Tests/AgentNotchControllerReactivityTests.swift
git commit -m "feat(notch): reactive fullscreen / mouseLeave / noSession behavior [P11.6.2]"
```

## Task 11.6.3: Call `setDisplayOptions` from WorkspaceStore

**Files:**
- Modify: `AiyuTerm/App/WorkspaceStore.swift`

- [ ] **Step 1: Find `refreshNotchPanelState`**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
grep -n "refreshNotchPanelState\|currentNotchViewState" AiyuTerm/App/WorkspaceStore.swift | head
```

- [ ] **Step 2: After updating the view model, propagate display options to the controller**

```swift
func refreshNotchPanelState() {
    guard let viewModel = agentNotchPanelViewModel else { return }
    let state = currentNotchViewState()
    viewModel.update(state: state)
    if let controller = agentNotchPanelController {
        controller.lastKnownHasActivity = state.hasAnyActivity
        controller.setDisplayOptions(state.display)
    }
}
```

- [ ] **Step 3: Build + run notch tests**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -configuration Debug -destination 'platform=macOS' build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head
```

- [ ] **Step 4: Commit**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
git add AiyuTerm/App/WorkspaceStore.swift
git commit -m "feat(notch): propagate display options from store to controller [P11.6.3]"
```

---

# Phase 11.7 — Port Upstream Test Parity (4 Files)

## Task 11.7.1: AgentCodexTranscriptTests

**Files:**
- Read upstream: `/tmp/codeisland-research/Tests/CodeIslandTests/AppStateCodexTranscriptTests.swift`
- Create: `Tests/AgentCodexTranscriptTests.swift`

- [ ] **Step 1: Read upstream + understand what it tests**

```bash
cat /tmp/codeisland-research/Tests/CodeIslandTests/AppStateCodexTranscriptTests.swift
```

- [ ] **Step 2: Port tests one-by-one, renaming types and fixing compile errors**

For each test function, rename:
- `AppState` → direct reducer calls (`mutateSession(with:sessions:)` from our reducer)
- `SessionSnapshot` → `AgentSessionSnapshot`
- `AgentStatus` → `AgentSessionStatus` (with upstream → our mapping)

Skip any test that references types we deliberately don't have, and document the skip with a `// SKIP(Phase 11.7.1): references AppState subscription` comment.

- [ ] **Step 3: Run**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -destination 'platform=macOS' test -only-testing:AiyuTermTests/AgentCodexTranscriptTests 2>&1 | grep -cE "^Test case .* passed"
```

- [ ] **Step 4: Commit**

```bash
git add Tests/AgentCodexTranscriptTests.swift
git commit -m "test(agent): port upstream Codex transcript reducer tests [P11.7.1]"
```

## Task 11.7.2: AgentSessionSnapshotTitleTests

**Files:**
- Read upstream: `/tmp/codeisland-research/Tests/CodeIslandCoreTests/SessionSnapshotTitleTests.swift`
- Create: `Tests/AgentSessionSnapshotTitleTests.swift`

- [ ] **Step 1: Read upstream tests**

```bash
cat /tmp/codeisland-research/Tests/CodeIslandCoreTests/SessionSnapshotTitleTests.swift
```

- [ ] **Step 2: Port each test method with renames**

For each `func test*()` in upstream, copy to our file and apply renames:
- `SessionSnapshot` → `AgentSessionSnapshot`
- `SessionTitleSource` → `AgentSessionTitleSource`
- `AgentStatus` → `AgentSessionStatus` (if referenced)
- Upstream `derivedTitle(...)` or equivalent → whatever our snapshot uses (`sessionTitle`, `sessionTitleSource`, or a computed property)

File shell:

```swift
//
// AgentSessionSnapshotTitleTests.swift
// AiyuTermTests
//
// Phase 11.7.2: parity tests ported from upstream CodeIsland
// SessionSnapshotTitleTests.swift. Verifies title resolution
// precedence (custom > ai > derived).
//

import Foundation
import XCTest
@testable import AiyuTerm

final class AgentSessionSnapshotTitleTests: XCTestCase {
    // Populate with ported methods from upstream
}
```

Any test that references a type we don't have gets a `// SKIP(11.7.2): upstream uses <type>` comment and is removed.

- [ ] **Step 3: Build + run**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -destination 'platform=macOS' test -only-testing:AiyuTermTests/AgentSessionSnapshotTitleTests 2>&1 | grep -cE "^Test case .* passed"
```

- [ ] **Step 4: Commit**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
git add Tests/AgentSessionSnapshotTitleTests.swift
git commit -m "test(agent): port upstream SessionSnapshot title tests [P11.7.2]"
```

## Task 11.7.3: AgentDerivedSessionStateTests

**Files:**
- Read upstream: `/tmp/codeisland-research/Tests/CodeIslandCoreTests/DerivedSessionStateTests.swift`
- Create: `Tests/AgentDerivedSessionStateTests.swift`

Upstream `derivedSessionState` is equivalent to our `deriveAgentSessionSummary` (grep for it in `AgentSessionSnapshot.swift`).

- [ ] **Step 1: Read upstream**

```bash
cat /tmp/codeisland-research/Tests/CodeIslandCoreTests/DerivedSessionStateTests.swift
```

- [ ] **Step 2: Identify the equivalent in our reducer**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
grep -n "deriveAgentSessionSummary\|derivedState" AiyuTerm/Services/Agent/HookProtocol/AgentSessionSnapshot.swift | head
```

- [ ] **Step 3: Port each test method**

For every `func test*` in upstream, write an equivalent that calls `deriveAgentSessionSummary(from:)` with a dict of snapshots. Test the returned `AgentSessionSummary` matches the expected status + source.

```swift
import Foundation
import XCTest
@testable import AiyuTerm

final class AgentDerivedSessionStateTests: XCTestCase {
    func testParity_idleSessionsYieldIdleSummary() {
        var s = AgentSessionSnapshot()
        s.status = .idle
        s.source = "claude"
        let summary = deriveAgentSessionSummary(from: ["sid-1": s])
        XCTAssertEqual(summary.primaryStatus, .idle)
        XCTAssertEqual(summary.primarySource, "claude")
    }

    // Add one method per upstream test, prefixed testParity_
}
```

- [ ] **Step 4: Build + run**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -destination 'platform=macOS' test -only-testing:AiyuTermTests/AgentDerivedSessionStateTests 2>&1 | grep -cE "^Test case .* passed"
```

- [ ] **Step 5: Commit**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
git add Tests/AgentDerivedSessionStateTests.swift
git commit -m "test(agent): port upstream DerivedSessionState tests [P11.7.3]"
```

## Task 11.7.4: AgentScreenDetectorParityTests

**Files:**
- Read upstream: `/tmp/codeisland-research/Tests/CodeIslandTests/ScreenDetectorTests.swift`
- Create: `Tests/AgentScreenDetectorParityTests.swift`

We already have `AgentNotchScreenDetectorTests` (12 tests). Port upstream cases we're missing.

- [ ] **Step 1: Read upstream tests**

```bash
cat /tmp/codeisland-research/Tests/CodeIslandTests/ScreenDetectorTests.swift
```

- [ ] **Step 2: List our current cases**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
grep -E "^    func test" Tests/AgentNotchScreenDetectorTests.swift
```

- [ ] **Step 3: Identify upstream cases we don't cover**

Compare the method lists. For each upstream method not covered, write a new test in `AgentScreenDetectorParityTests.swift` prefixed `testParity_` so names don't collide.

- [ ] **Step 4: Create the new file with missing cases**

```swift
import Foundation
import XCTest
@testable import AiyuTerm

final class AgentScreenDetectorParityTests: XCTestCase {
    // testParity_<upstream method name> for each ported case
}
```

- [ ] **Step 5: Build + run**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -destination 'platform=macOS' test -only-testing:AiyuTermTests/AgentScreenDetectorParityTests 2>&1 | grep -cE "^Test case .* passed"
```

- [ ] **Step 6: Commit**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
git add Tests/AgentScreenDetectorParityTests.swift
git commit -m "test(screen): port upstream ScreenDetector test parity cases [P11.7.4]"
```

---

# Phase 11.8 — L10n String Parity

## Task 11.8.1: Audit L10n gaps

- [ ] **Step 1: List upstream keys**

```bash
grep -oE "\"[a-zA-Z_]+\"" /tmp/codeisland-research/Sources/CodeIsland/L10n.swift | sort -u > /tmp/aiyu-l10n-upstream-keys.txt
wc -l /tmp/aiyu-l10n-upstream-keys.txt
```

- [ ] **Step 2: List our current keys**

```bash
grep -oE "\"[a-zA-Z_.]+\"" AiyuTerm/Support/L10n.swift | sort -u > /tmp/aiyu-l10n-ours.txt
wc -l /tmp/aiyu-l10n-ours.txt
```

- [ ] **Step 3: Compute the diff**

```bash
comm -23 /tmp/aiyu-l10n-upstream-keys.txt /tmp/aiyu-l10n-ours.txt > /tmp/aiyu-l10n-missing.txt
wc -l /tmp/aiyu-l10n-missing.txt
```

## Task 11.8.2: Port all missing L10n strings

**Files:**
- Modify: `AiyuTerm/Support/L10n.swift`
- Test: `Tests/L10nParityTests.swift` (create)

- [ ] **Step 1: Write parity test**

```swift
//
// L10nParityTests.swift
// AiyuTermTests
//
// Phase 11.8: verify every upstream CodeIsland L10n key has a
// translation in both English and Simplified Chinese.
//

import Foundation
import XCTest
@testable import AiyuTerm

final class L10nParityTests: XCTestCase {

    private static let expectedKeys: [String] = [
        // Populated from /tmp/aiyu-l10n-upstream-keys.txt
        // Phase 11.8.2 Step 1 seeds this list
    ]

    func testAllUpstreamKeysExistInEnglish() {
        for key in Self.expectedKeys {
            let v = L10n.localized(key, language: .english)
            XCTAssertFalse(v.isEmpty, "Missing English translation for key: \(key)")
            XCTAssertNotEqual(v, key, "Key not resolved: \(key)")
        }
    }

    func testAllUpstreamKeysExistInSimplifiedChinese() {
        for key in Self.expectedKeys {
            let v = L10n.localized(key, language: .simplifiedChinese)
            XCTAssertFalse(v.isEmpty, "Missing zh-Hans translation for key: \(key)")
            XCTAssertNotEqual(v, key, "Key not resolved: \(key)")
        }
    }
}
```

- [ ] **Step 2: Seed `expectedKeys` from the diff file**

Read `/tmp/aiyu-l10n-missing.txt` and list each key in the swift array.

- [ ] **Step 3: Add translations**

Open `AiyuTerm/Support/L10n.swift` and add every missing key to both the English and zh-Hans dictionaries. Translate from the upstream zh-Hans / en pairs.

- [ ] **Step 4: Run test, expect all pass**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -destination 'platform=macOS' test -only-testing:AiyuTermTests/L10nParityTests 2>&1 | grep -cE "^Test case .* passed"
```

- [ ] **Step 5: Commit**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
git add AiyuTerm/Support/L10n.swift Tests/L10nParityTests.swift
git commit -m "feat(l10n): full CodeIsland string parity (en + zh-Hans) [P11.8.2]"
```

---

# Phase 11.9 — Final Integration + Visual Polish

Integrate the pixel kit + mascots into `AgentNotchPanelView.swift` so they actually appear. Up to Phase 11.5 the pixel kit is stored as standalone files — now we wire them into the visible UI.

## Task 11.9.1: Wire `AgentTypingIndicator` when status == .working

**Files:**
- Modify: `AiyuTerm/UI/NotchPanel/AgentNotchPanelView.swift` (inside `SessionCardView`)

- [ ] **Step 1: Find the current tool row in SessionCardView**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
grep -n "showToolStatus\|toolLine" AiyuTerm/UI/NotchPanel/AgentNotchPanelView.swift | head
```

- [ ] **Step 2: Replace the tool row block**

Find the block that currently renders `toolLine(tool:detail:)` gated on `display.showToolStatus`. Replace it with:

```swift
// Phase 11.9.1: show a typing indicator next to the tool
// name while the session is actively working.
if display.showToolStatus,
   let tool = snapshot.currentTool, !tool.isEmpty {
    HStack(spacing: 6) {
        if snapshot.status == .working {
            AgentTypingIndicator()
                .frame(width: 24, height: 8)
        }
        toolLine(tool: tool, detail: snapshot.toolDescription)
    }
}
```

- [ ] **Step 3: Build + run existing notch tests**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -configuration Debug -destination 'platform=macOS' build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -destination 'platform=macOS' test -only-testing:AiyuTermTests/AgentNotchPanelViewModelTests -only-testing:AiyuTermTests/AgentNotchPanelShapeTests 2>&1 | grep -cE "^Test case .* passed"
```

- [ ] **Step 4: Commit**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
git add AiyuTerm/UI/NotchPanel/AgentNotchPanelView.swift
git commit -m "feat(notch): show AgentTypingIndicator next to tool row when working [P11.9.1]"
```

## Task 11.9.2: Replace `sourceTag` with `AgentSessionTag` pixel kit component

**Files:**
- Modify: `AiyuTerm/UI/NotchPanel/AgentNotchPanelView.swift` (inside `SessionCardView`)

- [ ] **Step 1: Find the existing sourceTag**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
grep -n "private var sourceTag:" AiyuTerm/UI/NotchPanel/AgentNotchPanelView.swift
```

- [ ] **Step 2: Replace sourceTag body with AgentSessionTag**

Keep the `AgentCLIAccent.accent(for:)` color lookup, but delegate rendering to the pixel-kit component:

```swift
private var sourceTag: some View {
    let accent = AgentCLIAccent.accent(for: snapshot.source)
    return AgentSessionTag(
        text: accent.displayName,
        color: accent.color
    )
}
```

- [ ] **Step 3: Build + run tests**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -configuration Debug -destination 'platform=macOS' build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -destination 'platform=macOS' test -only-testing:AiyuTermTests/AgentNotchPanelShapeTests 2>&1 | grep -cE "^Test case .* passed"
```

Expected: `12` (existing count unchanged — `AgentSessionTag` is a drop-in replacement).

- [ ] **Step 4: Commit**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
git add AiyuTerm/UI/NotchPanel/AgentNotchPanelView.swift
git commit -m "feat(notch): render source tag via AgentSessionTag pixel-kit component [P11.9.2]"
```

## Task 11.9.3: Use `AgentClaudeLogoShape` inside `AgentClaudeMascotView`

**Files:**
- Modify: `AiyuTerm/UI/NotchPanel/Mascots/AgentClaudeMascotView.swift`

- [ ] **Step 1: Read the current Claude mascot body**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
cat AiyuTerm/UI/NotchPanel/Mascots/AgentClaudeMascotView.swift
```

- [ ] **Step 2: Replace the body with AgentClaudeLogoShape**

```swift
struct AgentClaudeMascotView: View {
    let status: AgentSessionStatus
    var size: CGFloat = 27
    @State private var pulse: Bool = false

    var body: some View {
        AgentClaudeLogoShape()
            .fill(status == .working ? Color.orange : Color.orange.opacity(0.7))
            .frame(width: size, height: size)
            .scaleEffect(pulse && status == .working ? 1.08 : 1.0)
            .animation(
                status == .working
                    ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                    : .default,
                value: pulse
            )
            .onAppear { pulse = true }
    }
}
```

- [ ] **Step 3: Build + mascot factory test**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -configuration Debug -destination 'platform=macOS' build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -destination 'platform=macOS' test -only-testing:AiyuTermTests/AgentMascotFactoryTests 2>&1 | grep -cE "^Test case .* passed"
```

Expected: `4`.

- [ ] **Step 4: Commit**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
git add AiyuTerm/UI/NotchPanel/Mascots/AgentClaudeMascotView.swift
git commit -m "feat(notch): Claude mascot uses AgentClaudeLogoShape pixel-kit component [P11.9.3]"
```

## Task 11.9.4: Integration smoke test for fully wired notch view

**Files:**
- Create: `Tests/AgentNotchPanelIntegrationTests.swift`

- [ ] **Step 1: Write the test**

```swift
//
// AgentNotchPanelIntegrationTests.swift
// AiyuTermTests
//
// Phase 11.9.4: end-to-end integration smoke test for the
// fully wired notch panel view (mascots + pixel kit + session
// cards + approval bars + display options).
//

import Foundation
import SwiftUI
import XCTest
@testable import AiyuTerm

final class AgentNotchPanelIntegrationTests: XCTestCase {

    func testFullyPopulatedNotchViewConstructsWithoutCrashing() {
        let snapshot1 = AgentNotchWorktreeSnapshot(
            id: "/tmp/a",
            workspaceName: "demo",
            worktreeDisplayName: "main",
            status: .working,
            source: "claude",
            model: "claude-sonnet-4",
            cwd: "/tmp/a",
            currentTool: "Bash",
            toolDescription: "ls -la",
            lastAssistantMessage: "I ran the command.",
            lastUserPrompt: "Show me the directory",
            permissionRequest: nil,
            questionRequest: nil,
            resolvedTitle: "Exploring the repo"
        )
        let snapshot2 = AgentNotchWorktreeSnapshot(
            id: "/tmp/b",
            workspaceName: "demo",
            worktreeDisplayName: "feature",
            status: .permissionNeeded,
            source: "codex",
            model: "gpt-4o",
            cwd: "/tmp/b",
            currentTool: "Edit",
            toolDescription: "update main.py",
            lastAssistantMessage: nil,
            lastUserPrompt: nil,
            permissionRequest: AgentPermissionRequest(
                id: UUID(),
                sessionId: "sid-2",
                worktreePath: "/tmp/b",
                toolName: "Edit",
                toolDescription: "main.py",
                timestamp: Date()
            ),
            questionRequest: nil,
            resolvedTitle: nil
        )
        let state = AgentNotchViewState(
            aggregatedStatus: .permissionNeeded,
            pendingCount: 1,
            worktrees: [snapshot1, snapshot2],
            display: .default
        )
        let viewModel = AgentNotchPanelViewModel(state: state)
        let view = AgentNotchPanelView(viewModel: viewModel)
        _ = AnyView(view.body)
    }

    func testEmptyNotchViewConstructs() {
        let viewModel = AgentNotchPanelViewModel(state: .empty)
        let view = AgentNotchPanelView(viewModel: viewModel)
        _ = AnyView(view.body)
    }
}
```

- [ ] **Step 2: Run**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -destination 'platform=macOS' test -only-testing:AiyuTermTests/AgentNotchPanelIntegrationTests 2>&1 | grep -cE "^Test case .* passed"
```

Expected: `2`.

- [ ] **Step 3: Commit**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
git add Tests/AgentNotchPanelIntegrationTests.swift
git commit -m "test(notch): end-to-end integration smoke test with populated + empty states [P11.9.4]"
```

---

# Phase 11.10 — Final Verification + Debug Rebuild

## Task 11.10.1: Full test suite sweep

- [ ] **Step 1: Run every P9 + P10 + P11 test suite**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -destination 'platform=macOS' test \
  -only-testing:AiyuTermTests/AgentChatMessageTextFormatterTests \
  -only-testing:AiyuTermTests/AgentCLIConfigInstallerPhase9Tests \
  -only-testing:AiyuTermTests/AgentTerminalActivatorHelpersTests \
  -only-testing:AiyuTermTests/AgentTerminalVisibilityHelpersTests \
  -only-testing:AiyuTermTests/AgentSessionPersistenceTests \
  -only-testing:AiyuTermTests/AgentSessionTitleStoreTests \
  -only-testing:AiyuTermTests/AgentDiagnosticsExporterTests \
  -only-testing:AiyuTermTests/AgentNotchPanelViewModelTests \
  -only-testing:AiyuTermTests/AgentNotchPanelShapeTests \
  -only-testing:AiyuTermTests/AgentNotificationRouterTests \
  -only-testing:AiyuTermTests/AgentSoundManagerTests \
  -only-testing:AiyuTermTests/AgentSoundManagerTableTests \
  -only-testing:AiyuTermTests/AppSettingsNotchKeysTests \
  -only-testing:AiyuTermTests/AppSettingsFullParityTests \
  -only-testing:AiyuTermTests/AgentHookEventMapperTests \
  -only-testing:AiyuTermTests/AgentHookProtocolTests \
  -only-testing:AiyuTermTests/AgentCLIConfigInstallerTests \
  -only-testing:AiyuTermTests/AgentCLIConfigInstallerTopLevelTests \
  -only-testing:AiyuTermTests/AgentCLIConfigTests \
  -only-testing:AiyuTermTests/AgentMascotFactoryTests \
  -only-testing:AiyuTermTests/AgentPixelKitSmokeTests \
  -only-testing:AiyuTermTests/AgentStatusItemControllerTests \
  -only-testing:AiyuTermTests/AgentNotchControllerReactivityTests \
  -only-testing:AiyuTermTests/AgentCodexTranscriptTests \
  -only-testing:AiyuTermTests/AgentSessionSnapshotTitleTests \
  -only-testing:AiyuTermTests/AgentDerivedSessionStateTests \
  -only-testing:AiyuTermTests/AgentScreenDetectorParityTests \
  -only-testing:AiyuTermTests/L10nParityTests \
  2>&1 | tee /tmp/aiyu-p11-final.log | grep -cE "^Test case .* passed"
grep -cE "^Test case .* failed" /tmp/aiyu-p11-final.log
```

Expected: at least 290 pass, 0 fail.

## Task 11.10.2: Rebuild Debug .app

- [ ] **Step 1: Build**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -3
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name 'AiyuTerm.app' -path '*/Debug/*' -not -path '*.xctest*' 2>/dev/null | head -1)
/usr/bin/xattr -d com.apple.quarantine "$APP_PATH" 2>/dev/null
echo "APP_PATH=$APP_PATH"
du -sh "$APP_PATH"
```

Expected: `** BUILD SUCCEEDED **` + path printed + ~60MB.

## Task 11.10.3: Completion report

- [ ] **Step 1: Compute delta since `cf2203d`**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
git log --oneline cf2203d..HEAD | wc -l
git diff --stat cf2203d HEAD | tail -1
```

- [ ] **Step 2: Tally test count**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
find Tests -name '*.swift' | xargs wc -l | tail -1
```

- [ ] **Step 3: Produce an honest completion matrix** comparing every upstream file to our status. Every row must be either ✅ Ported / ⏭ Skip (with justification) / 🚧 Partial (with list of remaining gaps).

- [ ] **Step 4: Write final report to `docs/2026-04-10/phase11-100-percent-parity/completion-report.md`**

Include:
- Total new commits + LOC
- Test count + pass rate
- Debug .app path
- Upstream-vs-port matrix (every row must be ✅ or ⏭ — NO 🚧 rows allowed; if any remain, Phase 11.x is NOT complete)
- 10-step manual verification procedure
- Known issues + follow-ups

- [ ] **Step 5: Final commit**

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
git add docs/2026-04-10/phase11-100-percent-parity/
git commit -m "docs(phase11): 100% parity completion report + implementation plan [P11.10]"
```

---

# Execution Handoff

Plan complete and saved to `docs/2026-04-10/phase11-100-percent-parity/plan.md`. Two execution options:

**1. Subagent-Driven (recommended)** — Dispatch a fresh subagent per Phase 11.N task (or per Task 11.N.M group), review between tasks, fast iteration. Requires agent token budget (may hit limits again).

**2. Inline Execution** — Execute tasks sequentially in this session using superpowers:executing-plans, batching Phase 11.0 / 11.1 / 11.2 / 11.3 / 11.4 / 11.5 / 11.6 / 11.7 / 11.8 / 11.9 / 11.10 with a verification checkpoint between phases.

**Which approach?**
