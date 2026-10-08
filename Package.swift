// swift-tools-version:5.9
import PackageDescription

// focusd is a macOS executable plus its test target. AppKit and Carbon are system
// frameworks, linked automatically from the `import`s — no extra linker flags.
let package = Package(
    name: "focusd",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "focusd",
            path: "Sources/focusd"
        ),
        .testTarget(
            name: "focusdTests",
            dependencies: ["focusd"],
            path: "Tests/focusdTests"
        )
    ]
)
