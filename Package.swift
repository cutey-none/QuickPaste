// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "QuickPaste",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "QuickPasteCore"),
        .executableTarget(name: "QuickPaste", dependencies: ["QuickPasteCore"]),
        .testTarget(name: "QuickPasteCoreTests", dependencies: ["QuickPasteCore"]),
    ]
)
