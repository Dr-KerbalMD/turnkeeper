import Foundation

/// Reading Speed, Strikes, spells, hazard text and abilities.
extension StatBlockConverter {
    mutating func readOffense(_ entry: PluckStatBlock.Entry) -> Bool {
        switch entry.name {
        case "Speed":
            creature.speeds = StatBlockText.speeds(StatBlockText.list(entry.text, separator: ";").first ?? "")
        case "Melee", "Ranged": readStrike(entry)
        case "Description", "Disable", "Routine", "Reset" where creature.kind == .hazard: readHazardText(entry)
        default:
            guard entry.name.hasSuffix("Spells") || entry.name.hasSuffix("Rituals") else { return false }
            readSpellcasting(entry)
        }
        return true
    }

    /// "[one-action] jaws +12 [+8/+4] (agile, finesse), **Damage** 2d6+4 piercing plus Grab"
    private mutating func readStrike(_ entry: PluckStatBlock.Entry) {
        let text = Self.removingGlyphs(entry.text)
        let pattern = #/
            ^(?<name>.+?) \s+ (?<bonus>[+\-−–]\d+) (?:\s*\[[^\]]*\])? \s*
            (?:\((?<traits>[^)]*)\))? ,? \s* Damage \s+ (?<damage>.+)$
            /#
        guard let match = text.firstMatch(of: pattern) else {
            keepAsText(entry, section: 2, problem: "couldn't read the attack")
            return
        }
        let pieces = match.output.damage.components(separatedBy: " plus ")
            .flatMap { $0.components(separatedBy: " and ") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let damage = pieces.filter { $0.first?.isNumber == true }.joined(separator: " plus ")
        var strike = Strike(name: String(match.output.name), isRanged: entry.name == "Ranged",
                            attackBonus: StatBlockText.integer(String(match.output.bonus)) ?? 0,
                            traits: match.output.traits.map { StatBlockText.list(String($0)) } ?? [],
                            damage: StatBlockText.damage(damage))
        strike.effects = pieces.filter { $0.first?.isNumber != true }
        creature.strikes.append(strike)
    }

    /// "DC 20, attack +12; 4th dispel magic; Cantrips (2nd) light"
    private mutating func readSpellcasting(_ entry: PluckStatBlock.Entry) {
        let parts = StatBlockText.list(entry.text, separator: ";")
        let header = parts.first ?? ""
        let difficultyClass = header.firstMatch(of: /DC\s+(\d+)/).flatMap { Int($0.output.1) } ?? 0
        let attack = header.firstMatch(of: /attack\s+([+\-−–]?\d+)/).flatMap {
            StatBlockText.integer(String($0.output.1))
        } ?? 0
        let ranks = StatBlockText.spellRanks(parts.dropFirst().joined(separator: "; "))
        if ranks.isEmpty { warn(entry, "no spells read") }
        creature.spellcasting.append(Spellcasting(name: entry.name, difficultyClass: difficultyClass,
                                                  attack: attack, ranks: ranks))
    }

    private mutating func readHazardText(_ entry: PluckStatBlock.Entry) {
        let text = StatBlockText.rulesText(entry.markdown)
        switch entry.name {
        case "Description": creature.hazard?.description = text
        case "Disable": creature.hazard?.disable = text
        case "Routine": creature.hazard?.routine = text
        default: creature.hazard?.reset = text
        }
    }

    // MARK: Abilities

    /// An ability: "[reaction] (arcane, fire) **Trigger** … **Effect** …". Unlabeled text joins the ability
    /// before it.
    mutating func readAbility(_ entry: PluckStatBlock.Entry, section: Int) {
        var text = entry.markdown
        guard !entry.name.isEmpty else {
            appendToLastAbility(text, entry: entry, section: section)
            return
        }
        let cost = Self.leadingCost(&text)
        var traits: [String] = []
        if text.hasPrefix("("), let close = text.firstIndex(of: ")") {
            traits = StatBlockText.list(String(text[text.index(after: text.startIndex)..<close]))
            text = text[text.index(after: close)...].trimmingCharacters(in: CharacterSet(charactersIn: " ;"))
        }
        var ability = Ability(name: entry.name, cost: cost, section: Self.sections[section],
                              text: StatBlockText.rulesText(text))
        ability.traits = traits
        if let frequency = text.firstMatch(of: /\*\*Frequency\*\*\s+(?<value>[^;*]+)/) {
            ability.frequency = frequency.output.value.trimmingCharacters(in: .whitespaces)
        }
        creature.abilities.append(ability)
    }

    private mutating func appendToLastAbility(_ text: String, entry: PluckStatBlock.Entry, section: Int) {
        guard let last = creature.abilities.indices.last else {
            warn(entry, "kept as text")
            creature.abilities.append(Ability(name: "Notes", cost: .none, section: Self.sections[section],
                                              text: StatBlockText.rulesText(text)))
            return
        }
        let joined = StatBlockText.plainText(creature.abilities[last].text) + "\n" + text
        creature.abilities[last].text = StatBlockText.rulesText(joined)
    }

    private static let sections: [AbilitySection] = [.interaction, .defensive, .offensive]

    private static let costs: [(String, ActionCost)] = [
        ("[three-actions]", .three), ("[two-actions]", .two), ("[one-action]", .one), ("[reaction]", .reaction),
        ("[free-action]", .free), ("◆◆◆", .three), ("◆◆", .two), ("◆", .one), ("⤾", .reaction), ("↺", .reaction),
        ("◇", .free)
    ]

    private static func leadingCost(_ text: inout String) -> ActionCost {
        for (glyph, cost) in costs where text.hasPrefix(glyph) {
            text = text.dropFirst(glyph.count).trimmingCharacters(in: .whitespaces)
            return cost
        }
        return .none
    }

    static func removingGlyphs(_ text: String) -> String {
        costs.reduce(text) { $0.replacingOccurrences(of: $1.0, with: "") }.trimmingCharacters(in: .whitespaces)
    }
}
