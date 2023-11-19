
// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EVPlayer",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "EVPlayer",
            targets: ["EVPlayer"])
    ],
    dependencies: [
        // List your dependencies here
    ],
    targets: [
        .target(
            name: "EVPlayer",
            dependencies: [],
            path: "Source",
            resources: [.copy("EVPlayer/Resources")]
        )
    ]
)
