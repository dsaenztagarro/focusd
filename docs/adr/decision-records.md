# Decision records

**Status:** Accepted · **Decision log:** [#5](https://github.com/dsaenztagarro/focusd/issues/5)

How this project writes things down: which artefact owns which kind of fact, and why every document an agent reads grows with the product's areas rather than with its work.

## Context

focusd is small, and agents do much of its work. Every durable document is loaded into an agent's context alongside the code, so a document that restates the code is a second copy that nothing checks, and a corpus that grows by one file per decision or feature stops being read long before anyone notices. The project began with numbered, immutable ADRs plus a how-it-works explainer per mechanism; four records in, one ADR already existed only to say the previous one was wrong, and the explainer repeated the code's own comments.

## Decisions

### One owner per fact

What the code does is stated by **tests** named for the rules they hold. Why it is built this way is a theme's **record** in `docs/adr/`. Commands to build, install and operate it are a line in the **README**, and a multi-step procedure is a **skill**. What is still open is an **issue**. How permissions and secrets are handled is `docs/SECURITY.md`.

### Prose records *why*, never *what the code currently does*

A claim about code state in a durable doc is born rotting. A hard-to-follow mechanism is made clear in the code and its comments; a non-obvious failure mode gets a named test or a README troubleshooting line. The durable form of an open question is **Left open** — a decision deliberately not made, with the condition that would reopen it. "Not yet done" is work status and belongs on an issue.

### A record is one per theme, amended in place

A decision amends the record that owns its theme — a reversal, an extension or a refinement alike — and adds one dated line to the theme's `decision-log` issue. The record carries no history; git does. [The README](README.md) carries the themes, the bar and the format.

### An input is deleted once what it produced ships

A design doc or a review is an input to an epic, written outside `docs/`. Its durable half moves to a record, a test or an issue first; then it goes, and git keeps the text.

## Rejected

- **Numbered ADRs, immutable, superseded by new files.** Optimises for an audit trail git already provides, and shelves a wrong decision next to the right one.
- **How-it-works explainers.** A third copy beside the code and the tests that nothing checks; an explanation is given from the current code when asked.
- **A doc page per feature or per guide.** Its whole content is a narrative of current behaviour, so the folder is born rotting.
- **Tests over the documents** (a file exists, a table matches a folder). They specify paperwork; review holds the documents.

## References

Decision log: [#5](https://github.com/dsaenztagarro/focusd/issues/5) · Rules: [`.claude/rules/durable-docs.md`](../../.claude/rules/durable-docs.md), [`AGENTS.md`](../../AGENTS.md)
