<!--
  terminal-architecture.md
  AiyuTerm

  Author: everettjf
-->

# Terminal Architecture

AiyuTerm keeps terminal code split between a small set of abstractions and a dedicated Ghostty adapter layer. The goal is to let higher-level session code talk to a stable interface while the `libghostty` bridge stays isolated.

## Directory Layout

```text
AiyuTerm/Services/Terminal/
├─ Ghostty/
│  ├─ AiyuTermGhosttyBootstrap.swift
│  ├─ AiyuTermGhosttyClipboardSupport.swift
│  ├─ AiyuTermGhosttyController.swift
│  ├─ AiyuTermGhosttyInputSupport.swift
│  └─ AiyuTermGhosttyRuntime.swift
├─ SessionBackendLaunch.swift
├─ ShellSession.swift
├─ TerminalSurface.swift
└─ WorkspaceSessionController.swift
```

## Responsibilities

### `TerminalSurface.swift`

Defines the app-facing terminal protocols:

- `TerminalSurfaceController`
- `ManagedTerminalSessionSurfaceController`
- `TerminalSurfaceFactory`

Higher layers should depend on these protocols first, not on Ghostty concrete types.

### `ShellSession.swift`

Owns the lifecycle of a single terminal session:

- launch configuration
- working-directory tracking
- title updates
- process exit handling
- focus and search commands

This layer should not know about Ghostty callbacks beyond the controller protocol.

### `WorkspaceSessionController.swift`

Coordinates multiple sessions for a workspace and feeds pane-level UI state.

### `Ghostty/AiyuTermGhosttyRuntime.swift`

Owns the shared `libghostty` app/runtime instance, callback wiring, and clipboard callback entry points.

### `Ghostty/AiyuTermGhosttyController.swift`

Bridges one managed terminal surface to AppKit:

- creates and destroys surfaces
- forwards Ghostty actions to workspace commands
- manages search/read-only state snapshots
- handles input, IME, selection, cursor, and secure-input behaviors

### `Ghostty/AiyuTermGhosttyInputSupport.swift`

Contains pure keyboard and IME helper logic. This file is intentionally kept light on object state so its behavior can be unit tested directly.

### `Ghostty/AiyuTermGhosttyClipboardSupport.swift`

Normalizes clipboard read/write helpers and payload typing used by the runtime and controller.

### `Ghostty/AiyuTermGhosttyBootstrap.swift`

Performs one-time `libghostty` global initialization before the app starts driving any terminal surface.

## Design Rules

- Keep `libghostty` specifics inside `AiyuTerm/Services/Terminal/Ghostty/`.
- Prefer pure helper functions for modifier translation, text routing, and selection rules when possible.
- Let `ShellSession` observe controller callbacks rather than owning Ghostty state directly.
- Avoid adding new terminal-engine abstractions unless the app genuinely supports another engine again.
- Do not modify `AiyuTerm/Vendor/` unless the change explicitly requires a new Ghostty binary or header surface.

## When To Add Tests

Add unit coverage when changing:

- key routing or modifier translation
- IME marked-text behavior
- clipboard permission flows
- workspace-action dispatch from Ghostty callbacks
- session lifecycle transitions in `ShellSession`

For UI-heavy terminal changes, pair unit tests with a small manual smoke test note covering focus, typing, split operations, and search if those behaviors were touched.
