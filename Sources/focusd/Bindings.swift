// The pure half of focusd: which keys are bound and where each press lands.
// Kept apart from the Carbon/AppKit plumbing in main.swift so the tests can
// state these rules without a WindowServer.

import Carbon.HIToolbox
import Foundation

// MARK: - Keys

/// The key names a config may use, in the order slots are registered.
/// Each maps to a virtual key code (`kVK_*`), which names a physical key,
/// not the character it types.
let keyNames: [(name: String, code: Int)] = [
    ("a", kVK_ANSI_A), ("b", kVK_ANSI_B), ("c", kVK_ANSI_C), ("d", kVK_ANSI_D),
    ("e", kVK_ANSI_E), ("f", kVK_ANSI_F), ("g", kVK_ANSI_G), ("h", kVK_ANSI_H),
    ("i", kVK_ANSI_I), ("j", kVK_ANSI_J), ("k", kVK_ANSI_K), ("l", kVK_ANSI_L),
    ("m", kVK_ANSI_M), ("n", kVK_ANSI_N), ("o", kVK_ANSI_O), ("p", kVK_ANSI_P),
    ("q", kVK_ANSI_Q), ("r", kVK_ANSI_R), ("s", kVK_ANSI_S), ("t", kVK_ANSI_T),
    ("u", kVK_ANSI_U), ("v", kVK_ANSI_V), ("w", kVK_ANSI_W), ("x", kVK_ANSI_X),
    ("y", kVK_ANSI_Y), ("z", kVK_ANSI_Z),
    ("0", kVK_ANSI_0), ("1", kVK_ANSI_1), ("2", kVK_ANSI_2), ("3", kVK_ANSI_3),
    ("4", kVK_ANSI_4), ("5", kVK_ANSI_5), ("6", kVK_ANSI_6), ("7", kVK_ANSI_7),
    ("8", kVK_ANSI_8), ("9", kVK_ANSI_9),
    ("f1", kVK_F1), ("f2", kVK_F2), ("f3", kVK_F3), ("f4", kVK_F4),
    ("f5", kVK_F5), ("f6", kVK_F6), ("f7", kVK_F7), ("f8", kVK_F8),
    ("f9", kVK_F9), ("f10", kVK_F10), ("f11", kVK_F11), ("f12", kVK_F12),
    ("space", kVK_Space), ("return", kVK_Return),
]

/// Carbon's modifier mask bits, in the order a chord is written. This is *not*
/// the same encoding as NSEvent flags.
let modifierNames: [(name: String, mask: Int)] = [
    ("ctrl", controlKey), ("alt", optionKey), ("cmd", cmdKey), ("shift", shiftKey),
]

/// One key plus its modifiers: what `RegisterEventHotKey` matches.
struct Chord: Hashable, CustomStringConvertible {
    let keyCode: UInt32
    let modifiers: UInt32

    var description: String {
        let modifiers = modifierNames.filter { self.modifiers & UInt32($0.mask) != 0 }.map(\.name)
        let key = keyNames.first { UInt32($0.code) == keyCode }?.name ?? "keycode \(keyCode)"
        return (modifiers + [key]).joined(separator: "+")
    }
}

/// Reads a chord as written in the config: `"ctrl+t"`, `"f1"`, in any case.
func parseChord(_ text: String) throws -> Chord {
    let parts = text.lowercased().split(separator: "+", omittingEmptySubsequences: false).map(String.init)
    guard let code = keyNames.first(where: { $0.name == parts.last })?.code else {
        throw ConfigError.unknownKey(text)
    }
    var modifiers: UInt32 = 0
    for name in parts.dropLast() {
        guard let mask = modifierNames.first(where: { $0.name == name })?.mask else {
            throw ConfigError.unknownKey(text)
        }
        modifiers |= UInt32(mask)
    }
    return Chord(keyCode: UInt32(code), modifiers: modifiers)
}

// MARK: - Bindings

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

/// The flip: if `landing` is frontmost, go to `other`; from `other` — or from
/// any third app — go to `landing`. That makes the toggle a true back-and-forth
/// between two apps, with `landing` as the spot it lands on from elsewhere.
struct Toggle: Equatable {
    let chord: Chord
    let landing: String
    let other: String

    func target(front: String?) -> String {
        front == landing ? other : landing
    }
}

/// A direct app key. On an HHKB, Fn+N reaches macOS as a bare FN, so Fn+1 is F1.
struct Slot: Equatable {
    let key: Chord
    let target: Target
}

enum Action: Equatable {
    case toggle
    case focus(Target)
}

/// One registration with the WindowServer. `id` comes back in the
/// `EventHotKeyID` of every press, which is how the handler tells keys apart.
struct HotKey: Equatable {
    let id: UInt32
    let chord: Chord
    let action: Action
}

/// Everything one machine binds. A registered key is consumed in every app, so
/// only what is here is registered: a key left out still reaches the apps.
struct Bindings: Equatable {
    let toggle: Toggle
    let slots: [Slot]

    var hotKeys: [HotKey] {
        [HotKey(id: 1, chord: toggle.chord, action: .toggle)]
            + slots.enumerated().map { index, slot in
                HotKey(id: UInt32(index + 2), chord: slot.key, action: .focus(slot.target))
            }
    }

    func hotKey(id: UInt32) -> HotKey? {
        hotKeys.first { $0.id == id }
    }

    func action(forHotKeyID id: UInt32) -> Action? {
        hotKey(id: id)?.action
    }
}

/// What a machine without a config gets: Ctrl+T flips Alacritty (Zellij) and
/// iTerm2 (Herdr), and no slots. Ctrl+T is taken globally, including inside the
/// shell, nvim and Zellij; nothing in this environment binds it. See
/// docs/adr/hotkeys.md.
let defaultBindings = Bindings(
    toggle: Toggle(chord: Chord(keyCode: UInt32(kVK_ANSI_T), modifiers: UInt32(controlKey)),
                   landing: "org.alacritty", other: "com.googlecode.iterm2"),
    slots: []
)

// MARK: - Config file

/// `~/.config/focusd/config.json5`, as JSON5: comments, unquoted keys and
/// trailing commas. Resolve an app's bundle id with
/// `osascript -e 'id of app "AppName"'`.
private struct ConfigFile: Decodable {
    struct ToggleEntry: Decodable {
        let key: String
        let apps: [String]
    }

    let toggle: ToggleEntry?
    let slots: [String: String]?
}

enum ConfigError: Error, Equatable, CustomStringConvertible {
    case unknownKey(String)
    case slotNotBare(String)
    case duplicateKey(String)
    case toggleApps([String])

    var description: String {
        switch self {
        case .unknownKey(let key): return "unknown key \"\(key)\""
        case .slotNotBare(let key): return "slot \"\(key)\" has a modifier; a slot is a bare key"
        case .duplicateKey(let chord): return "\(chord) is bound twice"
        case .toggleApps(let apps): return "toggle.apps must name two different apps, got \(apps)"
        }
    }
}

func parseConfig(_ data: Data) throws -> Bindings {
    let decoder = JSONDecoder()
    decoder.allowsJSON5 = true
    let file = try decoder.decode(ConfigFile.self, from: data)

    var toggle = defaultBindings.toggle
    if let entry = file.toggle {
        guard entry.apps.count == 2, entry.apps[0] != entry.apps[1] else {
            throw ConfigError.toggleApps(entry.apps)
        }
        toggle = Toggle(chord: try parseChord(entry.key), landing: entry.apps[0], other: entry.apps[1])
    }

    let slots = try (file.slots ?? [:]).map { name, target in
        let key = try parseChord(name)
        guard key.modifiers == 0 else { throw ConfigError.slotNotBare(name) }
        return Slot(key: key, target: target == "default-browser" ? .defaultBrowser : .app(target))
    }.sorted { registrationOrder($0.key) < registrationOrder($1.key) }

    var taken: Set<Chord> = []
    for chord in [toggle.chord] + slots.map(\.key) where !taken.insert(chord).inserted {
        throw ConfigError.duplicateKey(chord.description)
    }
    return Bindings(toggle: toggle, slots: slots)
}

private func registrationOrder(_ chord: Chord) -> Int {
    keyNames.firstIndex { UInt32($0.code) == chord.keyCode } ?? keyNames.count
}

enum ConfigOutcome: Equatable {
    case loaded
    case missing
    case invalid(String)
}

/// The bindings to register at startup. `readConfig` returns nil when there is
/// no file. This never fails: launchd's KeepAlive restarts a process that
/// exits, so a config that stopped it would restart it in a loop. Any problem
/// runs `defaultBindings` instead, with the reason.
func startupBindings(readConfig: () throws -> Data?) -> (bindings: Bindings, outcome: ConfigOutcome) {
    do {
        guard let data = try readConfig() else { return (defaultBindings, .missing) }
        return (try parseConfig(data), .loaded)
    } catch {
        return (defaultBindings, .invalid(String(describing: error)))
    }
}
