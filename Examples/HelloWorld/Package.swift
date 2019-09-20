// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HelloWorld",
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(path: "../../../aws-lambda-swift-sprinter-core"),
        //.package(url: "https://github.com/swift-sprinter/aws-lambda-swift-sprinter-core", from: "1.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "HelloWorld",
            dependencies: ["LambdaSwiftSprinter"]
        ),
        .testTarget(
            name: "HelloWorldTests",
            dependencies: ["HelloWorld"]
        ),
    ]
)
