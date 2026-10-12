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
        .package(url: "https://github.com/scooper4711/tabletop-kit.git", from: "0.9.0")
    ],
    targets: [
        .target(name: "CombatPadKit", dependencies: [.product(name: "Bestiary", package: "tabletop-kit")]),
        .target(name: "CombatPadUI", dependencies: [
            "CombatPadKit", "CharacterImport", .product(name: "ArtExtraction", package: "tabletop-kit"),
            .product(name: "BattleCards", package: "tabletop-kit"),
            .product(name: "CreatureArt", package: "tabletop-kit")
        ]),
        .target(name: "CharacterImport", dependencies: ["CombatPadKit"]),
        .executableTarget(name: "CombatPad", dependencies: ["CombatPadUI"]),
        .executableTarget(name: "BestiaryImport", dependencies: [
            .product(name: "CreatureImport", package: "tabletop-kit")
        ]),
        .executableTarget(name: "CardSnapshots", dependencies: ["CombatPadUI"]),
        .testTarget(
            name: "CombatPadKitTests",
            dependencies: ["CombatPadKit"]
        ),
        .testTarget(
            name: "CharacterImportTests",
            dependencies: ["CharacterImport"],
            resources: [.copy("Fixtures")]
        )
    ]
)
