// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "S3Test",
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        //.package(path: "../../../aws-lambda-swift-sprinter-core"),
        .package(url: "https://github.com/swift-sprinter/aws-lambda-swift-sprinter-core", from: "1.0.0-alpha.2"),
        .package(url: "https://github.com/Andrea-Scuderi/aws-sdk-swift.git", .branch("nio2.0-swift5.1")),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "S3Test",
            dependencies: ["LambdaSwiftSprinter", "S3", "Logging"]
        ),
        .testTarget(
            name: "S3TestTests",
            dependencies: ["S3Test"]
        ),
    ]
)
