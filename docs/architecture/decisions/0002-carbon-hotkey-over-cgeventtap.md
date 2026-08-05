# 0002. Capture the hotkey with Carbon `RegisterEventHotKey`, not a `CGEventTap`

**Status:** Accepted · **Scope:** hotkey capture / permissions · **Decision:** Register a single system hotkey via Carbon `RegisterEventHotKey` so the daemon needs no Accessibility/Input-Monitoring grant.

macOS offers two very different ways to run code on a global key press, and they sit on opposite sides of the privacy-permission boundary. Which one we pick decides whether the user ever has to open System Settings and grant a TCC permission — so it is worth recording *why* we chose the unprivileged one.

## Context

focusd must react to one key chord (⌘⌥Space, see [ADR 0003](0003-cmd-opt-space-keybinding.md)) no matter which app is focused. It is a background LaunchAgent with no window. The two capture mechanisms available are:

- **Carbon `RegisterEventHotKey`** — registers *one specific chord* with the WindowServer. The WindowServer matches the chord centrally and delivers a high-level `kEventHotKeyPressed` event to the registering process. The daemon never sees any other keystroke.
- **`CGEventTap`** (Quartz Event Services) — installs a tap in the event stream and sees *every* key event, which it can inspect, rewrite, or swallow.

Because a `CGEventTap` can observe the entire keyboard, macOS gates it behind the **Accessibility** (or Input Monitoring) TCC permission: a one-time manual grant in System Settings, which also resets on OS upgrades and when the binary's code signature changes. `RegisterEventHotKey` sees nothing but the chord it registered, so it needs **no** such grant.

We only ever need one chord. We do not need to read, block, or rewrite other keys.

## Decision

Use **Carbon `RegisterEventHotKey`**, targeting `GetApplicationEventTarget()`, with a `kEventClassKeyboard` / `kEventHotKeyPressed` handler installed via `InstallEventHandler`. Drive delivery with an `NSApplication` run loop in `.accessory` activation policy (headless, no Dock icon).

```
   key press (⌘⌥Space)
          |
          v
   +----------------+     matches the one registered chord
   |  WindowServer  |------------------------------------+
   +----------------+                                     |
          | everything else                               v
          v                                     kEventHotKeyPressed
   normal app delivery                                    |
                                                          v
                                            focusd handler -> toggleFocus()
```

The activation half — bringing the other app forward — uses `NSWorkspace.openApplication(at:configuration:)`, which is also unprivileged. **Net result: focusd requires zero TCC permissions to install and run.**

## Alternatives considered

- **`CGEventTap`.** More powerful: it could bind bare F-keys (including keys that emit system-defined events), consume the key so it never reaches the focused app, or implement chords/sequences. Rejected because it needs the Accessibility grant for a capability we do not use — a worse install experience (manual grant, breaks on re-sign/OS-upgrade) with no benefit for a single chord.
- **`NSEvent.addGlobalMonitorForEvents`.** Also requires Accessibility, and global monitors are *observe-only* — they cannot consume the event. Same permission cost, strictly less capable. Rejected.
- **Off-the-shelf daemon (skhd, Hammerspoon).** Solves the problem without any code, but this project is deliberately a from-scratch learning exercise in the native macOS APIs; a dependency defeats the purpose. See the README.

## Consequences

- **Easy:** install-and-go with no permission prompts; survives OS upgrades and re-signing without re-granting anything.
- **Hard / constrained:** the chord must be one `RegisterEventHotKey` can express — a real modifier plus a key code. It cannot bind a *bare* function key that the hardware turns into a system-defined event (brightness/media), which is one more reason ⌘⌥Space beats bare F1 in [ADR 0003](0003-cmd-opt-space-keybinding.md). The key is *consumed* by the registration, so the chosen chord is globally removed from every other app — acceptable because we pick a chord nothing else wants.
- **New obligation:** the run loop must actually run. If we ever drop `NSApplication.run()` for a leaner `CFRunLoop`, we must ensure Carbon events are still dispatched.

## References

- [ADR 0003](0003-cmd-opt-space-keybinding.md) — the chord we register and why.
- `docs/architecture/global-hotkey-daemon.md` — how the running daemon works.
- Apple: Carbon Event Manager `RegisterEventHotKey`; Quartz `CGEventTapCreate`; `NSWorkspace`.
