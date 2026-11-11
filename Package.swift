// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Zeigerreiter",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Zeigerreiter", path: "Sources/Zeigerreiter")
    ]
)
