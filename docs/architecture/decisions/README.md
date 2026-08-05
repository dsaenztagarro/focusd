# Architecture Decision Records

This folder holds **Architecture Decision Records (ADRs)** — short documents that capture one significant technical decision each: what we decided, *why*, the alternatives we rejected, and the consequences.

We keep ADRs because the reasoning behind a non-obvious call is institutional memory that a closed pull request or issue throws away.
An ADR answers the question a future maintainer actually asks — *"why is it built this way?"* — without anyone having to remember.

## Conventions

- **One decision per file.** Filename is `NNNN-kebab-case-title.md`, zero-padded (`0002-...`).
  Numbers are allocated in order and never reused.
- **Header line.** Every ADR opens with a bold `**Status:** ... · **Scope:** ... · **Decision:** ...` line.
- **Status lifecycle:** `Proposed` → `Accepted` → (`Superseded by NNNN` | `Deprecated`).
- **Accepted ADRs are immutable.** Don't rewrite the reasoning after acceptance — if the decision changes, write a new ADR and mark the old one `Superseded by NNNN`.
  Fixing typos or adding a forward-link is fine.
- **Diagrams are ASCII** (`+ - | v ^ >`), per the repo documentation conventions.

ADRs record **decisions and their rationale.** They do not replace **how-to guides** (`docs/guides/`) or **architecture overviews** (`docs/architecture/*.md`), which explain how the system works today rather than *why* a particular fork was chosen.

## Adding an ADR

1. Copy [`template.md`](template.md) to `NNNN-your-title.md` (next free number).
2. Fill in Context / Decision / Alternatives considered / Consequences.
3. Add a row to the index below.
4. If the decision is tracked by an issue or shipped in a PR, link it from the ADR.

## Index

| ADR | Title | Status |
|-----|-------|--------|
| [0001](0001-record-decisions-as-adrs.md) | Record architecture decisions as ADRs | Accepted |
| [0002](0002-carbon-hotkey-over-cgeventtap.md) | Capture the hotkey with Carbon `RegisterEventHotKey`, not a `CGEventTap` | Accepted |
| [0003](0003-cmd-opt-space-keybinding.md) | Bind the focus toggle to ⌘⌥Space | Accepted |
