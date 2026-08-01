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
        .target(
            name: "KeyboardBacklightBridge",
            path: "Sources/KeyboardBacklightBridge",
            publicHeadersPath: "include",
            cSettings: [
                .unsafeFlags(["-fobjc-arc"])
            ]
        ),
        .executableTarget(
            name: "AmphetamineExtraStrength",
            dependencies: ["KeyboardBacklightBridge"],
            path: "Sources/AmphetamineExtraStrength"
        )
    ],
    swiftLanguageVersions: [.v5]
)
