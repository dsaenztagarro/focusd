# 0003. Bind the focus toggle to ⌘⌥Space

**Status:** Superseded by [0004](0004-rebind-to-ctrl-t.md) · **Scope:** hotkey chord · **Decision:** Toggle with ⌘⌥Space (Command+Option+Space), not a bare function key.

> **Superseded by [ADR 0004](0004-rebind-to-ctrl-t.md):** in practice ⌘⌥Space collided with macOS's "Show Finder search window" shortcut (a system shortcut that only frees up after a re-login), so the toggle moved to Ctrl+T. The analysis below is preserved as the original reasoning.

The chord is the whole user interface of this tool, and the "obvious" choice (F1) is actively wrong on this setup. The reasoning is non-obvious enough — it depends on what other tools in the environment already claim — to be worth recording.

## Context

A global hotkey registered with the WindowServer is consumed *before* the focused app sees it (see [ADR 0002](0002-carbon-hotkey-over-cgeventtap.md)). So whatever chord we pick is removed from every other app, everywhere. The binding must therefore avoid anything the surrounding tools rely on. The environment this runs in:

- **Neovim** binds **F1–F5 and F10–F12** to the DAP debugger (continue, step over/into/out, etc.). A global F1 would hijack "continue" every time nvim is focused.
- **Zellij** (in Alacritty) uses **Ctrl+Space** as its tmux-style prefix and a wall of **Alt+letter** chords.
- **Herdr** (in iTerm2) mirrors Zellij: **Ctrl+Space** prefix plus `prefix+<key>`.
- **macOS**, on this machine, already reassigns the Space-family launcher chords: **⌘Space → Alfred** (Spotlight disabled), **⌃Space → Zellij** (input-source switch disabled). Crucially, **⌘⌥Space** (the "Finder search window" shortcut, symbolic-hotkey id 65) is **disabled** by the machine's `macos_defaults.sh`, leaving that slot free.

There are two structural facts that make the choice fall out cleanly:

1. **Terminal emulators do not forward ⌘-modified keys to the TUI.** iTerm2/Alacritty consume ⌘ for their own menus, so a ⌘-based chord can never collide with anything running *inside* the terminal (nvim, Zellij, Herdr). Only F-keys, Ctrl, and Alt reach the TUI. So the entire class of "⌘ + something the emulators don't claim" is conflict-free with the terminal contents.
2. **A bare function key is doubly disqualified:** it collides with nvim's DAP bindings, *and* with `RegisterEventHotKey` it can't even be captured when the key emits a hardware system-defined event (brightness/media) rather than a plain F-key code — which is the default unless "Use F1, F2 as standard function keys" is enabled.

## Decision

Bind **⌘⌥Space**. It is:

- **Provably free here** — the one macOS shortcut on that chord (Finder search, id 65) is already disabled by this environment's `macos_defaults.sh`.
- **Zero-conflict with terminal contents** — ⌘ never reaches nvim/Zellij/Herdr.
- **Permission-free and setting-free** — expressible by `RegisterEventHotKey` (a real modifier + a key code), so no Accessibility grant and no "standard function keys" toggle (unlike bare F-keys).
- **Mnemonically consistent** — it extends the machine's existing Space-launcher family: `⌘Space` = launcher (Alfred), `⌃Space` = multiplexer (Zellij), **`⌘⌥Space` = app toggle**.

Verified end-to-end: with the daemon running, a synthesized ⌘⌥Space fired the toggle (`front=com.googlecode.iterm2 -> org.alacritty`).

The chord is a two-constant change in `Sources/focusd/main.swift` (`hotKeyCode`, `hotKeyModifiers`) — rebinding is trivial.

## Alternatives considered

- **F1 (the original request).** Rejected: collides with nvim DAP "continue", and bare F1 needs either the standard-function-keys setting or an event tap to capture.
- **A free F-key (F6–F9).** F6–F9 dodge the DAP bindings, but still carry the hardware/system-defined-event problem and the "standard function keys" dependency. Weaker than a modifier chord.
- **A Hyper key (⌘⌃⌥⇧).** The most collision-proof class, but ergonomically hostile without a Karabiner remap, which isn't installed. Rejected as over-engineering for a two-app toggle.
- **Per-app keys (F1→Alacritty, F2→iTerm2).** More keys to remember for two apps, and inherits every F-key problem above. The user chose a single toggle. Rejected.

## Consequences

- **Easy:** one-hand chord, no permissions, no global keyboard-setting change, no muscle-memory collisions with the daily toolchain.
- **Hard / watch out:** the "provably free" argument *depends on* Finder-search (symbolic hotkey 65) staying disabled. On a machine where `macos_defaults.sh` hasn't run, macOS may still own ⌘⌥Space and contend with the registration. Documented in the README's install notes.
- **Open:** the two toggled apps are currently compile-time constants (`org.alacritty`, `com.googlecode.iterm2`). If focusd grows to N apps or a config file, revisit whether a single toggle is still the right model.

## References

- [ADR 0002](0002-carbon-hotkey-over-cgeventtap.md) — why the capture mechanism constrains which chords are even possible.
- `docs/architecture/global-hotkey-daemon.md` — the toggle flow.
- Environment sources: `~/.config/nvim/lua/plugins/dap.lua`, `~/.config/zellij/config.kdl`, `~/.config/herdr/config.toml`, `~/Code/dotfiles/bin/macos_defaults.sh`.
