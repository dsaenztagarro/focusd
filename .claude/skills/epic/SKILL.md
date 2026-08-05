---
name: epic
description: Turn a design doc into a GitHub epic — decompose the design into self-contained sub-issues with a phased plan, then implement them one ticket at a time (branch → tests → PR → squash-merge), carrying every pragmatic decision forward on the epic issue so later tickets inherit the context. The design doc is a UI design (a Claude Design canvas under `docs/designs/*.html`) or a backend/architecture design authored as markdown (`docs/architecture/*.md` or `docs/features/*.md`). User-invoked only; the user reviews the work at the very end. Run `/epic <design-path>` to start, or `/epic resume #<epic>` to continue.
argument-hint: "<docs/designs/*.html | docs/architecture/*.md | docs/features/*.md> | resume #<epic>"
---

# Run an epic from a design doc

When the user invokes this skill, take one design document and drive it end-to-end: open a
GitHub **epic** issue, split the design into meaningful self-contained **sub-issues** with a
phased plan, then implement the sub-issues **one at a time** until the epic is done. The user
reviews the work only at the very end — so the **epic issue is the shared memory** between
tickets, and the terminal stays quiet.

This skill is **user-invoked only**. It creates real GitHub issues and merges real PRs, so
never auto-trigger it; run it only when the user types `/epic`.

### Design-doc formats (UI vs backend)

A design doc comes in one of two shapes; the skill works the same either way — read it,
decompose it into phased tickets, ship them. What differs is where it lives and how it
decomposes:

| Kind | Lives in | Authored by | Decomposes by |
|------|----------|-------------|---------------|
| **UI / visual** | `docs/designs/*.html` | **Claude Design** (from a design brief) | the doc's sections/anchors; each interactive workflow becomes a spec'd ticket |
| **Backend / architecture** | `docs/architecture/*.md` (a cross-cutting contract) or `docs/features/*.md` (a feature's design) | authored directly as markdown from an approved plan/ADR | its own section headings and phase ordering; each layer that can merge green becomes a ticket |

For a backend design there are no visual workflows — "design fidelity" means the contracts the
doc specifies, verified by unit/integration tests rather than UI tests. When a section can't merge
green without another (a big-bang cutover), make it **one** ticket; don't split a red build across
two PRs.

## Operating principles (hold these the whole run)

- **One ticket at a time.** Never implement sub-issues in parallel. Finish, test, and ship the
  current ticket before starting the next.
- **The epic carries the context.** Every pragmatic decision goes on the epic's **Decisions Log**
  _and_ on the sub-issue. Before each ticket, re-read the log.
- **Terse terminal, rich issues.** No diff dumps, no test-log dumps, no plan narration. Emit one
  short status line per ticket. The detailed record lives in the issues and the epic.
- **Document where it belongs.** Pragmatic ticket decision → sub-issue + epic log. Architecturally
  meaningful decision → _also_ a numbered ADR (see step 3.5).
- **Follow the repo's rules.** `AGENTS.md` governs implementation, testing, commits, and the
  test/lint **gate**. Read it; don't restate it here.
- **Design fidelity is verified, not assumed.** Every workflow the design specifies must have a
  test (per the repo's testing rules). A merged ticket without a test for its workflow is an open
  gap — and a _closed_ epic is not proof its design is fully implemented. When re-running on a
  design a prior epic already touched, trust the **diff against the current code**, not the old
  checklist.

## 0. Resolve the argument (new vs resume)

| Argument | Mode |
|---|---|
| a design-doc path the codebase has **never** built against | **new epic** |
| a design-doc path a **prior epic already touched** (open or closed) | **re-diff** (reconciliation) |
| `resume #<n>` or a bare epic issue number | **resume** an in-flight epic |
| _(none)_ | **ask** which design doc; do not guess |

**Idempotency guard (path mode):** before creating anything, run
`gh issue list --label epic --search "<design filename>"` across both states
(`--state open` and `--state closed`).

- An **open** epic exists → switch to **resume** instead of opening a duplicate.
- A **closed** epic exists → switch to **re-diff mode**. A closed epic is _not_ proof the current
  design is fully implemented — re-diff to find what changed or was never finished. Open a **fresh**
  epic scoped to the delta.
- Nothing references it → **new epic**.

**Resume mode:** read the epic body — its phased checklist tells you which sub-issues are done
(`[x]`), skipped, or outstanding (`[ ]`). Read the **Decisions Log** in full, then jump to step 3
for the first outstanding ticket. If the design changed since the epic was created, run the
**re-diff pass (step 1.5)** over the outstanding scope first.

**Re-diff mode:** plan as a new epic (steps 1–2) but make the **re-diff pass (step 1.5)** the basis
of decomposition: the tickets are the workflows that are missing, broken, partial, or untested —
not a greenfield rebuild. Reference the prior epic in the new epic's Summary.

## 1. Plan the epic (read the design → decompose)

1. Read the design doc. Identify its sections and the components/behaviours each specifies.
2. Ground the design against the codebase where a section maps to existing code — prefer the
   `Explore` agent over manual grep. You are looking for what already exists so tickets reuse it.
3. **In re-diff / resume modes, run the re-diff pass (step 1.5) now.**
4. Decompose into **meaningful, self-contained issues.** Each should be shippable on its own and
   map to one or more sections. When two pieces can't merge green independently, make them one
   ticket.
5. Order the issues into **phases by dependency** — foundation / shared vocabulary first, then the
   surfaces that build on it.
6. Draft the epic body using the **Epic body template** below.
7. **Approval gate (the one interactive pause):** show the user the proposed epic title and the
   phased issue list, and get a yes before creating anything on GitHub. This is the cheapest point
   to course-correct, and creating a dozen issues is outward-facing and hard to undo. After the yes,
   run autonomously to the end.

### 1.5 Re-diff pass (re-diff & resume modes only)

Diff the current implementation against the latest design before decomposing. The prior epic being
closed means nothing; verify against the code.

1. **Enumerate** every surface, element, and **workflow** the latest design specifies. A subagent
   (`Explore`) reading the design end-to-end is the cheapest way to get an exhaustive list.
2. **Classify** each against the current code (`Explore`): `covered+tested` (out of scope),
   `covered-untested` (backfill the test), `partial` (fidelity gap), `broken` (fix first),
   `missing`.
3. **The classification _is_ the decomposition.** Group the not-`covered+tested` workflows into
   phased tickets. Order: `broken` fixes and shared atoms first, larger reworks next, integration
   last.
4. **Surface, never drop.** Items the prior epic skipped or left partial are listed explicitly.
5. **Verify the classification.** Treat your own "covered+tested" calls skeptically — read the test
   and confirm it asserts the workflow, not just a success status.

## 2. Create the epic and its sub-issues

1. Create the epic: `gh issue create --label epic --title "EPIC: <title>" --body-file <tmp>`.
   Capture the epic number `#E`. (If the `epic` label is missing: `gh label create epic`.)
2. Create one issue per planned ticket (`gh issue create`), body =
   - first line: `Part of EPIC #E · Design [<section>](<design-path>)`
   - `## Goal` — what this ticket delivers
   - `## Acceptance` — checkbox criteria
   - `## Technical notes` — files/patterns to reuse, constraints
   - `## Decisions` — placeholder, filled as the ticket is implemented
3. Rewrite the epic's **Phased plan** so each line references the real sub-issue number:
   `- [ ] #<sub> — <title>`, grouped by phase. Edit with `gh issue edit #E`.

## 3. Implement tickets — strictly one at a time

Loop over the outstanding tickets **in phase order**. For each:

### 3.1 Pre-flight context
- Read the sub-issue in full (`gh issue view #<sub>`).
- Re-read the epic's **Decisions Log** (`gh issue view #E`); honor any entry whose _affects:_ tag
  names this ticket.
- Ensure a clean working tree on an up-to-date default branch.

### 3.2 Blocked check (skip rule)
If a critical step is blocking and **no pragmatic decision can unblock it**: comment
`Skipped: <reason>` on the sub-issue, append a `⚠ skipped` entry to the epic Decisions Log, leave
the epic checkbox **unchecked**, and move on. **Never silently drop a ticket.** If a pragmatic
decision _can_ unblock it, take the smallest reasonable one and record it (step 3.9).

### 3.3 Branch
`git checkout -b <sub>-<slug>` from the default branch.

**Guard against a remote branch-name collision first.** `git checkout -b` succeeds even when a
branch of that name exists on the remote, and a later push would land your commits on it, silently
contaminating whatever PR points at it. Before the first push, run
`git ls-remote --exit-code origin <branch>`; if it exists remotely, pick a distinct name.

### 3.4 Implement
Follow `AGENTS.md` and the established repo conventions. Reuse before you build. For a UI ticket,
match the Claude Design canvas exactly and reference the design system (per `AGENTS.md`).

### 3.5 ADR gate (architecturally meaningful decisions only)
If this ticket made a decision that's architecturally meaningful (a data-model or interface
contract, a cross-cutting integration choice, a security boundary — not a local code choice),
record an ADR:
- copy `docs/architecture/decisions/template.md` → next free `NNNN-<slug>.md`,
- fill Context / Decision / Alternatives considered / Consequences, ASCII diagrams only,
- add the index row to `docs/architecture/decisions/README.md`,
- reference the sub-issue and epic in the ADR's References section.

If the ticket built or materially changed a non-trivial mechanism, update its how-it-works
explainer under `docs/architecture/` in the same PR (per `AGENTS.md`).

### 3.6 Test gate
The project's **test + lint gate** (as defined in `AGENTS.md`) must pass. Fix failures before going
further. Where the change has a runtime surface, drive it and confirm the behaviour, not just that
tests pass.

### 3.7 Commit
Conventional Commits with scope and the issue ref: `type(scope): <subject> (#<sub>)`.

### 3.8 Ship the ticket (merge — no release here)
- `git push -u origin HEAD`
- `gh pr create` with a body that ends `Closes #<sub>` and links `Part of EPIC #E`
- squash-merge once the gate is green: `gh pr merge --squash --delete-branch`
- return to the default branch and pull.

### 3.9 Record + carry the decision forward
For every pragmatic decision: comment it on the sub-issue and append one line to the epic
**Decisions Log** (`gh issue edit #E`), tagging which future tickets it may affect. Then check the
ticket's box on the epic Phased plan and annotate `shipped (PR #X)`.

### 3.10 Status line
One short line, e.g. `✓ #12 row badge — shipped (PR #18)` or
`⚠ #14 bell inbox — skipped (needs a Notification model, not in scope)`. Nothing more.

## 4. Close out the epic

When every ticket is shipped or consciously skipped:
1. Cut **one** release for the epic's merged work (version bump + changelog + tag + GitHub
   release). One release per epic — not per ticket.
2. Close the epic issue if nothing is outstanding; otherwise leave it open with an `## Outstanding`
   note listing the skipped tickets and what would unblock them.
3. If deployment is a separate, human-gated step in this project, **do not deploy** — print the
   handoff so the user can deploy.
4. Print a brief final summary: tickets shipped, tickets skipped + why, ADRs created, the headline
   pragmatic decisions, and the release version.

## Epic body template

```markdown
# EPIC: <title>

**Design:** [<design-path>](<design-path>)

## Summary
<2-3 sentences: what this epic delivers and why>

## Core principles
- <invariants every ticket must uphold — naming, contracts, design fidelity>

## Phased plan
**Phase 1 — <name>**
- [ ] #<sub> — <title>

**Phase 2 — <name>**
- [ ] #<sub> — <title>

## Decisions Log
<!-- append-only; newest last. One line per pragmatic or skip decision. -->
- **#<sub>:** <decision> — _why:_ <rationale> — _affects:_ #<a>, #<b> (or "none")
```

## Notes for the agent

- The **approval gate in step 1.7 is the only mid-run pause.** Everything after runs to completion
  without asking — the user reviews the finished work at the end.
- The Decisions Log is **append-only.** Don't rewrite earlier entries. An accepted ADR is likewise
  immutable — supersede with a new ADR, never edit in place.
- Resume safety: a ticket is "done" only when its box is checked and its PR is merged — read the
  epic's checklist state, not local git.
- Keep the design-doc link relative so it resolves in the repo; link the specific section anchor
  when a UI doc exposes one.
