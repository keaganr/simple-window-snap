// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SWSUI",
    platforms: [.macOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SWSUI",
            targets: ["SWSUI"]
        ),
    ],
    dependencies: [
        .package(path: "../SWSAccessibility"),
        .package(path: "../SWSModel"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SWSUI",
            dependencies: ["SWSAccessibility", "SWSModel"]
        ),
        .testTarget(
            name: "SWSUITests",
            dependencies: ["SWSUI"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
