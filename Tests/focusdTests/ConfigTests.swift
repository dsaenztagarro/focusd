import Carbon.HIToolbox
import Foundation
import Testing
@testable import focusd

// Every binding comes from a per-machine JSON5 file read once at startup, so
// one binary serves machines with different apps. Startup never fails on the
// file: launchd's KeepAlive would restart a process that exits in a loop, so a
// missing or broken file runs the built-in Ctrl+T toggle and nothing else.
// See docs/adr/hotkeys.md.
struct ConfigTests {
    private func config(_ text: String) -> Data { Data(text.utf8) }

    @Test("a missing config keeps Ctrl+T flipping Alacritty and iTerm2")
    func missingConfig() {
        let (bindings, outcome) = startupBindings { nil }
        #expect(outcome == .missing)
        #expect(bindings.toggle.chord == Chord(keyCode: UInt32(kVK_ANSI_T), modifiers: UInt32(controlKey)))
        #expect(bindings.toggle.target(front: "org.alacritty") == "com.googlecode.iterm2")
        #expect(bindings.toggle.target(front: "com.googlecode.iterm2") == "org.alacritty")
        #expect(bindings.slots.isEmpty)
    }

    @Test("an invalid config falls back to the toggle alone", arguments: [
        "{ toggle: ",
        #"{ slots: { f13: "org.alacritty" } }"#,
    ])
    func invalidConfig(text: String) {
        let (bindings, outcome) = startupBindings { Data(text.utf8) }
        guard case .invalid = outcome else {
            Issue.record("expected an invalid outcome, got \(outcome)")
            return
        }
        #expect(bindings == defaultBindings)
        #expect(bindings.hotKeys.map(\.action) == [.toggle])
    }

    @Test("an unreadable config falls back to the toggle alone")
    func unreadableConfig() {
        struct ReadFailure: Error {}
        let (bindings, outcome) = startupBindings { throw ReadFailure() }
        guard case .invalid = outcome else {
            Issue.record("expected an invalid outcome, got \(outcome)")
            return
        }
        #expect(bindings == defaultBindings)
    }

    @Test("the config accepts comments and trailing commas")
    func json5() throws {
        let bindings = try parseConfig(config("""
            // a personal machine
            {
              toggle: { key: "ctrl+t", apps: ["org.alacritty", "com.googlecode.iterm2",], },
              slots: {
                f1: "com.googlecode.iterm2",  // Fn+1
                f3: "default-browser",
              },
            }
            """))
        #expect(bindings.slots.map(\.target) == [.app("com.googlecode.iterm2"), .defaultBrowser])
    }

    @Test("an unknown key name is rejected", arguments: [
        #"{ slots: { f13: "org.alacritty" } }"#,
        #"{ toggle: { key: "hyper+t", apps: ["a", "b"] } }"#,
        #"{ toggle: { key: "ctrl+", apps: ["a", "b"] } }"#,
    ])
    func unknownKey(text: String) {
        #expect(throws: ConfigError.self) { try parseConfig(config(text)) }
    }

    @Test("a slot is a bare key")
    func slotWithModifier() {
        #expect(throws: ConfigError.self) {
            try parseConfig(config(#"{ slots: { "alt+f1": "org.alacritty" } }"#))
        }
    }

    @Test("two bindings on one key are rejected", arguments: [
        #"{ toggle: { key: "f1", apps: ["a", "b"] }, slots: { f1: "c" } }"#,
        #"{ slots: { f1: "a", F1: "b" } }"#,
    ])
    func duplicateKey(text: String) {
        #expect(throws: ConfigError.self) { try parseConfig(config(text)) }
    }

    @Test("the toggle names exactly two apps", arguments: [
        #"{ toggle: { key: "ctrl+t", apps: ["org.alacritty"] } }"#,
        #"{ toggle: { key: "ctrl+t", apps: ["a", "b", "c"] } }"#,
        #"{ toggle: { key: "ctrl+t", apps: ["a", "a"] } }"#,
    ])
    func toggleApps(text: String) {
        #expect(throws: ConfigError.self) { try parseConfig(config(text)) }
    }

    @Test("a config without a toggle keeps the default toggle")
    func slotsOnly() throws {
        let bindings = try parseConfig(config(#"{ slots: { f5: "com.tinyspeck.slackmacgap" } }"#))
        #expect(bindings.toggle == defaultBindings.toggle)
    }
}
