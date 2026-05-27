// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Portzilla",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Portzilla",
            path: "Sources/Portzilla"
        ),
        .testTarget(
            name: "PortzillaTests",
            dependencies: ["Portzilla"],
            path: "Tests/PortzillaTests"
        )
    ]
)
