# The global-hotkey daemon

*How focusd actually works today.* Complementary to [ADR 0002](decisions/0002-carbon-hotkey-over-cgeventtap.md) (why Carbon, not an event tap) and [ADR 0003](decisions/0003-cmd-opt-space-keybinding.md) (why ⌘⌥Space); this records *how* the running program behaves so the mental model can be rebuilt without reading all the code.

## The mental model

focusd is a windowless background agent with a single job: when a globally-registered chord is pressed, activate whichever of two apps is *not* currently frontmost. It is an event handler bolted onto a run loop. The one idea that makes everything else fall into place: **the WindowServer does the key matching for us and hands us a single high-level "the hotkey fired" event** — so the program is tiny and needs no privileged access to the keyboard.

Everything lives in one file, `Sources/focusd/main.swift`, under ~90 lines.

## How it works

```
  launchd (LaunchAgent, GUI session)
        |  RunAtLoad / KeepAlive
        v
  focusd process
   1. installHotKey():
        RegisterEventHotKey(Cmd+Opt+Space) --> registers chord with WindowServer
        InstallEventHandler(...)           --> our C callback for kEventHotKeyPressed
   2. NSApplication.run() (.accessory)     --> run loop; no Dock icon
        |
        |   ⌘⌥Space pressed anywhere
        v
   3. handler -> toggleFocus()
        front = NSWorkspace.frontmostApplication.bundleIdentifier
        target = (front == appA) ? appB : appA
        focus(target):
           url = urlForApplication(target)
           NSWorkspace.openApplication(url, activates: true)  --> app comes forward
```

Walking the pieces:

- **`installHotKey()`** — builds an `EventHotKeyID`, registers ⌘⌥Space (`kVK_Space` + `cmdKey|optionKey`) against `GetApplicationEventTarget()`, and installs a `kEventClassKeyboard` / `kEventHotKeyPressed` handler. The handler is a `@convention(c)` callback, so it captures no Swift state and simply calls the top-level `toggleFocus()`.
- **The run loop** — `NSApplication.shared.run()` with `setActivationPolicy(.accessory)`. The run loop is what lets the WindowServer deliver the hotkey event; `.accessory` keeps focusd out of the Dock and app switcher. focusd never activates *itself*.
- **`toggleFocus()`** — reads the frontmost app's bundle id and picks the other of the two. From a third app (a browser, say) it lands on `appA`.
- **`focus(bundleID:)`** — resolves the app URL and calls `NSWorkspace.openApplication(at:configuration:)` with `activates = true`. This one call both launches the app if it isn't running and activates it if it is. No Accessibility permission is involved at any step.

The two apps are compile-time constants at the top of `main.swift` (`appA = org.alacritty`, `appB = com.googlecode.iterm2`); the chord is the two constants `hotKeyCode` / `hotKeyModifiers`.

Packaging: `make install` compiles a release binary to `~/.local/bin/focusd`, renders `launchd/local.focusd.plist` (substituting the absolute binary and log paths launchd can't expand) into `~/Library/LaunchAgents/`, and loads it. Logs go to `~/Library/Logs/local.focusd.log`.

## Failure modes

- **`RegisterEventHotKey` returns non-`noErr`** → another process or an *enabled* system shortcut already owns the chord. focusd logs the `OSStatus` and keeps running (but the hotkey won't fire). On this environment the contending shortcut (Finder search, id 65) is disabled by `macos_defaults.sh`; elsewhere it may need disabling. See [ADR 0003](decisions/0003-cmd-opt-space-keybinding.md).
- **Target app not installed** → `urlForApplication` returns nil; `focus()` logs `app not installed` and does nothing.
- **Daemon crashes/exits** → `KeepAlive` in the LaunchAgent relaunches it.
- **It's a LaunchDaemon by mistake** → a system-context daemon has no WindowServer session, so the hotkey and activation silently do nothing. focusd must be a per-user **LaunchAgent** (it is).

## See also

- [ADR 0002](decisions/0002-carbon-hotkey-over-cgeventtap.md) — Carbon vs. `CGEventTap` and the permission story.
- [ADR 0003](decisions/0003-cmd-opt-space-keybinding.md) — the ⌘⌥Space choice.
- `README.md` — install/build/learning walkthrough.
