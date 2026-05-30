// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NotchAgent",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Sparkle — auto-update framework. Pinned to 2.6+ for stable
        // SPUStandardUpdaterController + ed25519 signature verification.
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .target(
            name: "NotchAgentCore",
            path: "Sources/NotchAgentCore"
        ),
        .executableTarget(
            name: "NotchAgent",
            dependencies: [
                "NotchAgentCore",
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "Yams", package: "Yams"),
            ],
            path: "Sources/NotchAgent",
            resources: [
                .copy("Resources")
            ]
        ),
        .executableTarget(
            name: "notchagent-bridge",
            dependencies: ["NotchAgentCore"],
            path: "Sources/NotchAgentBridge"
        ),
        .executableTarget(
            name: "notchagent-cli",
            dependencies: ["NotchAgentCore"],
            path: "Sources/NotchAgentCLI"
        ),
        .testTarget(
            name: "NotchAgentCoreTests",
            dependencies: ["NotchAgentCore"],
            path: "Tests/NotchAgentCoreTests"
        ),
        .testTarget(
            name: "NotchAgentTests",
            dependencies: [
                "NotchAgent",
                .product(name: "Yams", package: "Yams"),
            ],
            path: "Tests/NotchAgentTests"
        ),
    ]
)
