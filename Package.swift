// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Clipd",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Clipd", targets: ["Clipd"])
    ],
    targets: [
        .executableTarget(
            name: "Clipd",
            path: "Clipd",
            exclude: [
                "Assets.xcassets",
                "Info.plist",
                "Clipd.entitlements"
            ]
        )
    ]
)
