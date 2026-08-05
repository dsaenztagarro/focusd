# 0001. Record architecture decisions as ADRs

**Status:** Accepted · **Scope:** Project documentation · **Decision:** Record significant architectural decisions as numbered ADRs under `docs/architecture/decisions/`.

This is the meta-decision that establishes the practice. It exists so the convention itself is written down, not just assumed — and it ships with this template so a new project inherits the practice on day one.

## Context

Every project makes non-obvious calls — a data-model shape, an integration boundary, a security trade-off.
The *reasoning* behind each ("we evaluated the options and chose X because …") is the institutional memory a future maintainer needs and the thing a closed pull request or issue throws away.
Without an agreed home, numbering, and status lifecycle, decisions are easy to write and hard to find, and there is no convention for *superseding* one when it changes.

## Decision

Adopt **Architecture Decision Records**, Michael Nygard's lightweight format.

- ADRs live in `docs/architecture/decisions/`, one decision per file, named `NNNN-kebab-case-title.md`.
- Each ADR carries a `Status` (`Proposed` → `Accepted` → `Superseded`/`Deprecated`) and follows [`template.md`](template.md).
- Accepted ADRs are immutable; a changed decision is a *new* ADR that supersedes the old.
- The folder [`README.md`](README.md) is the index and states the conventions in full.

ADRs record **decisions and their rationale.** They do not replace **how-to guides** (`docs/guides/`) or **architecture overviews** (`docs/architecture/*.md`), which explain how the system works today rather than why a particular fork was chosen.

## Alternatives considered

- **GitHub issues / PRs as the record.** They track *work to be done* and close when the work ships; the question "why is it built this way?" outlives them.
- **No formal records, reasoning in commit messages.** Undiscoverable and unindexed; there is no supersede convention.

## Consequences

- Significant decisions get a discoverable, permanent, reviewable home; the "why" survives the issue that produced it.
- Small overhead per decision (write the ADR, bump the index) — acceptable, and part of the AI-first posture where the reasoning is as much a deliverable as the code.

## References

- [Documenting Architecture Decisions — Michael Nygard](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [`README.md`](README.md) — folder conventions and index
- [`template.md`](template.md) — ADR template
