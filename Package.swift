// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SwitchNet",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "SwitchNet"
        )
    ]
)
