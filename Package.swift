// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "TextureMap",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .macOS(.v10_15),
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
