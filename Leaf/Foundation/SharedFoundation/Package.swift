// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SharedFoundation",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
    dependencies: [
        .package(path: "../AppInfo")
        .package(path: "../Router")
    ],
            name: "SharedFoundation",
            targets: ["SharedFoundation"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SharedFoundation"),
        .testTarget(
            name: "SharedFoundationTests",
            dependencies: ["SharedFoundation"]
        ),
    ]
)
