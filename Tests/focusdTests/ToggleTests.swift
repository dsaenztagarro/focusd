import Foundation
import Testing
@testable import focusd

// Ctrl+T is a two-way flip between the config's two toggle apps, with the
// first as the landing spot from anywhere else (see docs/adr/hotkeys.md).
struct ToggleTests {
    private let toggle = try! parseConfig(Data("""
        { toggle: { key: "ctrl+t", apps: ["org.alacritty", "com.googlecode.iterm2"] } }
        """.utf8)).toggle

    @Test("Ctrl+T from Alacritty lands on iTerm2")
    func fromAlacritty() {
        #expect(toggle.target(front: "org.alacritty") == "com.googlecode.iterm2")
    }

    @Test("Ctrl+T from any other app lands on Alacritty", arguments: [
        "com.googlecode.iterm2", "com.apple.Safari", nil,
    ])
    func fromElsewhere(front: String?) {
        #expect(toggle.target(front: front) == "org.alacritty")
    }

    @Test("a configured toggle flips its own two apps")
    func otherPair() throws {
        let toggle = try parseConfig(Data("""
            { toggle: { key: "cmd+alt+return", apps: ["com.apple.Safari", "com.apple.mail"] } }
            """.utf8)).toggle
        #expect(toggle.target(front: "com.apple.Safari") == "com.apple.mail")
        #expect(toggle.target(front: "org.alacritty") == "com.apple.Safari")
    }
}
