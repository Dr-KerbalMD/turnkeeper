import CombatPadKit
import Foundation
@testable import FoundryImport

/// Loads the real Foundry documents copied into `Fixtures` and parses them.
enum Fixtures {
    static func document(_ name: String) throws -> JSONValue {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") else {
            throw FixtureError.missing(name)
        }
        return try JSONValue(contentsOf: url)
    }

    static func creature(_ name: String, game: Game = .pathfinder, pack: String = "test-pack") throws -> Creature {
        var parser = CreatureParser(text: converter())
        guard let creature = parser.creature(from: try document(name), game: game, pack: pack) else {
            throw FixtureError.notACreature(name)
        }
        return creature
    }

    /// A converter whose only localization is the Reactive Strike glossary entry.
    static func converter() -> RulesTextConverter {
        let glossary = JSONValue.object([
            "PF2E": .object(["NPC": .object(["Abilities": .object(["Glossary": .object([
                "ReactiveStrike": .string("<p><strong>Trigger</strong> A creature moves.</p>")
            ])])])])
        ])
        return RulesTextConverter(localizer: Localizer(roots: [glossary]))
    }

    enum FixtureError: Error {
        case missing(String)
        case notACreature(String)
    }
}
