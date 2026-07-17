// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Flyover",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Flyover",
            path: "Sources/Flyover",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
