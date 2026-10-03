import CombatPadKit
import Foundation

/// Reads `action` items into stat-block abilities.
enum AbilityParser {
    static func ability(_ item: JSONValue, text: RulesText) -> Ability {
        let system = item["system"]
        var ability = Ability(
            name: item["name"].string,
            cost: cost(system),
            section: AbilitySection(rawValue: system["category"].string) ?? .offensive,
            text: text
        )
        ability.traits = system[path: "traits.value"].strings
        ability.frequency = frequency(system["frequency"], text: text)
        return ability
    }

    private static func cost(_ system: JSONValue) -> ActionCost {
        switch system[path: "actionType.value"].string {
        case "reaction": return .reaction
        case "free": return .free
        case "action": return ActionCost(actions: system[path: "actions.value"].int)
        default: return .none
        }
    }

    private static let periods = [
        "round": "round", "turn": "turn", "day": "day", "PT1M": "minute", "PT10M": "10 minutes",
        "PT1H": "hour", "PT24H": "day", "P1W": "week", "P1M": "month", "P1Y": "year"
    ]

    /// "1/day" from the frequency field, or "listed" when the text has its own Frequency line.
    private static func frequency(_ frequency: JSONValue, text: RulesText) -> String {
        if let maximum = frequency["max"].optionalInt {
            let per = frequency["per"].string
            return "\(maximum)/\(periods[per] ?? per)"
        }
        return text.markup.contains("**Frequency**") ? "listed" : ""
    }
}
