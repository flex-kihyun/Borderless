// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SharedFeature",
    platforms: [.iOS(.v18)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SharedFeature",
            targets: ["SharedFeature"]),
    ],
    dependencies: [
        .package(path: "../Contract")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SharedFeature",
            dependencies: ["Contract"]),
        .testTarget(
            name: "SharedFeatureTests",
            dependencies: ["SharedFeature"]
        ),
    ]
)
