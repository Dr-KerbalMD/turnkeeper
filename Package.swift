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
        .target(name: "FoundryImport", dependencies: ["CombatPadKit"]),
        .executableTarget(name: "BestiaryImport", dependencies: ["FoundryImport"]),
        .executableTarget(name: "CardSnapshots", dependencies: ["CombatPadUI"]),
        .testTarget(
            name: "CombatPadKitTests",
            dependencies: ["CombatPadKit"]
        ),
        .testTarget(
            name: "FoundryImportTests",
            dependencies: ["FoundryImport"],
            resources: [.copy("Fixtures")]
        )
    ]
)
