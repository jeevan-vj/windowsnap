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
            // Exclude plist (handled by bundle in Xcode) and asset catalog which SPM CLI build cannot process.
            exclude: ["App/Info.plist", "App/Assets.xcassets"],
            sources: [
                "App/",
                "Core/",
                "UI/",
                "Models/",
                "Utils/"
            ]
        ),
    ]
)