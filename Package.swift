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
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.6")
    ],
    targets: [
        .executableTarget(
            name: "RecallMac",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/RecallMac",
            resources: [
                .copy("Resources/Doubtabase-logo-v2.png")
            ],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
            ]
        )
    ]
)
