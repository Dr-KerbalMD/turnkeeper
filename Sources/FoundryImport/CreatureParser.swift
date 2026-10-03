import CombatPadKit
import Foundation

/// Builds a `Creature` from a Foundry NPC or complex hazard document.
public struct CreatureParser {
    public var text: RulesTextConverter

    public init(text: RulesTextConverter) {
        self.text = text
    }

    /// Returns nil for documents that are not NPCs or complex hazards.
    public mutating func creature(from document: JSONValue, game: Game, pack: String) -> Creature? {
        guard let kind = Self.kind(of: document) else { return nil }
        let system = document["system"]
        let items = document["items"].array
        var creature = Creature(key: "\(game.rawValue).\(pack).\(document["_id"].string)",
                                name: document["name"].string, game: game)
        creature.kind = kind
        creature.level = system[path: "details.level.value"].int
        creature.traits = StatisticsParser.traitLine(system["traits"])
        creature.source = StatisticsParser.source(system[path: "details.publication"], pack: pack)
        creature.senses = StatisticsParser.senses(system["perception"])
        creature.languages = StatisticsParser.languages(system[path: "details.languages"])
        creature.skills = StatisticsParser.skills(system["skills"], items: items)
        creature.attributes = StatisticsParser.attributes(system["abilities"])
        creature.items = StatisticsParser.inventory(items)
        creature.defenses = StatisticsParser.defenses(system)
        creature.speeds = StatisticsParser.speeds(system[path: "attributes.speed"])
        creature.strikes = StrikeParser.strikes(items)
        creature.spellcasting = SpellcastingParser.entries(items, creatureLevel: creature.level)
        creature.initiativeStatistic = Self.initiativeStatistic(system, kind: kind)
        creature.abilities = abilities(items)
        if kind == .hazard { creature.hazard = hazardDetails(system) }
        return creature
    }

    static func kind(of document: JSONValue) -> CreatureKind? {
        switch document["type"].string {
        case "npc": return .creature
        case "hazard": return document[path: "system.details.isComplex"].bool ? .hazard : nil
        default: return nil
        }
    }

    private static func initiativeStatistic(_ system: JSONValue, kind: CreatureKind) -> String {
        let statistic = system[path: "initiative.statistic"].string
        if !statistic.isEmpty { return statistic }
        return kind == .hazard ? "stealth" : "perception"
    }

    private mutating func abilities(_ items: [JSONValue]) -> [Ability] {
        items.filter { $0["type"].string == "action" }.map { item in
            AbilityParser.ability(item, text: text.convert(item[path: "system.description.value"].string))
        }
    }

    private mutating func hazardDetails(_ system: JSONValue) -> HazardDetails {
        let details = system["details"]
        var hazard = HazardDetails(
            stealth: system[path: "attributes.stealth.value"].int,
            description: text.convert(details["description"].string)
        )
        hazard.stealthDetails = text.convert(system[path: "attributes.stealth.details"].string)
        hazard.disable = text.convert(details["disable"].string)
        hazard.routine = text.convert(details["routine"].string)
        hazard.reset = text.convert(details["reset"].string)
        return hazard
    }
}
