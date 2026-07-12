// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SWSHotkey",
    platforms: [.macOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SWSHotkey",
            targets: ["SWSHotkey"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.2.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        // SWSHotkey wraps the third-party KeyboardShortcuts package so the rest
        // of the app never imports it directly (see implementation-plan.md).
        .target(
            name: "SWSHotkey",
            dependencies: ["KeyboardShortcuts"]
        ),
        .testTarget(
            name: "SWSHotkeyTests",
            dependencies: ["SWSHotkey"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
