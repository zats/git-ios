// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GitIOS",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "GitIOS", targets: ["git", "gitremote"]),
    ],
    targets: [
        .binaryTarget(
            name: "git",
            path: "Artifacts/git.xcframework"
        ),
        .binaryTarget(
            name: "gitremote",
            path: "Artifacts/gitremote.xcframework"
        ),
    ]
)
