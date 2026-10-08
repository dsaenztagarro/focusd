// focusd — a tiny macOS global-hotkey daemon that toggles focus between two apps.
//
// It does exactly three things:
//   1. Register a global hotkey with the WindowServer (Carbon `RegisterEventHotKey`).
//   2. On press, ask "who is frontmost?" (AppKit `NSWorkspace`).
//   3. Activate the *other* app (AppKit `NSWorkspace.openApplication`).
//
// Why Carbon and not a CGEventTap: `RegisterEventHotKey` registers a single
// chord with the WindowServer, which delivers it to us as a high-level event.
// It needs **no Accessibility / Input-Monitoring grant** — unlike an event tap,
// which sees the whole keyboard stream and therefore requires that privilege.
// See docs/adr/hotkeys.md for the full trade-off.

import AppKit
import Carbon.HIToolbox

// MARK: - Logging

/// Write one timestamped line to stderr. The LaunchAgent redirects stderr to
/// ~/Library/Logs/local.focusd.log, so `make logs` tails these.
private func log(_ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    FileHandle.standardError.write(Data("[\(timestamp)] \(message)\n".utf8))
}

// MARK: - Focus logic

/// Bring `bundleID` to the front, launching it if it isn't running.
///
/// `openApplication(at:configuration:)` is the modern "open or activate" call:
/// on an already-running app it just activates it, so one code path covers both
/// the running and not-running cases. None of this needs special permissions.
private func focus(bundleID: String) {
    let workspace = NSWorkspace.shared
    guard let url = workspace.urlForApplication(withBundleIdentifier: bundleID) else {
        log("app not installed: \(bundleID)")
        return
    }
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    workspace.openApplication(at: url, configuration: configuration) { _, error in
        if let error {
            log("activate/launch failed for \(bundleID): \(error.localizedDescription)")
        }
    }
}

private func toggleFocus() {
    let frontID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    let targetID = toggleTarget(front: frontID)
    log("toggle: front=\(frontID ?? "nil") -> \(targetID)")
    focus(bundleID: targetID)
}

// MARK: - Carbon hotkey plumbing

/// Held for the process lifetime so the registration stays alive.
private var hotKeyRef: EventHotKeyRef?

/// Pack up to four ASCII chars into an `OSType` (a FourCharCode). Used to give
/// our hotkey a unique signature the event handler can recognise.
private func fourCharCode(_ string: String) -> OSType {
    var result: OSType = 0
    for scalar in string.unicodeScalars.prefix(4) {
        result = (result << 8) + (scalar.value & 0xFF)
    }
    return result
}

/// Register the hotkey and install the handler the WindowServer calls on press.
private func installHotKey() {
    let hotKeyID = EventHotKeyID(signature: fourCharCode("FCSD"), id: 1)
    var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                  eventKind: UInt32(kEventHotKeyPressed))

    // The handler is a C callback (`@convention(c)`): it must not capture any
    // Swift state, so it calls the top-level `toggleFocus()` and returns.
    InstallEventHandler(GetApplicationEventTarget(), { _, _, _ -> OSStatus in
        toggleFocus()
        return noErr
    }, 1, &eventType, nil, nil)

    let status = RegisterEventHotKey(hotKeyCode, hotKeyModifiers, hotKeyID,
                                     GetApplicationEventTarget(), 0, &hotKeyRef)
    if status == noErr {
        log("registered hotkey Ctrl+T (keycode \(hotKeyCode), mods \(hotKeyModifiers))")
    } else {
        // Most likely another process/system shortcut already owns this chord.
        log("RegisterEventHotKey failed with OSStatus \(status)")
    }
}

// MARK: - Entry point

log("focusd starting; toggling \(appA) <-> \(appB)")
installHotKey()

// A run loop must be pumping for the WindowServer to deliver hotkey events.
// NSApplication provides one; `.accessory` keeps us out of the Dock and the
// app switcher — a headless background agent.
let application = NSApplication.shared
application.setActivationPolicy(.accessory)
application.run()
