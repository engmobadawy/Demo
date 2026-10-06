// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NetworkLayer",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "NetworkLayer", targets: ["NetworkLayer"]),
    ],
    targets: [
        .target(name: "NetworkLayer"),
        .testTarget(name: "NetworkLayerTests", dependencies: ["NetworkLayer"]),
    ]
)
