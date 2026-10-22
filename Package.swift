// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Kill3000",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "Kill3000Engine",
            targets: ["Kill3000Engine"]
        ),
        .executable(
            name: "Kill3000App",
            targets: ["Kill3000App"]
        )
    ],
    targets: [
        .target(
            name: "Kill3000Engine",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "Kill3000App",
            dependencies: ["Kill3000Engine"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "Kill3000EngineTests",
            dependencies: ["Kill3000Engine"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "Kill3000AppTests",
            dependencies: ["Kill3000App"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)
