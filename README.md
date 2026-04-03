# AiyuTerm

[中文版本](./README.zh-CN.md)

[![Platform](https://img.shields.io/badge/Platform-macOS-black?style=flat-square)](https://github.com/aiyu-ai/AiyuTerm)
[![License](https://img.shields.io/badge/License-Apache%202.0-2ea44f?style=flat-square)](./LICENSE)

AiyuTerm is a native macOS terminal workspace app for developers who work across repositories, worktrees, branches, and split panes. It supports local shell, SSH, tmux sessions, and AI agent-backed terminal sessions with real-time status badges.

> AiyuTerm is forked from [Liney](https://github.com/wuwenrui/liney) by wuwenrui. Thanks to the original author for the excellent foundation. The project has been renamed from Liney to AiyuTerm.

![AiyuTerm app screenshot](./images/screenshot.png)

## Features

- **Multi-repo sidebar** -- Keep multiple repositories and worktrees in one sidebar, switch between them instantly
- **Persistent layout** -- Reopen the same pane layout when you come back to a repo; layouts are saved per worktree
- **Split panes** -- Split terminals horizontally or vertically, zoom any pane to full screen
- **Multiple session types** -- Mix local shell, SSH, and agent-backed terminal sessions in the same workspace
- **Tmux integration** -- Sidebar panel for tmux session management (attach, create, rename, kill)
- **Agent status badges** -- Real-time permission and task completion notifications for Claude Code
- **Command palette** -- Quick access to all actions via keyboard
- **Customizable shortcuts** -- Rebind every keyboard shortcut in Settings
- **Native macOS app** -- Built with AppKit + SwiftUI, powered by the Ghostty terminal engine

## Install

### Direct Download

Download the latest signed `.dmg` from GitHub Releases:

<https://github.com/aiyu-ai/AiyuTerm/releases/latest>

### Homebrew (coming soon)

```bash
brew install --cask aiyu-ai/tap/aiyuterm
```

## Quick Start

### 1. Add repositories

Open AiyuTerm and drag a folder into the sidebar, or use the "+" button to add local repositories.

### 2. Open terminal tabs

Select a repository or worktree in the sidebar, then press `Cmd+T` to open a new terminal tab.

### 3. Split panes

- `Cmd+D` -- Split right
- `Cmd+Shift+D` -- Split down
- `Cmd+Option+Arrow` -- Move focus between panes
- `Cmd+Enter` -- Toggle zoom on the active pane

### 4. Switch worktrees

Click another worktree in the sidebar. AiyuTerm restores the last pane layout you used for that worktree automatically.

### 5. Use the command palette

Press `Cmd+P` to open the command palette for quick access to all actions.

## Keyboard Shortcuts

All shortcuts are customizable in Settings (`Cmd+,`).

### Tabs

| Action | Shortcut |
|--------|----------|
| New tab | `Cmd+T` |
| Close tab | `Cmd+W` |
| Next tab | `Ctrl+Tab` |
| Previous tab | `Ctrl+Shift+Tab` |
| Select tab 1-9 | `Cmd+1` ... `Cmd+9` |

### Panes

| Action | Shortcut |
|--------|----------|
| Split right | `Cmd+D` |
| Split down | `Cmd+Shift+D` |
| Duplicate pane | `Cmd+Option+D` |
| Focus left/right/up/down | `Cmd+Option+Arrow` |
| Toggle pane zoom | `Cmd+Enter` |
| Close pane | `Cmd+Option+W` |

### General

| Action | Shortcut |
|--------|----------|
| Command palette | `Cmd+P` |
| Toggle sidebar | `Cmd+B` |
| Toggle overview | `Cmd+Shift+O` |
| Find | `Cmd+F` |
| Settings | `Cmd+,` |
| Refresh workspace | `Cmd+R` |
| Refresh all repos | `Cmd+Shift+R` |
| Full screen | `Ctrl+Cmd+F` |

## Agent Status Badges

AiyuTerm shows real-time status on sidebar icons when Claude Code needs attention:

| Status | Badge | Trigger |
|--------|-------|---------|
| Permission needed | Red pulse | Claude Code waiting for user approval |
| Task completed | Green checkmark | Claude Code finished a task |
| Error | Red static | Claude Code encountered an error |

Powered by Claude Code hooks. See [docs/agent-status-badges.md](./docs/agent-status-badges.md) for setup instructions.

## Tmux Integration

AiyuTerm provides a sidebar panel for managing tmux sessions within your workspace:

- **Attach** to existing tmux sessions
- **Create** new named sessions
- **Rename** or **kill** sessions from the sidebar
- Sessions are grouped by workspace

Requires `tmux` installed (`brew install tmux`).

## Data Storage

AiyuTerm stores workspace data and settings as JSON files:

- **Default**: `~/.aiyuterm/`
- **Debug builds**: `~/.aiyuterm-debug/`

No cloud sync. All data stays local on your machine.

## Requirements

- macOS 14.6 or later
- Universal build: Apple Silicon and Intel Macs

## For Developers

Development setup, build commands, testing, and release docs: [`DEVELOP.md`](./DEVELOP.md).

## Acknowledgments

- [Liney](https://github.com/wuwenrui/liney) by wuwenrui -- the original open-source terminal workspace app this project is forked from
- [Ghostty](https://ghostty.org/) -- the terminal engine powering AiyuTerm
- [Sparkle](https://sparkle-project.org/) -- auto-update framework

## License

Released under the Apache License 2.0. See [`LICENSE`](./LICENSE).
