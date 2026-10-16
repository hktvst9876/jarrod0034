// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SteadyCore",
    platforms: [
        .iOS(.v18),
        .watchOS(.v11),
        .macOS(.v15)
    ],
    products: [
        .library(name: "SteadyCore", targets: ["SteadyCore"])
    ],
    targets: [
        .target(name: "SteadyCore"),
        .testTarget(
            name: "SteadyCoreTests",
            dependencies: ["SteadyCore"],
            resources: [.copy("Resources")]
        )
    ]
)
