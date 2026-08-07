// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AnchorCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AnchorCore", targets: ["AnchorCore"])
    ],
    targets: [
        .target(
            name: "AnchorCore",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "AnchorCoreTests",
            dependencies: ["AnchorCore"]
        ),
    ]
)
