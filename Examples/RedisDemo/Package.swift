// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RedisDemo",
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/swift-sprinter/aws-lambda-swift-sprinter-nio-plugin", from: "1.0.0-alpha.3"),
        .package(url: "https://gitlab.com/mordil/swift-redi-stack.git", from: "1.0.0-alpha.5"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A starget can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "RedisDemo",
            dependencies: ["LambdaSwiftSprinterNioPlugin", "Logging", "RediStack"]),
        .testTarget(
            name: "RedisDemoTests",
            dependencies: ["RedisDemo"]),
    ]
)
