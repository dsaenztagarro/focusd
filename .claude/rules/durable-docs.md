---
paths:
  - "docs/**/*.md"
---

# Durable prose records *why*, never what the code currently does

**The tests are the specification.** What the code does is stated by named tests; prose holds only what they cannot — the *why* ([`decision-records`](../../docs/adr/decision-records.md)).

**Never write a claim about the current state of the code into a durable doc.** No "not yet built", no migration status, no list of what is wired where. That belongs on an issue.

## The genres, and what each may hold

| genre | holds | never holds |
|---|---|---|
| **decision record** — [`docs/adr/`](../../docs/adr/README.md) | one theme's live decisions, the forks, the rejected options still worth stating, what was deliberately not built | a census of the code as it stood, a rollout plan, a ticket list, an alternative nobody would reach for again |
| **security** — [`docs/SECURITY.md`](../../docs/SECURITY.md) | the permission and secrets posture, and its rules | how the code achieves it, beyond naming the mechanism |
| **design input** — wherever the user points, never `docs/` | an input to an epic, written in the future tense | permanence — `/epic` deletes it at close-out |

Split a change across those owners: behaviour → tests, why → its theme record, commands → a README line, a multi-step procedure → a skill.

**The durable form of an open question is "Left open"** — a decision deliberately not made, with the condition that would reopen it. "Not yet done" is work status, and it does not belong here.

**A decision record is amended in place**, never superseded by a second file. Superseded reasoning, and any rejected option nobody would reach for again, go to the theme's `decision-log` issue; git history keeps the text.

## Before writing a behaviour rule in prose, ask what test would fail

Name the test that would fail if the rule were violated — then write that test, and stop.

## Style

- **ASCII diagrams only** — `+`, `-`, `|`, `v`, `^`, `>`.
- **One line per paragraph, or semantic line breaks** — never fixed-column hard wraps.
