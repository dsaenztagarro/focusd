# focusd

A tiny macOS **global-hotkey daemon**, written from scratch in Swift. Press **Ctrl+T** anywhere to toggle focus between two apps — here, **Alacritty** (running Zellij) and **iTerm2** (running Herdr) — or **Fn+1…Fn+5** on an HHKB to jump straight to an app.

It exists as much to *learn the native macOS stack* as to switch windows: it's a small Swift program that touches global hotkeys, run loops, inter-app activation, `launchd` daemonization, and the macOS permission model — deliberately built from scratch instead of configuring [skhd](https://github.com/koekeishiya/skhd) or [Hammerspoon](https://www.hammerspoon.org/).

```
   Ctrl+T ----------+                       +--> the other terminal (Alacritty <-> iTerm2)
                    +--> focusd (agent) ----+
   Fn+1..Fn+5 ------+                       +--> that slot's app (iTerm2, Alacritty, browser, ...)
 (from anywhere)
```

## What it does

- Registers a handful of global hotkeys with the macOS WindowServer.
- On **Ctrl+T**, reads which app is frontmost and **activates the other** of the two terminals.
- On **Fn+N**, activates that slot's app; pressing the slot of the app already in front leaves it there.
- Launches the target app if it isn't running.
- Runs as a headless **LaunchAgent** — starts at login, no Dock icon, restarts if it dies.
- Needs **no Accessibility / Input-Monitoring permission** (see [Why no permissions](#why-no-permissions-the-key-design-choice)).

## Quick start

```bash
git clone https://github.com/dsaenztagarro/focusd.git
cd focusd
make install        # builds, installs the LaunchAgent, and loads it
# → press Ctrl+T to flip between Alacritty and iTerm2; add slots in the config (below)
make logs           # watch toggles as they happen
make uninstall      # remove it
```

Requires the Swift toolchain (Xcode or the Command Line Tools: `xcode-select --install`).

## What you can learn from this repo

This is the interesting part — the concepts generalize far beyond one hotkey:

1. **How a global hotkey is even possible.** macOS gives you two mechanisms on opposite sides of the privacy boundary: Carbon **`RegisterEventHotKey`** (register one chord with the WindowServer; needs no permission) vs. a **`CGEventTap`** (see the whole keyboard stream; needs an Accessibility grant). focusd uses the first. → [hotkeys record](docs/adr/hotkeys.md)
2. **Run loops.** A windowless program still needs an event loop to receive anything. focusd uses `NSApplication.run()` in `.accessory` policy — the same loop that delivers the Carbon hotkey event, minus the Dock icon.
3. **Inter-app control.** `NSWorkspace.frontmostApplication` to read focus, `NSWorkspace.openApplication(at:configuration:)` to bring another app forward — the modern "open-or-activate" call, unprivileged.
4. **C-interop from Swift.** The Carbon event handler is a `@convention(c)` callback that can't capture Swift state; virtual key codes and Carbon modifier masks are a different encoding from `NSEvent` flags. This is a compact, real example of bridging to a C framework.
5. **Daemonization the Apple way.** A `launchd` **LaunchAgent** plist with `RunAtLoad`/`KeepAlive`, why it must be a *per-user agent* (GUI session) and not a system daemon, and why `launchd` won't expand `~` in its paths (so `make install` substitutes absolutes). `brew services` is just a wrapper over this.
6. **The keybinding is an analysis, not a taste — and it can still be wrong.** Bare F1 collides with Neovim's DAP bindings; ⌘-modified keys never reach a terminal TUI, so the first pick was ⌘⌥Space — which turned out to *also* be macOS's Finder-search shortcut and won the race in practice. The toggle moved to Ctrl+T (no macOS shortcut at all). The [hotkeys record](docs/adr/hotkeys.md) holds the live reasoning, and its [decision log](https://github.com/dsaenztagarro/focusd/issues/6) holds the reversal.

## How it works

Everything is in `Sources/focusd/`: the rules in `Bindings.swift`, the plumbing in `main.swift`.

```
  launchd (LaunchAgent, GUI session)
        |  RunAtLoad / KeepAlive
        v
  focusd
   0. read ~/.config/focusd/config.json5  --> bindings (missing/invalid: Ctrl+T only)
   1. RegisterEventHotKey(chord, id)      --> the toggle as id 1, each slot as 2, 3, ...
      InstallEventHandler(kEventHotKeyPressed) --> C callback reads the id
   2. NSApplication.run() (.accessory)    --> run loop, no Dock icon
        |
        |  a registered chord pressed anywhere
        v
   3. action(forHotKeyID: id)
        toggle    -> target = (front == apps[0]) ? apps[1] : apps[0]
        focus(X)  -> target = X (the default browser is looked up now)
      NSWorkspace.openApplication(target, activates: true)
```

Why it is built this way, and what was rejected, is in [`docs/adr/hotkeys.md`](docs/adr/hotkeys.md); failure modes are under [Troubleshooting](#troubleshooting).

## Why no permissions (the key design choice)

Most hotkey tools ask you to grant **Accessibility** in System Settings. focusd doesn't, because it never needs to *see* your keystrokes — it registers each chord it needs with the WindowServer and gets a "that chord fired" event back. That is the entire reason to prefer `RegisterEventHotKey` over a `CGEventTap` here: same result for a handful of chords, none of the permission cost (which also breaks on OS upgrades and re-signing). Activating apps via `NSWorkspace` is unprivileged too. The trade-off — and what a `CGEventTap` would buy you — is written up in the [hotkeys record](docs/adr/hotkeys.md).

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

⌘⌥Space was the original, reasoned choice — until it collided with macOS's Finder-search shortcut in practice. **Ctrl+T** ([hotkeys record](docs/adr/hotkeys.md)) trades the "⌘ never reaches a TUI" safety of a Command chord for something better here: **no macOS system shortcut at all**, so no race and no per-machine settings dependency. The cost — Ctrl+T is a non-⌘ key, so it's consumed globally *inside* terminals too — is acceptable because nothing in this environment binds it (the only casualty is vim's niche `Ctrl+T` tag-pop).

## Fn-slots (HHKB)

On a Happy Hacking Keyboard, `Fn` is a layer inside the keyboard's firmware: macOS never sees it, and Fn+1 arrives as a plain **F1**. So each slot is a bare F-key that `RegisterEventHotKey` can register with no modifier, and no permission.

The slots are whatever the machine's [config](#configuring) names; on the work machine:

| Keys | Arrives as | Jumps to |
|------|-----------|----------|
| Fn+1 | F1 | iTerm2 (Herdr) |
| Fn+2 | F2 | Alacritty (Zellij) |
| Fn+3 | F3 | the default browser, resolved at press time |
| Fn+4 | F4 | Outlook |
| Fn+5 | F5 | Slack |

A registered key is consumed in every app, so the configured F-keys no longer reach anything else: nvim's debugger steps on `<Leader>d…` instead. A key no config names stays unbound. On an Apple keyboard, a bare F-key is a media key unless *"Use F1, F2, etc. keys as standard function keys"* is on, so the slots are meant for the HHKB.

## Configuring

Each machine has its own bindings in `~/.config/focusd/config.json5` (JSON5: comments and trailing commas allowed). This is the work machine's:

```json5
{
  // apps[0] is where Ctrl+T lands from any third app
  toggle: { key: "ctrl+t", apps: ["org.alacritty", "com.googlecode.iterm2"] },
  slots: {
    f1: "com.googlecode.iterm2",
    f2: "org.alacritty",
    f3: "default-browser",
    f4: "com.microsoft.Outlook",   // work machine only
    f5: "com.tinyspeck.slackmacgap",
  },
}
```

Edit it, then `make reload`. Resolve an app's bundle id with `osascript -e 'id of app "AppName"'`.

- **Keys:** `a`–`z`, `0`–`9`, `f1`–`f12`, `space`, `return`, with `ctrl`, `alt`, `cmd`, `shift` joined by `+` (`"cmd+alt+return"`). A slot is a bare key.
- **No file:** Ctrl+T flips Alacritty and iTerm2, and there are no slots. A file with no `toggle` keeps that toggle.
- **A broken file** (bad JSON5, an unknown key, one key bound twice, a toggle without exactly two apps) is ignored with the reason in `make logs`, and focusd runs on the no-file default.

`make install` never writes a config: one machine's apps don't belong on another.

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
  - Or just stay on the default **Ctrl+T**, which macOS never claims — see the [hotkeys record](docs/adr/hotkeys.md).
- **Fn+N does nothing.** `make logs` should show `registered hotkey … fN -> focus(…)` at start and a `slot fN:` line per press. No `registered` line for it means the config does not name that key, or was ignored: the start line says which. No `slot` line means the key never arrived as an F-key: check the keyboard's mode in a key-event viewer (Fn+1 should be `f1`, keycode 122, no modifiers).
- **Nothing happens at all on Ctrl+T.** Check the log (`make logs`). `RegisterEventHotKey failed` means another app owns the chord; `registered hotkey` with no `toggle:` lines means it's intercepted upstream. Rebind (above) or free the chord.
- **It toggles but the app doesn't come forward.** Confirm the bundle IDs with `osascript -e 'id of app "Alacritty"'`; an `app not installed: <id>` log line means the bundle ID resolves to nothing.
- **Loaded but the hotkey and activation silently do nothing.** It was installed as a system LaunchDaemon, which has no WindowServer session; focusd must be a per-user LaunchAgent, which is what `make install` writes.
- **Doesn't start at login.** `launchctl list | grep local.focusd` should show it; re-run `make install`.

## Layout

```
.
├── Sources/focusd/Bindings.swift # the rules: the config, keys, where a press lands
├── Sources/focusd/main.swift     # Carbon + AppKit plumbing, entry point
├── Tests/focusdTests/            # Swift Testing suite (make test)
├── Package.swift                 # SwiftPM executable, macOS 14+
├── Makefile                      # build / test / install / reload / uninstall / logs
├── launchd/local.focusd.plist    # LaunchAgent template
├── AGENTS.md · CLAUDE.md         # AI-agent instructions (single source of truth)
└── docs/
    ├── adr/                              # decision records, one per theme
    └── SECURITY.md
```

## Credits

Scaffolded on the [agentic-engineering-template](https://github.com/dsaenztagarro/agentic-engineering-template) — the agent instructions and the `template-feedback` / `epic` skills come from there.

## License

[MIT](LICENSE) © David Saenz
