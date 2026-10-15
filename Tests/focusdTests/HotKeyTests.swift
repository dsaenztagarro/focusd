import Carbon.HIToolbox
import Foundation
import Testing
@testable import focusd

// On an HHKB, Fn+N is a firmware layer that reaches macOS as a bare FN, so
// each slot is an F-key with no modifier. A slot names one app and lands on
// it whatever is frontmost; Ctrl+T keeps the two-terminal flip. Only the keys
// a machine's config names are registered, since each one is taken globally.
// See docs/adr/hotkeys.md.
struct HotKeyTests {
    private let work = try! parseConfig(Data("""
        {
          toggle: { key: "ctrl+t", apps: ["org.alacritty", "com.googlecode.iterm2"] },
          slots: {
            f5: "com.tinyspeck.slackmacgap",
            f1: "com.googlecode.iterm2",
            f2: "org.alacritty",
            f3: "default-browser",
            f4: "com.microsoft.Outlook",
          },
        }
        """.utf8))

    @Test("each slot key routes to its app", arguments: [
        (kVK_F1, Target.app("com.googlecode.iterm2")),
        (kVK_F2, Target.app("org.alacritty")),
        (kVK_F3, Target.defaultBrowser),
        (kVK_F4, Target.app("com.microsoft.Outlook")),
        (kVK_F5, Target.app("com.tinyspeck.slackmacgap")),
    ])
    func slotRoutes(keyCode: Int, target: Target) throws {
        let hotKey = try #require(work.hotKeys.first { $0.chord == Chord(keyCode: UInt32(keyCode), modifiers: 0) })
        #expect(work.action(forHotKeyID: hotKey.id) == .focus(target))
    }

    @Test("slots register in key order, after the toggle")
    func registrationOrder() {
        #expect(work.hotKeys.map(\.chord.description) == ["ctrl+t", "f1", "f2", "f3", "f4", "f5"])
        #expect(work.hotKeys.map(\.id) == [1, 2, 3, 4, 5, 6])
    }

    @Test("Ctrl+T is bound to the toggle")
    func toggleBinding() throws {
        let hotKey = try #require(work.hotKeys.first { $0.chord == Chord(keyCode: UInt32(kVK_ANSI_T), modifiers: UInt32(controlKey)) })
        #expect(work.action(forHotKeyID: hotKey.id) == .toggle)
    }

    @Test("every registered hotkey id routes to exactly one action")
    func idsRouteToTheirAction() {
        let ids = work.hotKeys.map(\.id)
        #expect(Set(ids).count == ids.count)
        for hotKey in work.hotKeys {
            #expect(work.action(forHotKeyID: hotKey.id) == hotKey.action)
        }
    }

    @Test("a config without slots registers only the toggle")
    func noSlots() throws {
        let bindings = try parseConfig(Data(#"{ toggle: { key: "ctrl+t", apps: ["a", "b"] } }"#.utf8))
        #expect(bindings.hotKeys.map(\.action) == [.toggle])
    }

    @Test("an unknown hotkey id routes nowhere")
    func unknownID() {
        #expect(work.action(forHotKeyID: 0) == nil)
    }
}
