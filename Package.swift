// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WortagCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "WortagCore", targets: ["WortagCore"])],
    targets: [
        .target(name: "WortagCore", path: "Shared", exclude: ["Theme.swift", "WordIntents.swift"]),
        .testTarget(name: "WortagCoreTests", dependencies: ["WortagCore"], path: "Tests")
    ]
)
