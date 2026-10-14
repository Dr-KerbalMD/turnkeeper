// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Turnkeeper",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "TurnkeeperKit", targets: ["TurnkeeperKit"]),
        .library(name: "TurnkeeperUI", targets: ["TurnkeeperUI"]),
        .executable(name: "Turnkeeper", targets: ["Turnkeeper"]),
        .executable(name: "BestiaryImport", targets: ["BestiaryImport"])
    ],
    dependencies: [
        .package(url: "https://github.com/scooper4711/tabletop-kit.git", from: "0.13.0")
    ],
    targets: [
        .target(name: "TurnkeeperKit", dependencies: [.product(name: "Bestiary", package: "tabletop-kit")]),
        .target(name: "TurnkeeperUI", dependencies: [
            "TurnkeeperKit", "CharacterImport", .product(name: "ArtExtraction", package: "tabletop-kit"),
            .product(name: "BattleCards", package: "tabletop-kit"),
            .product(name: "CreatureArt", package: "tabletop-kit"),
            .product(name: "AppNotices", package: "tabletop-kit")
        ]),
        .target(name: "CharacterImport", dependencies: ["TurnkeeperKit"]),
        .executableTarget(name: "Turnkeeper", dependencies: ["TurnkeeperUI"]),
        .executableTarget(name: "BestiaryImport", dependencies: [
            .product(name: "CreatureImport", package: "tabletop-kit")
        ]),
        .executableTarget(name: "CardSnapshots", dependencies: ["TurnkeeperUI"]),
        .testTarget(
            name: "TurnkeeperKitTests",
            dependencies: ["TurnkeeperKit"]
        ),
        .testTarget(
            name: "CharacterImportTests",
            dependencies: ["CharacterImport"],
            resources: [.copy("Fixtures")]
        )
    ]
)
