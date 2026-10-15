// focusd — a tiny macOS global-hotkey daemon that switches focus between apps.
//
// It does exactly three things:
//   1. Register its hotkeys with the WindowServer (Carbon `RegisterEventHotKey`).
//   2. On press, look up the key's action (Bindings.swift) and, for the
//      toggle, ask "who is frontmost?" (AppKit `NSWorkspace`).
//   3. Activate the target app (AppKit `NSWorkspace.openApplication`).
//
// Why Carbon and not a CGEventTap: `RegisterEventHotKey` registers each
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

/// Bring `target` to the front, launching it if it isn't running.
///
/// `openApplication(at:configuration:)` is the modern "open or activate" call:
/// on an already-running app it just activates it, so one code path covers both
/// the running and not-running cases. None of this needs special permissions.
private func focus(_ target: Target) {
    let workspace = NSWorkspace.shared
    let url: URL?
    switch target {
    case .app(let bundleID):
        url = workspace.urlForApplication(withBundleIdentifier: bundleID)
    case .defaultBrowser:
        url = workspace.urlForApplication(toOpen: URL(string: "https://example.com")!)
    }
    guard let url else {
        log("app not installed: \(target)")
        return
    }
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    workspace.openApplication(at: url, configuration: configuration) { _, error in
        if let error {
            log("activate/launch failed for \(target): \(error.localizedDescription)")
        }
    }
}

private func handleHotKey(id: UInt32) {
    guard let hotKey = bindings.hotKey(id: id) else {
        log("unknown hotkey id \(id)")
        return
    }
    let frontID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    switch hotKey.action {
    case .toggle:
        let targetID = bindings.toggle.target(front: frontID)
        log("toggle: front=\(frontID ?? "nil") -> \(targetID)")
        focus(.app(targetID))
    case .focus(let target):
        log("slot \(hotKey.chord): front=\(frontID ?? "nil") -> \(target)")
        focus(target)
    }
}

// MARK: - Carbon hotkey plumbing

/// Held for the process lifetime so the registrations stay alive.
private var hotKeyRefs: [EventHotKeyRef?] = []

private let hotKeySignature = fourCharCode("FCSD")

/// Pack up to four ASCII chars into an `OSType` (a FourCharCode). Used to give
/// our hotkey a unique signature the event handler can recognise.
private func fourCharCode(_ string: String) -> OSType {
    var result: OSType = 0
    for scalar in string.unicodeScalars.prefix(4) {
        result = (result << 8) + (scalar.value & 0xFF)
    }
    return result
}

/// Register every hotkey and install the handler the WindowServer calls on press.
private func installHotKeys() {
    var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                  eventKind: UInt32(kEventHotKeyPressed))

    // The handler is a C callback (`@convention(c)`): it must not capture any
    // Swift state, so it reads which hotkey fired from the event and hands
    // the id to the top-level `handleHotKey(id:)`.
    InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                       EventParamType(typeEventHotKeyID), nil,
                                       MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
        guard status == noErr else { return status }
        handleHotKey(id: hotKeyID.id)
        return noErr
    }, 1, &eventType, nil, nil)

    for hotKey in bindings.hotKeys {
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(hotKey.chord.keyCode, hotKey.chord.modifiers,
                                         EventHotKeyID(signature: hotKeySignature, id: hotKey.id),
                                         GetApplicationEventTarget(), 0, &ref)
        if status == noErr {
            hotKeyRefs.append(ref)
            log("registered hotkey \(hotKey.id) \(hotKey.chord) -> \(hotKey.action)")
        } else {
            // Most likely another process/system shortcut already owns this chord.
            log("RegisterEventHotKey failed for hotkey \(hotKey.id) \(hotKey.chord) with OSStatus \(status)")
        }
    }
}

// MARK: - Entry point

/// Read once at startup; an edit takes effect on the next start (`make reload`).
let configURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".config/focusd/config.json5")

let (bindings, configOutcome) = startupBindings {
    FileManager.default.fileExists(atPath: configURL.path) ? try Data(contentsOf: configURL) : nil
}
switch configOutcome {
case .loaded:
    log("focusd starting with \(configURL.path)")
case .missing:
    log("focusd starting; no config at \(configURL.path), using the default toggle")
case .invalid(let reason):
    log("focusd starting; ignoring \(configURL.path): \(reason); using the default toggle")
}
installHotKeys()

// A run loop must be pumping for the WindowServer to deliver hotkey events.
// NSApplication provides one; `.accessory` keeps us out of the Dock and the
// app switcher — a headless background agent.
let application = NSApplication.shared
application.setActivationPolicy(.accessory)
application.run()
