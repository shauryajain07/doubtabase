// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "RecallMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "RecallMac",
            targets: ["RecallMac"]
        )
    ],
    targets: [
        .executableTarget(
            name: "RecallMac",
            path: "Sources/RecallMac",
            resources: [
                .copy("Resources/Doubtabase-logo-v2.png")
            ]
        )
    ]
)
