# focusd

A tiny macOS **global-hotkey daemon**, written from scratch in Swift. Press **Ctrl+T** anywhere to toggle focus between two apps — here, **Alacritty** (running Zellij) and **iTerm2** (running Herdr).

It exists as much to *learn the native macOS stack* as to switch windows: it's ~90 lines that touch global hotkeys, run loops, inter-app activation, `launchd` daemonization, and the macOS permission model — deliberately built from scratch instead of configuring [skhd](https://github.com/koekeishiya/skhd) or [Hammerspoon](https://www.hammerspoon.org/).

```
   Ctrl+T  ──────────────▶  focusd  ─────────────▶  the other terminal comes forward
 (from anywhere)          (background agent)        Alacritty ⇄ iTerm2
```

## What it does

- Registers **one** global hotkey with the macOS WindowServer.
- On press, reads which app is frontmost and **activates the other** of the two (launching it if needed).
- Runs as a headless **LaunchAgent** — starts at login, no Dock icon, restarts if it dies.
- Needs **no Accessibility / Input-Monitoring permission** (see [Why no permissions](#why-no-permissions-the-key-design-choice)).

## Quick start

```bash
git clone https://github.com/dsaenztagarro/focusd.git
cd focusd
make install        # builds, installs the LaunchAgent, and loads it
# → press Ctrl+T to flip between Alacritty and iTerm2
make logs           # watch toggles as they happen
make uninstall      # remove it
```

Requires the Swift toolchain (Xcode or the Command Line Tools: `xcode-select --install`).

## What you can learn from this repo

This is the interesting part — the concepts generalize far beyond one hotkey:

1. **How a global hotkey is even possible.** macOS gives you two mechanisms on opposite sides of the privacy boundary: Carbon **`RegisterEventHotKey`** (register one chord with the WindowServer; needs no permission) vs. a **`CGEventTap`** (see the whole keyboard stream; needs an Accessibility grant). focusd uses the first. → [ADR 0002](docs/architecture/decisions/0002-carbon-hotkey-over-cgeventtap.md)
2. **Run loops.** A windowless program still needs an event loop to receive anything. focusd uses `NSApplication.run()` in `.accessory` policy — the same loop that delivers the Carbon hotkey event, minus the Dock icon.
3. **Inter-app control.** `NSWorkspace.frontmostApplication` to read focus, `NSWorkspace.openApplication(at:configuration:)` to bring another app forward — the modern "open-or-activate" call, unprivileged.
4. **C-interop from Swift.** The Carbon event handler is a `@convention(c)` callback that can't capture Swift state; virtual key codes and Carbon modifier masks are a different encoding from `NSEvent` flags. This is a compact, real example of bridging to a C framework.
5. **Daemonization the Apple way.** A `launchd` **LaunchAgent** plist with `RunAtLoad`/`KeepAlive`, why it must be a *per-user agent* (GUI session) and not a system daemon, and why `launchd` won't expand `~` in its paths (so `make install` substitutes absolutes). `brew services` is just a wrapper over this.
6. **The keybinding is an analysis, not a taste — and it can still be wrong.** Bare F1 collides with Neovim's DAP bindings; ⌘-modified keys never reach a terminal TUI, so the first pick was ⌘⌥Space — which turned out to *also* be macOS's Finder-search shortcut and won the race in practice. The toggle moved to Ctrl+T (no macOS shortcut at all). Two ADRs capture the reasoning *and the reversal*: [0003](docs/architecture/decisions/0003-cmd-opt-space-keybinding.md) → [0004](docs/architecture/decisions/0004-rebind-to-ctrl-t.md).

## How it works

Everything is in `Sources/focusd/main.swift`:

```
  launchd (LaunchAgent, GUI session)
        |  RunAtLoad / KeepAlive
        v
  focusd
   1. RegisterEventHotKey(Ctrl+T)         --> WindowServer matches the chord
      InstallEventHandler(kEventHotKeyPressed) --> C callback -> toggleFocus()
   2. NSApplication.run() (.accessory)    --> run loop, no Dock icon
        |
        |  Ctrl+T pressed anywhere
        v
   3. front  = NSWorkspace.frontmostApplication.bundleIdentifier
      target = (front == Alacritty) ? iTerm2 : Alacritty
      NSWorkspace.openApplication(target, activates: true)
```

The full walkthrough — with failure modes — is in [`docs/architecture/global-hotkey-daemon.md`](docs/architecture/global-hotkey-daemon.md).

## Why no permissions (the key design choice)

Most hotkey tools ask you to grant **Accessibility** in System Settings. focusd doesn't, because it never needs to *see* your keystrokes — it registers a single chord with the WindowServer and gets a "that chord fired" event back. That is the entire reason to prefer `RegisterEventHotKey` over a `CGEventTap` here: same result for one chord, none of the permission cost (which also breaks on OS upgrades and re-signing). Activating apps via `NSWorkspace` is unprivileged too. The trade-off — and what a `CGEventTap` would buy you — is written up in [ADR 0002](docs/architecture/decisions/0002-carbon-hotkey-over-cgeventtap.md).

## Why Ctrl+T

A global hotkey is *consumed* before the focused app sees it, so the chord must not collide with the surrounding toolchain. The candidates, and why most lose:

| Chord | Owner | Verdict |
|-------|-------|---------|
| F1–F5, F10–F12 | Neovim DAP (debugger) | ✗ hijacks "continue" etc. |
| Ctrl+Space | Zellij / Herdr prefix | ✗ core multiplexer key |
| ⌘Space | Alfred | ✗ launcher |
| Bare F-keys | hardware brightness/media | ✗ not capturable via `RegisterEventHotKey` without a settings change |
| ⌘⌥Space | macOS "Show Finder search window" | ✗ races focusd → lands on Finder (only "free" after disabling that shortcut *and* a re-login) |
| **Ctrl+T** | *(nothing on this setup)* | ✓ no macOS shortcut; unused by fzf / Zellij / nvim / zsh here |

⌘⌥Space was the original, reasoned choice ([ADR 0003](docs/architecture/decisions/0003-cmd-opt-space-keybinding.md)) — until it collided with macOS's Finder-search shortcut in practice. **Ctrl+T** ([ADR 0004](docs/architecture/decisions/0004-rebind-to-ctrl-t.md)) trades the "⌘ never reaches a TUI" safety of a Command chord for something better here: **no macOS system shortcut at all**, so no race and no per-machine settings dependency. The cost — Ctrl+T is a non-⌘ key, so it's consumed globally *inside* terminals too — is acceptable because nothing in this environment binds it (the only casualty is vim's niche `Ctrl+T` tag-pop).

## Configuring

Both the apps and the chord are constants at the top of `Sources/focusd/main.swift`:

```swift
private let appA = "org.alacritty"          // resolve with: osascript -e 'id of app "AppName"'
private let appB = "com.googlecode.iterm2"
private let hotKeyCode = UInt32(kVK_ANSI_T)         // virtual key code
private let hotKeyModifiers = UInt32(controlKey)
```

Change them and `make reload`. To toggle two different apps, swap the bundle IDs; to rebind, change the key code / modifier mask.

## Troubleshooting

- **If you rebind to ⌘⌥Space, it opens Finder / bounces you to the Desktop** (even though `make logs` shows the `toggle:` firing). This is why the default is Ctrl+T — but if you switch back to ⌘⌥Space, know that macOS's built-in **"Show Finder search window"** shortcut is *also* ⌘⌥Space, and the system-level shortcut races focusd, winning often enough that you land on Finder. The catch: disabling it via `defaults`/System Settings only takes effect after the **next login**, so a machine that hasn't re-logged-in still has it live. Confirm it's the culprit by unloading focusd (`make uninstall`) and pressing ⌘⌥Space — if Finder still opens, it's macOS, not focusd. Fix it one of these ways:
  - **System Settings** → Keyboard → Keyboard Shortcuts → **Spotlight** → uncheck *"Show Finder search window."* Applies immediately, no re-login.
  - **CLI, applied live** (writes the full-form disable and reloads settings):
    ```bash
    defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 65 \
      '{ enabled = 0; value = { parameters = ( 32, 49, 1572864 ); type = standard; }; }'
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
    ```
  - **Log out and back in** if you'd rather just re-read the setting you already have on disk.
  - Or just stay on the default **Ctrl+T**, which macOS never claims — see [ADR 0004](docs/architecture/decisions/0004-rebind-to-ctrl-t.md).
- **Nothing happens at all on Ctrl+T.** Check the log (`make logs`). `RegisterEventHotKey failed` means another app owns the chord; `registered hotkey` with no `toggle:` lines means it's intercepted upstream. Rebind (above) or free the chord.
- **It toggles but the app doesn't come forward.** Confirm the bundle IDs with `osascript -e 'id of app "Alacritty"'`.
- **Doesn't start at login.** `launchctl list | grep local.focusd` should show it; re-run `make install`.

## Layout

```
.
├── Sources/focusd/main.swift     # the whole daemon
├── Package.swift                 # SwiftPM executable, macOS 14+
├── Makefile                      # build / install / reload / uninstall / logs
├── launchd/local.focusd.plist    # LaunchAgent template
├── AGENTS.md · CLAUDE.md         # AI-agent instructions (single source of truth)
└── docs/
    ├── architecture/
    │   ├── global-hotkey-daemon.md          # how-it-works explainer
    │   └── decisions/                        # ADRs (0002 mechanism, 0003 keybinding)
    ├── guides/ · features/                   # docs taxonomy
    └── SECURITY.md
```

## Credits

Scaffolded on the [ai-engineering-template](https://github.com/dsaenztagarro/ai-engineering-template) — the docs taxonomy, ADR practice, and the `template-feedback` / `epic` skills come from there.

## License

[MIT](LICENSE) © David Saenz
