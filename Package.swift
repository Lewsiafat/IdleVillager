// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IdleVillager",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "IdleVillagerCore", targets: ["IdleVillagerCore"]),
        .executable(name: "IdleVillagerApp", targets: ["IdleVillagerApp"]),
    ],
    targets: [
        .target(name: "IdleVillagerCore"),
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
