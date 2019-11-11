// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HTTPSRequest",
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        //.package(path: "../../../aws-lambda-swift-sprinter-nio-plugin"),
        .package(url: "https://github.com/Andrea-Scuderi/aws-lambda-swift-sprinter-nio-plugin", from: "1.0.0-alpha.3"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "HTTPSRequest",
            dependencies: ["LambdaSwiftSprinterNioPlugin", "Logging"]
        ),
        .testTarget(
            name: "HTTPSRequestTests",
            dependencies: ["HTTPSRequest"]
        ),
    ]
)
