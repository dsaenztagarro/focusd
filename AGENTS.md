# AGENTS.md

Instructions for AI agents working on this codebase. This is the single source of truth agents read before doing anything; keep it current.

## Model selection & task tracking

Every task you plan or pick up carries an explicit **complexity** rating and the **model** it runs on — state both (`complexity · model · why`) in the plan, the epic ticket, or the task list so the choice is deliberate and reviewable, not implicit. When you decompose work, tag each piece; don't leave the model a running default nobody chose.

- **Default to the most capable model.** Correctness-critical, interdependent, or context-heavy work — the Carbon/AppKit interop, the run-loop and activation logic, anything where a subtle mistake compounds — stays there even when it is small.
- **Escalate to a cheaper/faster model only when the complexity genuinely pays off there** and the task isn't the correctness-critical kind above (e.g. a docs typo, a Makefile tweak). When it's a close call, stay on the capable model.
- **Record the call, one clause of why.** e.g. `complexity: simple · model: <cheaper> · why: comment-only edit`.

## Improving this workflow (raise the hand)

This project runs on the [ai-engineering-template](https://github.com/dsaenztagarro/ai-engineering-template). When you discover a **reusable, project-agnostic** improvement to the workflow itself — a rule that should exist here, a skill step that misfires, a docs-taxonomy gap, a principle worth stating — don't silently apply it only to this repo. **Raise the hand:** run the **`template-feedback`** skill (`.claude/skills/template-feedback/`) to surface a concrete proposal and, on the maintainer's OK, open an issue on the upstream template so every adopter benefits. Keep project-specific rules in this repo; send generalizable ones upstream.

## Project Overview

focusd is a tiny macOS **global-hotkey daemon**: press Ctrl+T anywhere to toggle focus between two apps (Alacritty running Zellij, and iTerm2 running Herdr). It is deliberately built from scratch on the native macOS system APIs — a learning exercise in how global hotkeys, run loops, inter-app activation, and `launchd` daemonization actually work — rather than configuring an off-the-shelf tool. See the [README](README.md).

## Tech Stack

- **Swift** (SwiftPM executable, `swift-tools-version:5.9`), targeting macOS 14+.
- **AppKit** (`NSWorkspace`, `NSApplication`) for reading the frontmost app and activating apps.
- **Carbon HIToolbox** (`RegisterEventHotKey`, `InstallEventHandler`) for the global hotkey.
- **launchd** LaunchAgent for run-at-login + keep-alive. `make` + `sed` for install.
- No third-party dependencies.

## Common Commands

```bash
# build:   swift build -c release
# test:    swift build -c release   (no unit suite; verification is runtime — see below)
# lint:    swift build -c release -Xswiftc -warnings-as-errors
# run:     make run          # foreground, Ctrl-C to stop (prints the log to the terminal)
# install: make install      # build + install LaunchAgent + load it
# logs:    make logs         # tail ~/Library/Logs/local.focusd.log
```

## Architecture

One Swift file (`Sources/focusd/main.swift`, ~90 lines) registers a Carbon hotkey, runs an `NSApplication` loop in `.accessory` policy, and on each press activates the app that isn't frontmost. The WindowServer does the key matching and hands the process a single high-level event, so no keyboard-monitoring permission is needed.

Key files:
- `Sources/focusd/main.swift` — the whole daemon: config constants, focus logic, Carbon plumbing, entry point.
- `launchd/local.focusd.plist` — LaunchAgent template (`__BIN__`/`__LOG__` filled by `make install`).
- `Makefile` — build / install / reload / uninstall / logs.
- `docs/architecture/global-hotkey-daemon.md` — how-it-works explainer.

For the two non-obvious decisions, read the ADRs before changing that area: [0002](docs/architecture/decisions/0002-carbon-hotkey-over-cgeventtap.md) (Carbon vs. `CGEventTap`, the permission model) and [0004](docs/architecture/decisions/0004-rebind-to-ctrl-t.md) (why Ctrl+T — supersedes [0003](docs/architecture/decisions/0003-cmd-opt-space-keybinding.md)'s ⌘⌥Space).

## Documentation Conventions

- **Architecture Decision Records** live in `docs/architecture/decisions/` — one decision per file, numbered, **immutable once accepted** (a changed decision is a new ADR that supersedes the old). Follow [`docs/architecture/decisions/template.md`](docs/architecture/decisions/template.md); the [README](docs/architecture/decisions/README.md) states the conventions. Record a decision that's architecturally meaningful (the event-capture mechanism, the permission boundary, the keybinding rationale) as an ADR — not local code choices.
- **How-to guides** live in `docs/guides/`; **feature docs** in `docs/features/`; **how-it-works explainers** in `docs/architecture/*.md`. Keep them distinct: an ADR is *why we chose X*, an explainer is *how it works today*, a guide is *how you do X*.
- **Markdown prose is one line per paragraph** (or semantic line breaks), never fixed-column hard wraps.

## Preserve Architectural Understanding

For any non-trivial mechanism — how the hotkey is delivered, the run-loop/activation dance, a cross-cutting convention that isn't obvious from any single file — keep a *how-it-works* explainer under `docs/architecture/` (a plain `*.md`). This is **complementary to ADRs, not a substitute**: the ADR records *why*; the explainer records *how it actually works today* so a maintainer (or a future agent) can rebuild the mental model without reverse-engineering the code.

- **When you build or materially change such a mechanism, write or update its explainer as part of the same work** — don't wait to be asked, and cross-link the explainer and its ADR both ways. Use [`docs/architecture/EXPLAINER-TEMPLATE.md`](docs/architecture/EXPLAINER-TEMPLATE.md). The current explainer is [`docs/architecture/global-hotkey-daemon.md`](docs/architecture/global-hotkey-daemon.md).

## Documentation Style

When creating diagrams in documentation or code comments:
- Use simple ASCII characters (`+`, `-`, `|`, `v`, `^`, `>`) instead of Unicode box-drawing characters.
- This ensures consistent rendering across all fonts, terminals, and editors.

```
Good (ASCII):
+--------+     +--------+
| Box A  |---->| Box B  |
+--------+     +--------+
```

## Testing Guidelines

### Test the real thing; don't mock the object under test

A test that stubs the very thing it is checking proves the stub, not the app. Default to **real collaborators**: exercise the actual `NSWorkspace`/Carbon behaviour rather than faking it. Reserve test doubles for genuine boundaries you cannot stand up in-process.

### Verify the runtime surface

This daemon's behaviour *is* its runtime surface — a green build proves nothing about whether the hotkey fires. Before considering a change done, **drive it and observe**: `make run`, press Ctrl+T (or synthesize it with `osascript -e 'tell application "System Events" to key code 17 using {control down}'`), and confirm a `toggle:` line in the log and the focus actually switching. Passing compilation is necessary, not sufficient.

## CI / gate

Before a change ships, the build must be clean with warnings treated as errors:

```bash
swift build -c release -Xswiftc -warnings-as-errors
```

and the runtime surface must be driven (above). There is no separate unit-test suite; if one is added, it joins this gate. The `/epic` skill defers to this gate.

## Development Workflow

For any new feature or significant change:

1. **Create a GitHub issue** documenting the change (summary, acceptance criteria, technical notes).
2. **Create a feature branch** named after the issue: `git checkout -b <issue>-<slug>`.
3. **Implement & test** — run the gate frequently; drive the runtime surface (press/synthesize the hotkey).
4. **Record decisions** — architecturally meaningful decision → an ADR; new/changed mechanism → its explainer.
5. **Open a PR** with `gh pr create`, body ending `Closes #<issue>`; merge with `gh pr merge --squash` once the gate is green.

For larger, multi-ticket work, drive it with the **`/epic`** skill (`.claude/skills/epic/`): one design doc → a GitHub epic → phased sub-issues → shipped, one ticket at a time.
