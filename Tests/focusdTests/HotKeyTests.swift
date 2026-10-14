import Carbon.HIToolbox
import Testing
@testable import focusd

// On an HHKB, Fn+N is a firmware layer that reaches macOS as a bare FN, so
// each slot is an F-key with no modifier. A slot names one app and lands on
// it whatever is frontmost; Ctrl+T keeps the two-terminal flip.
// See docs/adr/hotkeys.md.
struct HotKeyTests {
    @Test("each slot key routes to its app", arguments: [
        (kVK_F1, Target.app("com.googlecode.iterm2")),
        (kVK_F2, Target.app("org.alacritty")),
        (kVK_F3, Target.defaultBrowser),
        (kVK_F4, Target.app("com.microsoft.Outlook")),
        (kVK_F5, Target.app("com.tinyspeck.slackmacgap")),
    ])
    func slotRoutes(keyCode: Int, target: Target) throws {
        let hotKey = try #require(hotKeys.first { $0.keyCode == UInt32(keyCode) && $0.modifiers == 0 })
        #expect(action(forHotKeyID: hotKey.id) == .focus(target))
    }

    @Test("Ctrl+T is bound to the toggle")
    func toggleBinding() throws {
        let hotKey = try #require(hotKeys.first { $0.keyCode == UInt32(kVK_ANSI_T) && $0.modifiers == UInt32(controlKey) })
        #expect(action(forHotKeyID: hotKey.id) == .toggle)
    }

    @Test("no two hotkeys share a chord")
    func chordsAreUnique() {
        let chords = hotKeys.map { "\($0.keyCode)+\($0.modifiers)" }
        #expect(Set(chords).count == chords.count)
    }

    @Test("every registered hotkey id routes to exactly one action")
    func idsRouteToTheirAction() {
        let ids = hotKeys.map(\.id)
        #expect(Set(ids).count == ids.count)
        for hotKey in hotKeys {
            #expect(action(forHotKeyID: hotKey.id) == hotKey.action)
        }
    }

    @Test("an unknown hotkey id routes nowhere")
    func unknownID() {
        #expect(action(forHotKeyID: 0) == nil)
    }
}
