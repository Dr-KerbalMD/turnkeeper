import CombatPadKit
import Foundation

/// Reads the condition packs. Starfinder gets every Pathfinder condition plus its own.
public enum ConditionImporter {
    public static func conditions(
        scanner: PackScanner, text: inout RulesTextConverter
    ) throws -> [ConditionDefinition] {
        var bySlug: [String: ConditionDefinition] = [:]
        for game in Game.allCases {
            let packs = try scanner.packs(of: game, type: "Item").filter { $0.name == "conditions" }
            for file in packs.flatMap(scanner.documentFiles) {
                let document = try JSONValue(contentsOf: file)
                let slug = file.deletingPathExtension().lastPathComponent
                var condition = bySlug[slug] ?? ConditionDefinition(
                    slug: slug,
                    name: document["name"].string,
                    games: [],
                    isValued: document[path: "system.value.isValued"].bool,
                    text: text.convert(document[path: "system.description.value"].string)
                )
                condition.games = gamesHaving(condition, adding: game)
                bySlug[slug] = condition
            }
        }
        return bySlug.values.sorted { $0.slug < $1.slug }
    }

    private static func gamesHaving(_ condition: ConditionDefinition, adding game: Game) -> [Game] {
        let games = Set(condition.games + [game] + (game == .pathfinder ? [.starfinder] : []))
        return Game.allCases.filter(games.contains)
    }
}
