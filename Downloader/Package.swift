// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Downloader",
    platforms: [.iOS(.v14), .macOS(.v13)],
    products: [
        .library(
            name: "Downloader",
            targets: ["Downloader"]
        ),
    ],
    targets: [
        .target(
            name: "Downloader"
        ),
        .testTarget(
            name: "DownloaderTests",
            dependencies: ["Downloader"]
        ),
    ]
)
