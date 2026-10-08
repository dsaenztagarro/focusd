# Decision records

**A few broad themes, not a record per decision.**
A new decision amends the record that owns its theme; it does not open a sibling.
Each record answers the question a future maintainer actually asks — *why is it built this way?* — which is the one thing a closed pull request throws away.

| Record | Owns | Decision log |
|---|---|---|
| [Decision records](decision-records.md) | how this project records decisions, behaviour and instructions | [#5](https://github.com/dsaenztagarro/focusd/issues/5) |
| [Hotkeys](hotkeys.md) | how a key press becomes a focus change — capture, permissions, chords, what a press does | [#6](https://github.com/dsaenztagarro/focusd/issues/6) |

A record is named for its theme, not numbered: it is amended in place, so an order of creation says nothing, and a citation reads as the theme it points at.
A theme is drawn wide enough that the next decision in its area lands in it.
A decision that fits none is a new theme, and that is the maintainer's call: its record argues, in its own context section, why the decision fits no existing theme.
An `ADR NNNN` met in an old commit or pull request names a numbered record since folded into one of these themes; [#5](https://github.com/dsaenztagarro/focusd/issues/5) maps each number to its theme.

## The bar

A record holds reasoning that is not recoverable from the code. A decision earns a place only if all three hold:

- **A real fork.** There were at least two defensible options and one was chosen.
- **Consequence beyond the change.** A permission boundary, a key taken from every other app, a thing deliberately *not* built. Not a local code choice, however careful.
- **Nothing else can hold it.** Behaviour belongs in tests, a command in the README. A record is for the part neither holds: the reasoning.

## Format

Each record states what is **currently believed**, not how the project got here.

- **Status:** Accepted · **Decision log:** the theme's issue, then one or two sentences on what the theme decides.
- **Context · Decisions · Rejected · Left open · References.** A decision is a `###` heading stating the position, and a few sentences on what it rules out.
- **A rejected option earns its line only if someone would reach for it tomorrow.** One line: the option, and why it lost.
- **A fork deliberately left open always stays**, with the condition that would reopen it.
- Diagrams are ASCII; prose is one line per paragraph or semantic line breaks.

## On immutability

Immutability exists to stop a decision being silently rewritten so no reader can tell it changed.
A themed record keeps that property by a different mechanism: an amendment *replaces* a rule and adds one dated line to the theme's `decision-log` issue — what changed, and why, linking the commit — and git holds the prior wording. `git log --follow -p docs/adr/<theme>.md` is the history a chain of superseded files was only approximating.

What stays forbidden is changing a position without logging it.
