// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "inkypanels",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "InkyPanelsCore",
            targets: ["InkyPanelsCore"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.15.0"),
    ],
    targets: [
        .target(
            name: "InkyPanelsCore",
            dependencies: [
                "ZIPFoundation",
            ],
            path: "inkypanels",
            exclude: [
                "Preview Content",
                "Resources/Info.plist",
                "Resources/Assets.xcassets"
            ]
        ),
        .testTarget(
            name: "InkyPanelsTests",
            dependencies: [
                "InkyPanelsCore",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "inkypanelsTests",
            resources: [
                .copy("Fixtures")
            ]
        ),
    ]
)
