// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TextureMap",
    platforms: [
        .iOS(.v16),
        .tvOS(.v16),
        .macOS(.v13),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "TextureMap",
            targets: ["TextureMap"]),
    ],
    targets: [
        .target(
            name: "TextureMap",
            dependencies: []),
        .testTarget(
            name: "TextureMapTests",
            dependencies: ["TextureMap"]),
    ]
)
