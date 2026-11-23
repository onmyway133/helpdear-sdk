// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Helpdear",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "Helpdear", targets: ["Helpdear"]),
    ],
    targets: [
        .target(name: "Helpdear"),
        .testTarget(name: "HelpdearTests", dependencies: ["Helpdear"]),
    ]
)
