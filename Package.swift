// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "TranslateMac",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "TranslateMac", targets: ["TranslateMac"]),
    ],
    targets: [
        .target(name: "TranslateCore"),
        .target(name: "TranslateUI", dependencies: ["TranslateCore"]),
        .executableTarget(name: "TranslateMac", dependencies: ["TranslateUI", "TranslateCore"]),
        .testTarget(name: "TranslateCoreTests", dependencies: ["TranslateCore"]),
    ]
)
