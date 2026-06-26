// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DoableCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DoableCore", targets: ["DoableCore"]),
    ],
    targets: [
        .target(name: "DoableCore"),
        .testTarget(name: "DoableCoreTests", dependencies: ["DoableCore"]),
    ]
)
