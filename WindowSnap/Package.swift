// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WindowSnap",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "WindowSnap",
            targets: ["WindowSnap"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "CVirtualDisplay",
            path: "CVirtualDisplay",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "WindowSnap",
            dependencies: ["CVirtualDisplay"],
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
