// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WashMyMac",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "WashMyMac",
            path: "Sources/WashMyMac"
        )
    ]
)
