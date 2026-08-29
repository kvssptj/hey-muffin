// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Muffin",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "MuffinCore", targets: ["MuffinCore"]),
        .executable(name: "muffin", targets: ["muffin"]),
        .executable(name: "muffin-mcp", targets: ["muffin-mcp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "MuffinCore",
            path: "Sources/MuffinCore",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
        .executableTarget(
            name: "muffin",
            dependencies: [
                "MuffinCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/muffin",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
        .executableTarget(
            name: "muffin-mcp",
            dependencies: ["MuffinCore"],
            path: "Sources/muffin-mcp",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
    ]
)
