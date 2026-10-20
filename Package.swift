// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Fluor",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .executable(name: "Fluor", targets: ["Fluor"]),
    ],
    targets: [
        .executableTarget(
            name: "Fluor",
            path: "Fluor",
            exclude: [
                ".DS_Store",
                "AppIcon.icon",
                "Assets.xcassets",
                "Base.lproj",
                "Fluor.entitlements",
                "Info.plist",
                "en.lproj",
                "fr.lproj",
                "zh-Hans.lproj",
            ]
        ),
        .testTarget(
            name: "FluorTests",
            dependencies: ["Fluor"],
            path: "FluorTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
