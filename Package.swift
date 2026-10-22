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
    targets: [
        .target(name: "LabelCore"),
        .executableTarget(
            name: "MunbynLabeler",
            dependencies: ["LabelCore"]
        ),
        .executableTarget(
            name: "LabelCoreSelfTest",
            dependencies: ["LabelCore"]
        )
    ]
)
