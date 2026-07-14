// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MirrorMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MirrorMac", targets: ["MirrorMacApp"])
    ],
    targets: [
        .executableTarget(
            name: "MirrorMacApp",
            path: "Sources/MirrorMacApp",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
