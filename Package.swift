// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IdleVillager",
    // English is the development language and the fallback when the system language is not supported.
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "IdleVillagerCore", targets: ["IdleVillagerCore"]),
        .executable(name: "IdleVillagerApp", targets: ["IdleVillagerApp"]),
    ],
    targets: [
        // UI string tables live in Resources/<language>.lproj/Localizable.strings (see L10n).
        .target(name: "IdleVillagerCore", resources: [.process("Resources")]),
        .executableTarget(
            name: "IdleVillagerApp",
            dependencies: ["IdleVillagerCore"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "IdleVillagerCoreTests",
            dependencies: ["IdleVillagerCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
