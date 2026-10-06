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

    /// A small copy of the pf2e repository: a few spells, conditions and glossary abilities, the language
    /// files and `traits.ts`.
    static func repository() throws -> URL {
        guard let url = Bundle.module.url(forResource: "repo", withExtension: nil, subdirectory: "Fixtures") else {
            throw FixtureError.missing("repo")
        }
        return url
    }

    /// A link resolver over the fixture repository.
    static func links() throws -> LinkResolver {
        let repository = try repository()
        let localizer = try Localizer(languageDirectory: repository.appendingPathComponent("static/lang"))
        return LinkResolver(
            compendium: try CompendiumIndex(scanner: PackScanner(repository: repository)),
            traits: TraitGlossary(repository: repository, localizer: localizer)
        )
    }

    /// A converter that links into the fixture repository.
    static func linkingConverter(_ links: LinkResolver) -> RulesTextConverter {
        RulesTextConverter(localizer: Localizer(roots: []), links: links)
    }

    /// `linked-creature.json`, parsed with links into the fixture repository, and its resolver.
    static func linkedCreature() throws -> (Creature, LinkResolver) {
        let links = try links()
        var parser = CreatureParser(text: linkingConverter(links))
        guard let creature = parser.creature(from: try document("linked-creature"), game: .pathfinder,
                                             pack: "test-pack") else {
            throw FixtureError.notACreature("linked-creature")
        }
        return (creature, links)
    }

    enum FixtureError: Error {
        case missing(String)
        case notACreature(String)
    }
}
