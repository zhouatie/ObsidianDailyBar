// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ObsidianDailyBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "ObsidianDailyBar",
            targets: ["ObsidianDailyBar"]
        )
    ],
    targets: [
        .executableTarget(
            name: "ObsidianDailyBar",
            path: "Sources/ObsidianDailyBar"
        ),
        .testTarget(
            name: "ObsidianDailyBarTests",
            dependencies: ["ObsidianDailyBar"],
            path: "Tests/ObsidianDailyBarTests"
        )
    ]
)
