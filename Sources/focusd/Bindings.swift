// The pure half of focusd: which keys are bound and where each press lands.
// Kept apart from the Carbon/AppKit plumbing in main.swift so the tests can
// state these rules without a WindowServer.

import Carbon.HIToolbox

// MARK: - Configuration

/// The two apps to toggle between, by **bundle identifier**.
/// Resolve any app's id with:  `osascript -e 'id of app "AppName"'`
let appA = "org.alacritty"          // Alacritty (running Zellij)
let appB = "com.googlecode.iterm2"  // iTerm2 (running Herdr)

/// The global hotkey: Ctrl+T.
/// `kVK_ANSI_T` (17) is a virtual key code; the modifier mask uses Carbon's
/// `controlKey` bit (this is *not* the same encoding as NSEvent flags).
///
/// Unlike a ⌘-based chord (which a terminal emulator eats for its own menus and
/// so never reaches the TUI), Ctrl+T flows into the terminal — and because a
/// registered hotkey is *consumed*, focusd takes Ctrl+T globally, including
/// inside the shell/nvim/Zellij. That's an accepted trade-off here: Ctrl+T has
/// no macOS system shortcut (so no Finder-search race, unlike the old ⌘⌥Space),
/// and nothing in this environment binds it. See docs/adr/hotkeys.md.
/// To rebind, change these two constants and rebuild — nothing else depends on them.
let hotKeyCode = UInt32(kVK_ANSI_T)
let hotKeyModifiers = UInt32(controlKey)

/// The toggle: if A is frontmost, go to B; from B — or from any third app —
/// go to A. That makes Ctrl+T a true back-and-forth flip between the two
/// terminals, with A as the default landing spot from elsewhere.
func toggleTarget(front: String?) -> String {
    front == appA ? appB : appA
}
