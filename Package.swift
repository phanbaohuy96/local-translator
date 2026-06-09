// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "local-translator",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "local-translator"
        ),
        .testTarget(
            name: "local-translatorTests",
            dependencies: ["local-translator"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
