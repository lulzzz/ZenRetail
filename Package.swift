// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ZenRetail",
    platforms: [
        .macOS(.v10_14)
    ],
    products: [
        .library(
            name: "ZenRetailCore",
            targets: ["ZenRetailCore"]),
        .executable(
            name: "ZenRetail",
            targets: ["ZenRetail"]),
    ],
    dependencies: [
        .package(url: "https://github.com/gerardogrisolini/ZenNIO.git", .branch("master")),
        .package(url: "https://github.com/gerardogrisolini/ZenPostgres.git", .branch("master")),
        .package(url: "https://github.com/gerardogrisolini/ZenSMTP.git", .branch("master")),
        .package(url: "https://github.com/gerardogrisolini/ZenMWS.git", .branch("master")),
        .package(url: "https://github.com/gerardogrisolini/ZenEBAY.git", .branch("master")),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", .branch("master")),
        .package(url: "https://github.com/twostraws/SwiftGD.git", .branch("master")),
    ],
    targets: [
        .target(
            name: "ZenRetailCore",
            dependencies: ["ZenNIO", "ZenPostgres", "ZenSMTP", "ZenMWS", "ZenEBAY", "CryptoSwift", "SwiftGD"]),
        .target(
            name: "ZenRetail",
            dependencies: ["ZenRetailCore"]),
        .testTarget(
            name: "ZenRetailTests",
            dependencies: ["ZenRetailCore"]),
    ],
    swiftLanguageVersions: [.v5]
)
