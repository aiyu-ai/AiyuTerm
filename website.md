# Liney Website Brief

## Goal

Create a focused product landing page for **Liney**, a native macOS terminal workspace manager.

The page should make one thing obvious within a few seconds:

**Liney helps developers manage multiple repositories, worktrees, and terminal sessions in one clean native macOS workspace.**

This is not a generic terminal emulator. It is a workspace tool for people working across many repos, branches, and concurrent tasks.

## Target Audience

- Indie developers shipping across several repos
- Staff and senior engineers juggling multiple worktrees and long-running sessions
- AI-assisted developers who keep many task-specific terminal contexts open
- macOS users who prefer native apps over Electron-heavy tooling

## Positioning

Liney sits between a terminal app and a project workspace manager.

It should feel like:

- more organized than a traditional tabbed terminal
- lighter and more native than a browser-style dev workspace
- more practical than a tiling setup that requires lots of manual discipline

## Core Message

**One native workspace for all your repos, worktrees, and terminal flows.**

Supporting message:

**Switch contexts fast, keep parallel tasks visible, and stop losing track of shell sessions.**

## Hero Section

### Headline options

Preferred:

**A native macOS workspace for serious terminal work**

Alternatives:

- **Manage repos, worktrees, and terminals without the chaos**
- **The terminal workspace manager for macOS**
- **Keep every repo and terminal task in one place**

### Subheadline

**Liney brings repositories, git worktrees, split-pane terminals, canvas view, and diff inspection into one fast native macOS app.**

### Primary CTA

**Download for macOS**

### Secondary CTA

**View on GitHub**

### Hero bullets

- Native AppKit + SwiftUI app
- Built for multi-repo and worktree-heavy workflows
- Live terminal canvas and built-in diff view
- Ghostty-powered terminal surfaces

## Product Story

Developers rarely work in a single terminal anymore.

Modern work means jumping between repositories, feature branches, worktrees, review fixes, AI tasks, long-running dev servers, and remote shells. Standard terminal tabs break down fast. Important sessions get buried, branch context gets mixed up, and switching tasks becomes expensive.

Liney is built to solve that. It gives each workspace a structure: repositories in the sidebar, worktrees grouped where they belong, terminals arranged in panes, and a canvas mode to keep active sessions visible at once. It stays native, fast, and Mac-like while handling serious multi-context development.

## Key Features

### 1. Multi-Repo Sidebar

Organize many repositories in one app window.

- Pin active projects
- Archive inactive ones
- Reorder the workspace list
- Keep worktrees attached to their parent repository

### 2. Worktree-Native Workflow

Treat git worktrees as a first-class part of daily development.

- Create and remove worktrees from inside the app
- Switch between branches and working copies without losing structure
- Keep each worktree’s terminal layout separate

### 3. Split-Pane Terminal Sessions

Run multiple shells side by side without turning your screen into tab soup.

- Open local shell sessions
- Use SSH sessions when needed
- Keep task-specific panes grouped by workspace

### 4. Live Canvas View

See all active terminal sessions as a visual workspace.

- Live terminal previews, not static screenshots
- Move cards around to match how you think
- Keep layout persisted per workspace or worktree
- Focus one card for direct interaction while others stay visible

### 5. Built-In Diff Window

Open diff anytime from the app.

- Inspect current changes without leaving the workspace
- Empty state when there is no diff yet
- Works as a fast side tool during active coding sessions

### 6. Native macOS Feel

Liney should feel like a real Mac app, not a web app in disguise.

- AppKit container architecture with SwiftUI UI layers
- Fast local state and workspace persistence
- Tight keyboard-and-sidebar workflow

## Why It’s Different

Most terminal apps optimize for tabs.
Liney optimizes for **active development context**.

That means:

- repositories instead of just windows
- worktrees instead of manually tracked folders
- pane layouts instead of disposable tabs
- canvas visibility instead of hidden background sessions

## Social Proof / Trust Section

Use this section lightly. The product is early.

Suggested copy:

**Built for real multi-context development on macOS**

Liney is designed for developers who regularly work across multiple repositories, feature branches, code review fixes, and long-running terminal tasks.

Optional micro-points:

- Open source
- Native macOS stack
- Designed around real worktree workflows

## Installation Section

### Option 1

**Download the latest release**

Install the signed macOS app from the latest GitHub release.

### Option 2

**Install with Homebrew**

```bash
brew install --cask wuwenrui/tap/liney
```

If the actual tap path should stay generic in marketing copy, use:

```bash
brew install --cask liney
```

### Requirements

- macOS 14 or later
- Apple Silicon Mac

## Screenshot / Visual Direction

The page should feel native, sharp, and technical, not neon-gamer and not generic SaaS.

Visual direction:

- Bright, clean macOS-inspired surfaces
- Dense but elegant information layout
- Subtle graphite, off-white, steel, and muted blue accents
- Use terminal content and workspace structure as the visual hero
- Avoid purple gradients and template-style startup aesthetics

Suggested screenshots:

- Main workspace with sidebar + split panes
- Canvas view with several live session cards
- Diff window open beside a workspace
- Worktree-focused sidebar organization

## Information Architecture

Recommended page order:

1. Hero
2. Product screenshot
3. Problem / product story
4. Feature grid
5. Canvas highlight
6. Worktree and diff highlight
7. Installation
8. Open source / GitHub CTA
9. FAQ
10. Final CTA

## FAQ

### What is Liney?

Liney is a native macOS terminal workspace manager for developers working across multiple repositories, worktrees, and shell sessions.

### Is it a terminal emulator?

It includes terminal surfaces, but the main idea is workspace management: organizing repos, worktrees, panes, and session context in one app.

### Does it support Git worktrees?

Yes. Worktrees are a first-class workflow in Liney.

### Is it open source?

Yes. The source is available on GitHub.

### What platforms does it support?

Liney currently targets macOS, with Apple Silicon as the primary supported architecture for the shipped Ghostty runtime.

## Final CTA

### Headline

**Bring your terminal workflow into one native workspace**

### Buttons

- Download for macOS
- Star on GitHub

## SEO Metadata

### Title

**Liney - Native macOS Terminal Workspace Manager**

### Meta description

**Liney is a native macOS app for managing repositories, git worktrees, split-pane terminal sessions, canvas views, and diffs in one focused developer workspace.**

### Keywords

- macOS terminal workspace manager
- git worktree app mac
- native terminal app macOS
- developer workspace macOS
- terminal pane manager mac

## Tone

Writing tone should be:

- confident
- precise
- technical but not jargon-heavy
- productivity-focused
- native-Mac rather than hacker-cliche

Avoid:

- exaggerated “10x” language
- generic AI startup phrasing
- vague claims like “supercharge your workflow”

## Landing Page Prompt

Use this if generating the page with an AI design or site-building tool:

> Design a premium landing page for Liney, a native macOS terminal workspace manager. The audience is experienced developers who juggle multiple repositories, git worktrees, and terminal sessions. The visual style should feel like a serious Mac developer tool: clean, refined, bright, native, and technical. Avoid generic SaaS gradients, avoid purple-heavy palettes, and avoid playful startup tropes. The page should clearly show that Liney combines a multi-repo sidebar, worktree-aware layouts, split-pane terminal sessions, a live canvas view of active terminals, and a built-in diff viewer. Include a strong hero, product screenshots, a feature grid, installation section, FAQ, and final CTA to download for macOS or view on GitHub.
