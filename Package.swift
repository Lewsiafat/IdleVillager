// swift-tools-version: 6.0
import PackageDescription

// IdleVillagerApp 依賴 SwiftUI 與 AppKit，只能在 macOS 上建置。
// Linux（包含 Cloud Agent）仍建置並測試 IdleVillagerCore。macOS 的產品與 target 維持不變。
#if os(macOS)
let idleVillagerProducts: [Product] = [
    .library(name: "IdleVillagerCore", targets: ["IdleVillagerCore"]),
    .executable(name: "IdleVillagerApp", targets: ["IdleVillagerApp"]),
]
let idleVillagerAppTargets: [Target] = [
    .executableTarget(
        name: "IdleVillagerApp",
        dependencies: ["IdleVillagerCore"],
        resources: [.process("Resources")]
    ),
]
#else
let idleVillagerProducts: [Product] = [
    .library(name: "IdleVillagerCore", targets: ["IdleVillagerCore"]),
]
let idleVillagerAppTargets: [Target] = []
#endif

let package = Package(
    name: "IdleVillager",
    platforms: [.macOS(.v14)],
    products: idleVillagerProducts,
    targets: [
        .target(name: "IdleVillagerCore"),
    ] + idleVillagerAppTargets + [
        .testTarget(
            name: "IdleVillagerCoreTests",
            dependencies: ["IdleVillagerCore"]
        ),
    ]
)
