# 0004. Rebind the focus toggle to Ctrl+T

**Status:** Accepted · **Scope:** hotkey chord · **Decision:** Toggle with Ctrl+T, superseding the ⌘⌥Space of [ADR 0003](0003-cmd-opt-space-keybinding.md).

[ADR 0003](0003-cmd-opt-space-keybinding.md) chose ⌘⌥Space and flagged, as its one risk, that the choice "depends on Finder-search staying disabled." That risk materialized. This ADR records the reversal: what went wrong, and why Ctrl+T is the better chord *for this environment* despite being a non-⌘ key.

## Context

⌘⌥Space is also macOS's built-in **"Show Finder search window"** shortcut (symbolic hotkey id 65). Although the environment's `macos_defaults.sh` writes that shortcut disabled, **symbolic-hotkey changes only take effect after the next login** — so on a running session that hasn't re-logged-in, macOS still owns ⌘⌥Space and races focusd for it. Observed symptom: pressing the chord fired focusd (the log showed the correct toggle) *and* opened Finder-search, so focus landed on the Finder/Desktop. Confirmed by unloading focusd entirely — ⌘⌥Space still opened Finder with nothing of ours running.

That makes ⌘⌥Space depend on a **fragile, per-machine system-settings state**: correct only after a re-login, re-broken by an OS upgrade that resets the shortcut, and invisible until it bites. The user also asked for something simpler to press than a three-key chord.

The key structural fact from ADR 0002/0003 still holds: a registered hotkey is *consumed*, so whatever we bind is removed from every app globally. ⌘-based chords never reach a terminal's TUI (the emulator eats ⌘ for menus), which is why ADR 0003 preferred them. Ctrl+T is the opposite — it flows into the terminal — so binding it globally takes it away from the shell/nvim/Zellij too. That cost is only acceptable if nothing in the environment actually uses Ctrl+T.

Checked, and it's clear here:

| Potential Ctrl+T user | Status on this setup |
| --------------------- | -------------------- |
| macOS symbolic hotkey | none — **no OS shortcut on Ctrl+T** (verified: with focusd off, Ctrl+T does nothing) |
| fzf shell widget (`^T`) | not sourced in zsh — inactive |
| Zellij | `keybinds clear-defaults=true`, no `Ctrl t` binding |
| nvim | no `<C-t>` mapping |
| zsh line editor | `bindkey -v` (vi mode) — `transpose-chars` (`^T`) not bound |

## Decision

Bind **Ctrl+T** (`kVK_ANSI_T` + Carbon `controlKey`). It:

- **Has no macOS system shortcut**, so it needs no system-settings change and can't lose a race with Finder-search — the entire failure mode of ADR 0003 disappears, and it works the same on a fresh machine with no re-login.
- **Is simpler to press** (two keys, one hand) than ⌘⌥Space.
- **Is unclaimed in this environment** (table above), so the global consumption costs nothing in active use.

Verified end-to-end: with focusd off, Ctrl+T is inert at the OS level; with focusd on, Ctrl+T flips iTerm2 ⇄ Alacritty and never lands on Finder.

## Alternatives considered

- **Keep ⌘⌥Space, disable Finder-search properly (ADR 0003 + a re-login).** Rejected: it works, but re-introduces the exact fragile, per-machine, invisible-until-it-breaks dependency this ADR is removing. Portability and "works after `make install` with no OS fiddling" won.
- **A different ⌘-based chord, e.g. ⌘⌥Return.** Genuinely conflict-free (⌘ never reaches the TUI; no macOS shortcut) and was verified free. Rejected only on ergonomics — it's still a three-key chord; the user wanted fewer keys. This remains the fallback if a Ctrl+T collision ever appears.
- **A bare function key (F6–F9).** Rejected in ADR 0003 already (hardware media keys; `RegisterEventHotKey` can't capture a key that emits a system-defined event); unchanged here.

## Consequences

- **Easy:** no dependency on any macOS setting; identical behavior across machines; a shorter chord.
- **Hard / watch out:** Ctrl+T is now globally consumed, so it's gone *inside* terminals too. The only real loss in this environment is vim's built-in **Ctrl+T (pop tag stack)** — niche given the nvim setup leans on LSP/Telescope. If a future tool starts using Ctrl+T (a REPL, a new shell widget, restoring emacs line-editing), it won't receive it; rebind then (two constants in `Sources/focusd/main.swift`), and ⌘⌥Return is the ready fallback.
- **Note:** the ⌘⌥Space Finder-search disable already applied to the machine is left in place — it reflects the dotfiles' own intent to free the Spotlight/Finder Space cluster, and no longer has anything to do with focusd.

## References

- Supersedes [ADR 0003](0003-cmd-opt-space-keybinding.md) — the original ⌘⌥Space decision and its Space-cluster analysis.
- [ADR 0002](0002-carbon-hotkey-over-cgeventtap.md) — why a registered hotkey is consumed (the constraint that makes chord choice matter).
- `docs/architecture/global-hotkey-daemon.md` — how the running daemon works.
- Environment sources: `~/.config/zsh` (fzf/bindkey), `~/.config/zellij/config.kdl`, `~/.config/nvim`.
