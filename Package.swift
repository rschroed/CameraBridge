// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CameraBridge",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CameraBridgeCore",
            targets: ["CameraBridgeCore"]
        ),
        .library(
            name: "CameraBridgeAPI",
            targets: ["CameraBridgeAPI"]
        ),
        .library(
            name: "CameraBridgeClientSwift",
            targets: ["CameraBridgeClientSwift"]
        ),
        .library(
            name: "CameraBridgeSupport",
            targets: ["CameraBridgeSupport"]
        ),
        .executable(
            name: "camd",
            targets: ["camd"]
        ),
        .executable(
            name: "CameraBridgeApp",
            targets: ["CameraBridgeApp"]
        ),
    ],
    targets: [
        .target(
            name: "CameraBridgeCore",
            path: "packages/CameraBridgeCore/Sources/CameraBridgeCore"
        ),
        .target(
            name: "CameraBridgeAPI",
            dependencies: ["CameraBridgeCore"],
            path: "packages/CameraBridgeAPI/Sources/CameraBridgeAPI"
        ),
        .target(
            name: "CameraBridgeClientSwift",
            dependencies: ["CameraBridgeAPI"],
            path: "packages/CameraBridgeClientSwift/Sources/CameraBridgeClientSwift"
        ),
        .target(
            name: "CameraBridgeSupport",
            path: "packages/CameraBridgeSupport/Sources/CameraBridgeSupport"
        ),
        .executableTarget(
            name: "camd",
            dependencies: ["CameraBridgeAPI", "CameraBridgeCore", "CameraBridgeSupport"],
            path: "apps/camd/Sources/camd"
        ),
        .executableTarget(
            name: "CameraBridgeApp",
            dependencies: ["CameraBridgeClientSwift", "CameraBridgeSupport"],
            path: "apps/CameraBridgeApp/Sources/CameraBridgeApp"
        ),
        .testTarget(
            name: "CameraBridgeCoreTests",
            dependencies: ["CameraBridgeCore"],
            path: "tests/CameraBridgeCoreTests"
        ),
        .testTarget(
            name: "CameraBridgeAPITests",
            dependencies: ["CameraBridgeAPI"],
            path: "tests/CameraBridgeAPITests"
        ),
        .testTarget(
            name: "CameraBridgeClientSwiftTests",
            dependencies: ["CameraBridgeClientSwift"],
            path: "tests/CameraBridgeClientSwiftTests"
        ),
        .testTarget(
            name: "CameraBridgeSupportTests",
            dependencies: ["CameraBridgeSupport"],
            path: "tests/CameraBridgeSupportTests"
        ),
        .testTarget(
            name: "CameraBridgeAppTests",
            dependencies: ["CameraBridgeApp"],
            path: "tests/CameraBridgeAppTests"
        ),
        .testTarget(
            name: "CameraBridgeDaemonTests",
            dependencies: ["camd"],
            path: "tests/CameraBridgeDaemonTests"
        ),
    ]
)
