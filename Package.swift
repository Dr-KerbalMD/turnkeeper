// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CombatPad",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "CombatPadKit", targets: ["CombatPadKit"]),
        .library(name: "CombatPadUI", targets: ["CombatPadUI"]),
        .executable(name: "CombatPad", targets: ["CombatPad"]),
        .executable(name: "BestiaryImport", targets: ["BestiaryImport"])
    ],
    targets: [
        .target(name: "CombatPadKit"),
        .target(name: "CombatPadUI", dependencies: ["CombatPadKit"]),
        .executableTarget(name: "CombatPad", dependencies: ["CombatPadUI"]),
        .executableTarget(name: "BestiaryImport", dependencies: ["CombatPadKit"]),
        .testTarget(
            name: "CombatPadKitTests",
            dependencies: ["CombatPadKit"],
            resources: [.copy("Fixtures")]
        )
    ]
)
