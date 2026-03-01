// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BlackBox",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "BlackBox", targets: ["BlackBox"]),
    ],
    dependencies: [
        // Stripe/Paddle SDK would go here for production
    ],
    targets: [
        .executableTarget(
            name: "BlackBox",
            dependencies: [],
            path: "BlackBox",
            resources: [
                .process("Resources"),
                .process("Shaders")
            ]
        ),
        .testTarget(
            name: "BlackBoxTests",
            dependencies: ["BlackBox"],
            path: "BlackBoxTests"
        ),
    ]
)
