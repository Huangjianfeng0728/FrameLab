// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FrameLab",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "FrameLab", targets: ["PicAnalysisApp"])
    ],
    targets: [
        .executableTarget(
            name: "PicAnalysisApp"
        ),
        .testTarget(
            name: "PicAnalysisAppTests",
            dependencies: ["PicAnalysisApp"]
        )
    ]
)
