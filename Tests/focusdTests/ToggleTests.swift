import Testing
@testable import focusd

// Ctrl+T is a two-way flip between the terminals, with Alacritty as the
// landing spot from anywhere else (see docs/adr/hotkeys.md).
struct ToggleTests {
    @Test("Ctrl+T from Alacritty lands on iTerm2")
    func fromAlacritty() {
        #expect(toggleTarget(front: "org.alacritty") == "com.googlecode.iterm2")
    }

    @Test("Ctrl+T from any other app lands on Alacritty", arguments: [
        "com.googlecode.iterm2", "com.apple.Safari", nil,
    ])
    func fromElsewhere(front: String?) {
        #expect(toggleTarget(front: front) == "org.alacritty")
    }
}
