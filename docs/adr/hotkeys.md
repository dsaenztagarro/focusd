# Hotkeys

**Status:** Accepted · **Decision log:** [#6](https://github.com/dsaenztagarro/focusd/issues/6)

How a key press becomes a focus change: how the key is captured, what that costs in permissions, which keys are bound, and what a press does.

## Context

focusd is a windowless per-user background agent. It must react to a key press no matter which app is focused, and then bring another app forward.

macOS offers two capture mechanisms on opposite sides of the privacy boundary:

- **Carbon `RegisterEventHotKey`** registers one specific chord with the WindowServer. The WindowServer matches it centrally and delivers a high-level `kEventHotKeyPressed` event; the process never sees any other keystroke.
- **`CGEventTap`** sees *every* key event and can inspect, rewrite or swallow it. Because it can observe the whole keyboard, macOS gates it behind the Accessibility / Input Monitoring TCC grant: a manual step in System Settings that resets on OS upgrades and on re-signing.

The keyboard in daily use is an HHKB Hybrid. Its `Fn` key is a layer inside the keyboard's firmware: it never reaches macOS, and Fn plus a number row key arrives as a plain function key with no modifier.

Whichever key is registered is **consumed**: the WindowServer delivers it to focusd and to no other app. Choosing a key therefore means choosing what to take away from everything else, and the environment decides that:

- Terminal emulators eat ⌘-modified keys for their menus, so a ⌘ chord never reaches a TUI. F-keys, Ctrl and Alt do reach it — nvim, Zellij (in Alacritty) and Herdr (in iTerm2) all bind Ctrl/Alt chords.
- A macOS symbolic hotkey on the same chord races the registration, and disabling one only takes effect after the next login.

## Decisions

### Capture with Carbon `RegisterEventHotKey`, never an event tap

focusd needs to recognise a fixed set of chords, never to read, block or rewrite other keys. `RegisterEventHotKey` does exactly that with **zero TCC permissions**, and activation through `NSWorkspace.openApplication` is unprivileged too, so install-and-go needs no System Settings step and survives upgrades and re-signing. The price is that a binding must be expressible as a modifier mask plus a virtual key code.

```
   key press
       |
       v
  +--------------+   matches a registered chord
  | WindowServer |-------------------------------+
  +--------------+                               |
       | everything else                         v
       v                               kEventHotKeyPressed
  normal app delivery                            |
                                                 v
                                     focusd handler -> focus change
```

### It runs as a per-user LaunchAgent on an `NSApplication` run loop

Hotkey events are only delivered while a run loop pumps; `NSApplication.run()` in `.accessory` policy provides one without a Dock icon. A system LaunchDaemon has no WindowServer session, so the hotkey and the activation would silently do nothing: focusd is a LaunchAgent with `KeepAlive`.

### Ctrl+T flips between the two terminals

Ctrl+T toggles Alacritty (Zellij) and iTerm2 (Herdr); from any third app it lands on Alacritty. It has no macOS system shortcut, so no setting or re-login is involved, and it is two keys under one hand. Being a Ctrl chord it is taken from the shell, nvim and the multiplexers too; nothing in the environment binds it, and the one real loss is vim's tag-stack pop.

### Fn+N on the HHKB jumps straight to an app, by importance

The Fn-layer function keys are registered bare, one per app, ordered so the most-used app sits on the lowest number: the two terminals first, then the browser, mail and chat. The browser slot resolves the system's default browser at press time rather than naming one, so changing browsers needs no rebuild.

A slot means "be in this app": pressing the slot of the frontmost app leaves it there. Ctrl+T already owns the back-and-forth flip, so a slot that also flipped would be a second way to do the same thing.

Every bound key is taken from every app, so a function key is bound only once it has an app; the unassigned ones still reach the apps that use them. nvim's debugger keeps its stepping keys on a leader group in the dotfiles, off the function keys, so the slots keep the importance order from 1.

## Rejected

- **`CGEventTap`** — could bind keys Carbon cannot, but costs the Accessibility grant for a capability not used.
- **`NSEvent.addGlobalMonitorForEvents`** — the same grant, and observe-only: it cannot consume the key.
- **skhd / Hammerspoon** — solves it with no code, but focusd is deliberately built on the native APIs.
- **⌘⌥Space** — conflict-free inside terminals, but it is also macOS's Finder-search shortcut and lost the race until a re-login.
- **A Hyper key (⌘⌃⌥⇧)** — the most collision-proof class, but unpressable without a Karabiner remap.
- **Slots on a modifier chord (⌥ + F-key)** — keeps the debugger's keys, but Alt still reaches the TUI and it gives back the one-chord ergonomics the Fn layer offers.
- **A slot that flips back when its app is frontmost** — duplicates Ctrl+T.

## Left open

- **The slots assume the HHKB's layer.** On an Apple keyboard a function key emits a media event unless "Use F1, F2 as standard function keys" is on, so `RegisterEventHotKey` never sees it; typing on a non-HHKB keyboard would reopen how the slots are reached, most likely with a modifier.

- **⌘⌥Return is the fallback chord** if anything starts binding Ctrl+T (a REPL, an fzf widget, emacs line editing in zsh): verified free, and ⌘ never reaches a TUI. It lost only on ergonomics.
- **Replacing `NSApplication.run()` with a bare `CFRunLoop`** would be leaner, and is open as long as Carbon events are still dispatched.

## References

Decision log: [#6](https://github.com/dsaenztagarro/focusd/issues/6) · Code: `Sources/focusd/main.swift` · Apple: Carbon Event Manager `RegisterEventHotKey`, Quartz `CGEventTapCreate`, `NSWorkspace`
