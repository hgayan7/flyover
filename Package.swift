// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BreakPlane",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "BreakPlane",
            path: "Sources/BreakPlane",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
