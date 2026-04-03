// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OneCC",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "OneCC",
            path: "OCC",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
