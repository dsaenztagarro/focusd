# Architecture docs

Two kinds of document live here, and the distinction matters:

- **Decisions** (`decisions/`) — **why** the system is built the way it is. One Architecture Decision Record per significant, non-obvious fork: the decision, the rejected alternatives, the consequences. Immutable once accepted. See [`decisions/README.md`](decisions/README.md).
- **Explainers** (`*.md` in this folder) — **how** a mechanism actually works today. A plain-language, current-state description of a subsystem so a maintainer (or a future agent) can rebuild the mental model without reverse-engineering the code.

```
why  -> docs/architecture/decisions/NNNN-*.md   (ADR: the fork and its rationale, immutable)
how  -> docs/architecture/*.md                  (explainer: the mechanism as it works now, living)
do X -> docs/guides/*.md                         (how-to)
```

They are complementary. A non-trivial mechanism usually has **both**: an ADR that records the decision behind it, and an explainer that records how the resulting machine behaves — cross-linked both ways.

## Writing an explainer

Use [`EXPLAINER-TEMPLATE.md`](EXPLAINER-TEMPLATE.md). Keep it legible: the mental model in a paragraph, the interactions/states, the failure modes, an ASCII diagram where one helps, and links to the key files and the related ADR.

**When you build or materially change a mechanism, write or update its explainer in the same change** — this is enforced by `AGENTS.md`, so the doc never drifts from the code.
