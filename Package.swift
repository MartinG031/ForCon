// swift-tools-version: 5.10

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
        .target(name: "FormatConverterCore"),
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
