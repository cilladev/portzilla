// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Portzilla",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "Portzilla",
            dependencies: ["KeyboardShortcuts"],
            path: "Sources/Portzilla"
        ),
        .testTarget(
            name: "PortzillaTests",
            dependencies: ["Portzilla"],
            path: "Tests/PortzillaTests"
        )
    ]
)
