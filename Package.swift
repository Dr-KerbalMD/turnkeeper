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
    dependencies: [
        .package(url: "https://github.com/scooper4711/tabletop-kit.git", from: "0.3.0")
    ],
    targets: [
        .target(name: "CombatPadKit"),
        .target(name: "CombatPadUI", dependencies: [
            "CombatPadKit", "CharacterImport", .product(name: "ArtExtraction", package: "tabletop-kit")
        ]),
        .target(name: "CharacterImport", dependencies: ["CombatPadKit"]),
        .executableTarget(name: "CombatPad", dependencies: ["CombatPadUI"]),
        .target(name: "FoundryImport", dependencies: ["CombatPadKit"]),
        .executableTarget(name: "BestiaryImport", dependencies: ["FoundryImport"]),
        .executableTarget(name: "CardSnapshots", dependencies: ["CombatPadUI"]),
        .testTarget(
            name: "CombatPadKitTests",
            dependencies: ["CombatPadKit"]
        ),
        .testTarget(
            name: "CharacterImportTests",
            dependencies: ["CharacterImport"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "FoundryImportTests",
            dependencies: ["FoundryImport"],
            resources: [.copy("Fixtures")]
        )
    ]
)
