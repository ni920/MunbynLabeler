// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "MunbynLabeler",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "LabelCore", targets: ["LabelCore"]),
        .executable(name: "MunbynLabeler", targets: ["MunbynLabeler"]),
        .executable(name: "LabelCoreSelfTest", targets: ["LabelCoreSelfTest"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")
    ],
    targets: [
        .target(name: "LabelCore"),
        .executableTarget(
            name: "MunbynLabeler",
            dependencies: [
                "LabelCore",
                .product(name: "Sparkle", package: "Sparkle")
            ]
        ),
        .executableTarget(
            name: "LabelCoreSelfTest",
            dependencies: ["LabelCore"]
        )
    ]
)
