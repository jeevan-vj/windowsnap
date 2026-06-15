// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WindowSnap",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "WindowSnap",
            targets: ["WindowSnap"]
        ),
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "WindowSnap",
            dependencies: [],
            path: "WindowSnap",
            exclude: ["App/Info.plist", "App/Assets.xcassets"],
            sources: [
                "App/",
                "Core/",
                "UI/",
                "Models/",
                "Utils/"
            ]
        ),
        .testTarget(
            name: "WindowSnapTests",
            dependencies: ["WindowSnap"],
            path: "Tests/WindowSnapTests"
        ),
    ]
)
