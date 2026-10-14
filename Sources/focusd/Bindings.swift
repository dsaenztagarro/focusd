// The pure half of focusd: which keys are bound and where each press lands.
// Kept apart from the Carbon/AppKit plumbing in main.swift so the tests can
// state these rules without a WindowServer.

import Carbon.HIToolbox

// MARK: - Configuration

/// The two apps Ctrl+T flips between, by **bundle identifier**.
/// Resolve any app's id with:  `osascript -e 'id of app "AppName"'`
let appA = "org.alacritty"          // Alacritty (running Zellij)
let appB = "com.googlecode.iterm2"  // iTerm2 (running Herdr)

/// Ctrl+T: `kVK_ANSI_T` (17) is a virtual key code; the modifier mask uses
/// Carbon's `controlKey` bit (this is *not* the same encoding as NSEvent flags).
///
/// Because a registered hotkey is *consumed*, focusd takes Ctrl+T globally,
/// including inside the shell/nvim/Zellij; nothing in this environment binds
/// it. See docs/adr/hotkeys.md.
let hotKeyCode = UInt32(kVK_ANSI_T)
let hotKeyModifiers = UInt32(controlKey)

/// Where a slot press lands.
enum Target: Equatable, CustomStringConvertible {
    case app(String)        // a bundle identifier
    case defaultBrowser     // whatever handles https:// right now

    var description: String {
        switch self {
        case .app(let bundleID): return bundleID
        case .defaultBrowser: return "default browser"
        }
    }
}

/// Direct app keys, in order of importance. On an HHKB, Fn+N reaches macOS as
/// a bare FN, so Fn+1 is F1. Every key listed here is consumed in every app:
/// leave a key out rather than bind it to nothing.
let slots: [(keyCode: UInt32, target: Target)] = [
    (UInt32(kVK_F1), .app(appB)),                          // iTerm2 (Herdr)
    (UInt32(kVK_F2), .app(appA)),                          // Alacritty (Zellij)
    (UInt32(kVK_F3), .defaultBrowser),
    (UInt32(kVK_F4), .app("com.microsoft.Outlook")),
    (UInt32(kVK_F5), .app("com.tinyspeck.slackmacgap")),
]

// MARK: - Routing

enum Action: Equatable {
    case toggle
    case focus(Target)
}

/// One registration with the WindowServer. `id` comes back in the
/// `EventHotKeyID` of every press, which is how the handler tells keys apart.
struct HotKey {
    let id: UInt32
    let keyCode: UInt32
    let modifiers: UInt32
    let action: Action
}

let hotKeys: [HotKey] =
    [HotKey(id: 1, keyCode: hotKeyCode, modifiers: hotKeyModifiers, action: .toggle)]
    + slots.enumerated().map { index, slot in
        HotKey(id: UInt32(index + 2), keyCode: slot.keyCode, modifiers: 0, action: .focus(slot.target))
    }

func action(forHotKeyID id: UInt32) -> Action? {
    hotKeys.first { $0.id == id }?.action
}

/// The toggle: if A is frontmost, go to B; from B — or from any third app —
/// go to A. That makes Ctrl+T a true back-and-forth flip between the two
/// terminals, with A as the default landing spot from elsewhere.
func toggleTarget(front: String?) -> String {
    front == appA ? appB : appA
}
