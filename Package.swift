// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "pocket-gris",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PocketGrisCore",
            targets: ["PocketGrisCore"]
        ),
        .executable(
            name: "pocketgris",
            targets: ["PocketGrisCLI"]
        ),
        .executable(
            name: "PocketGrisApp",
            targets: ["PocketGrisApp"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0")
    ],
    targets: [
        // Core library - pure Swift, no UI dependencies
        .target(
            name: "PocketGrisCore",
            dependencies: [],
            path: "Sources/PocketGrisCore"
        ),

        // CLI for testing and control
        .executableTarget(
            name: "PocketGrisCLI",
            dependencies: [
                "PocketGrisCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/PocketGrisCLI"
        ),

        // Menu bar app
        .executableTarget(
            name: "PocketGrisApp",
            dependencies: ["PocketGrisCore"],
            path: "Sources/PocketGrisApp"
        ),

        // Tests
        .testTarget(
            name: "PocketGrisCoreTests",
            dependencies: ["PocketGrisCore"],
            path: "Tests/PocketGrisCoreTests"
        )
    ]
)
