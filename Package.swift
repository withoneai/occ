// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OCC",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "OCC",
            path: "OCC",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
