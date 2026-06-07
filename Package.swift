// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ForCon",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "FormatConverterCore",
            targets: ["FormatConverterCore"]
        ),
        .executable(
            name: "ForCon",
            targets: ["ForCon"]
        )
    ],
    targets: [
        .target(
            name: "FormatConverterCore",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .executableTarget(
            name: "ForCon",
            dependencies: ["FormatConverterCore"]
        ),
        .testTarget(
            name: "FormatConverterCoreTests",
            dependencies: ["FormatConverterCore"]
        )
    ]
)
