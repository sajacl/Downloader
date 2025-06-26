// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Downloader",
    products: [
        .library(
            name: "Downloader",
            targets: ["Downloader"]),
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
