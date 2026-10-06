import CombatPadKit
import Foundation

/// Reads stat-block Strikes from `melee` items.
enum StrikeParser {
    static func strikes(_ items: [JSONValue]) -> [Strike] {
        let abilityNames = abilitiesBySlug(items).mapValues { $0["name"].string }
        return items.filter { $0["type"].string == "melee" }.map { strike($0, abilityNames: abilityNames) }
    }

    /// The creature's `action` items by slug, which Strike effects name.
    static func abilitiesBySlug(_ items: [JSONValue]) -> [String: JSONValue] {
        Dictionary(
            items.filter { $0["type"].string == "action" && !$0[path: "system.slug"].string.isEmpty }
                .map { ($0[path: "system.slug"].string, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private static func strike(_ item: JSONValue, abilityNames: [String: String]) -> Strike {
        let system = item["system"]
        let range = system["range"]
        var traits = system[path: "traits.value"].strings
        if let increment = range["increment"].optionalInt {
            traits.append("range increment \(increment) feet")
        } else if let maximum = range["max"].optionalInt {
            traits.append("range \(maximum) feet")
        }
        var strike = Strike(
            name: item["name"].string,
            isRanged: !range.isNull,
            attackBonus: system[path: "bonus.value"].int,
            traits: traits,
            damage: damage(system["damageRolls"])
        )
        strike.effects = system[path: "attackEffects.value"].strings.map { abilityNames[$0] ?? Words.label($0) }
        strike.areaNote = areaNote(system)
        return strike
    }

    /// Foundry keys damage instances by random IDs, so their order is lost. The base instance, the one
    /// templates adjust, is put first: the first non-persistent part, preferring one with a modifier.
    static func damage(_ rolls: JSONValue) -> [DamagePart] {
        let parts = rolls.object.keys.sorted().map { key -> DamagePart in
            let roll = rolls[key]
            let category = roll["category"].string
            let type = [category == "persistent" ? "" : category, roll["damageType"].string]
                .filter { !$0.isEmpty }.joined(separator: " ")
            return DamagePart(
                formula: roll["damage"].string.replacingOccurrences(of: " ", with: ""),
                type: type,
                isPersistent: category == "persistent" || roll["damageType"].string == "bleed"
            )
        }
        return parts.sorted { rank($0) < rank($1) }
    }

    private static func rank(_ part: DamagePart) -> Int {
        if part.isPersistent { return 3 }
        if part.type.hasPrefix("precision") || part.type.hasPrefix("splash") { return 2 }
        return part.formula.contains("+") || part.formula.contains("-") ? 0 : 1
    }

    private static func areaNote(_ system: JSONValue) -> String {
        let action = system["action"].string
        guard !action.isEmpty, action != "strike" else { return "" }
        let area = system["area"]
        let label = Words.label(action)
        guard let size = area["value"].optionalInt else { return label }
        return "\(label) (\(size)-foot \(area["type"].string))"
    }
}
