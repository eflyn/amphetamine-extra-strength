// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "AmphetamineExtraStrength",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "AmphetamineExtraStrength",
            targets: ["AmphetamineExtraStrength"]
        )
    ],
    targets: [
        .executableTarget(
            name: "AmphetamineExtraStrength",
            path: "Sources/AmphetamineExtraStrength"
        )
    ],
    swiftLanguageVersions: [.v5]
)
