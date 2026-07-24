// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwVisionKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SwVisionKit", targets: ["SwVisionKit"]),
    ],
    targets: [
        .target(name: "SwVisionKit"),
        .testTarget(name: "SwVisionKitTests", dependencies: ["SwVisionKit"]),
    ]
)
