import CombatPadKit
import Foundation

/// The stat-block lines of a creature, grouped so each card style can arrange them its own way.
struct CardContent {
    var name: String
    /// "CREATURE 8" or "HAZARD 3".
    var levelLabel: String
    var template: CreatureTemplate
    var traits: TraitLine
    var senses: [CardLine] = []
    var statistics: [CardLine] = []
    var interaction: [CardLine] = []
    var defense: [CardLine] = []
    var hitPoints: [CardSegment] = []
    var defensive: [CardLine] = []
    var offense: [CardLine] = []
    var offensive: [CardLine] = []
    var hazard: [CardLine] = []

    init(presenter: StatBlockPresenter) {
        let creature = presenter.creature
        let builder = CardLineBuilder(presenter: presenter)
        name = creature.name
        levelLabel = "\(creature.kind == .hazard ? "HAZARD" : "CREATURE") \(presenter.level)"
        template = presenter.template
        traits = creature.traits
        senses = builder.sensesLines()
        statistics = builder.statisticsLines()
        interaction = builder.abilityLines(in: .interaction)
        defense = builder.defenseLines()
        hitPoints = builder.hitPointSegments()
        defensive = builder.immunityLines() + builder.abilityLines(in: .defensive)
        offense = builder.offenseLines()
        offensive = builder.abilityLines(in: .offensive)
        hazard = builder.hazardLines()
    }
}

/// Builds card lines from a presenter.
struct CardLineBuilder {
    let presenter: StatBlockPresenter
    private var creature: Creature { presenter.creature }

    func sensesLines() -> [CardLine] {
        guard creature.kind == .creature else { return [] }
        var perception: [CardSegment] = [.value(presenter.perception, signed: true)]
        let senses = creature.senses.senses + (creature.senses.details.isEmpty ? [] : [creature.senses.details])
        if !senses.isEmpty { perception.append(.text("; " + senses.joined(separator: ", "))) }
        var lines = [CardLine.labeled("Perception", perception)]
        if !creature.languages.isEmpty {
            lines.append(.labeled("Languages", [.text(creature.languages.joined(separator: ", "))]))
        }
        if !creature.skills.isEmpty {
            lines.append(.labeled("Skills", joined(creature.skills.map { skill in
                [.text("\(skill.name) "), .value(presenter.skill(skill), signed: true)]
            })))
        }
        return lines
    }

    func statisticsLines() -> [CardLine] {
        guard creature.kind == .creature else { return [] }
        let attributes = creature.attributes
        let values = [("Str", attributes.strength), ("Dex", attributes.dexterity), ("Con", attributes.constitution),
                      ("Int", attributes.intelligence), ("Wis", attributes.wisdom), ("Cha", attributes.charisma)]
        var lines = [CardLine(joined(values.map { [.bold("\($0.0) "), .text(signed($0.1))] }))]
        if !creature.items.isEmpty { lines.append(.labeled("Items", [.text(creature.items.joined(separator: ", "))])) }
        return lines
    }

    func defenseLines() -> [CardLine] {
        var line: [CardSegment] = [.bold("AC "), .value(presenter.armorClass, signed: false)]
        line += parenthesized(creature.defenses.armorClassDetails)
        if creature.kind == .creature || creature.defenses.fortitude != 0 {
            line += [.text("; "), .bold("Fort "), .value(presenter.fortitude, signed: true),
                     .text(", "), .bold("Ref "), .value(presenter.reflex, signed: true),
                     .text(", "), .bold("Will "), .value(presenter.will, signed: true)]
        }
        if !creature.defenses.saveDetails.isEmpty { line.append(.text("; \(creature.defenses.saveDetails)")) }
        return [CardLine(line)]
    }

    func hitPointSegments() -> [CardSegment] {
        let defenses = creature.defenses
        let hardness: [CardSegment] = defenses.hardness > 0 ? [.bold("Hardness "), .text("\(defenses.hardness), ")] : []
        return hardness + [.bold("HP "), .value(presenter.maxHitPoints, signed: false)]
            + parenthesized(defenses.hitPointDetails)
    }

    func immunityLines() -> [CardLine] {
        let defenses = creature.defenses
        var parts: [[CardSegment]] = []
        let immunities = defenses.immunities.joined(separator: ", ")
        if !immunities.isEmpty { parts.append([.bold("Immunities "), .text(immunities)]) }
        if !defenses.weaknesses.isEmpty { parts.append([.bold("Weaknesses "), .text(describe(defenses.weaknesses))]) }
        if !defenses.resistances.isEmpty {
            parts.append([.bold("Resistances "), .text(describe(defenses.resistances))])
        }
        return parts.isEmpty ? [] : [CardLine(joined(parts, separator: "; "))]
    }

    func offenseLines() -> [CardLine] {
        var lines: [CardLine] = []
        let speeds = presenter.speeds
        if !speeds.isEmpty {
            lines.append(.labeled("Speed", joined(speeds.map { item in
                let prefix = item.speed.type == "land" ? "" : "\(item.speed.type) "
                return [.text(prefix), .value(item.feet, signed: false), .text(" feet")]
            })))
        }
        lines += creature.strikes.map(strikeLine)
        lines += creature.spellcasting.map(spellLine)
        return lines
    }

    func abilityLines(in section: AbilitySection) -> [CardLine] {
        // Passive entries without text, such as "+1 Status to All Saves vs. Magic", repeat a statistic line.
        creature.abilities.filter { $0.section == section && !($0.cost == .none && $0.text.isEmpty) }
            .flatMap(abilityLines)
    }

    func hazardLines() -> [CardLine] {
        guard let hazard = creature.hazard else { return [] }
        var lines = [CardLine.labeled("Stealth", [.value(presenter.initiative, signed: true)]
                                      + inline(hazard.stealthDetails, isLimited: false))]
        lines += textLines("Description", hazard.description)
        lines += textLines("Disable", hazard.disable)
        lines += textLines("Routine", hazard.routine)
        lines += textLines("Reset", hazard.reset)
        return lines
    }

    // MARK: Pieces

    private func strikeLine(_ strike: Strike) -> CardLine {
        var segments: [CardSegment] = [.bold(strike.isRanged ? "Ranged " : "Melee "), .actions(.one), .text(" "),
                                       .italic(strike.name.lowercased()), .text(" "),
                                       .value(presenter.attack(strike), signed: true)]
        segments += parenthesized(strike.traits.map(traitLabel).joined(separator: ", "))
        if !strike.areaNote.isEmpty { segments.append(.text(" [\(strike.areaNote)]")) }
        let damage = presenter.damage(strike)
        if !damage.isEmpty {
            segments.append(.text(", "))
            segments.append(.bold("Damage "))
            segments += joined(damage.map { [.damage($0)] }, separator: " plus ")
        }
        if !strike.effects.isEmpty { segments.append(.text(" plus \(strike.effects.joined(separator: " and "))")) }
        return CardLine(segments)
    }

    private func spellLine(_ entry: Spellcasting) -> CardLine {
        var segments: [CardSegment] = [.bold(entry.name + " ")]
        if entry.difficultyClass > 0 { segments += [.text("DC "), .value(presenter.spellDC(entry), signed: false)] }
        if entry.attack != 0 { segments += [.text(", attack "), .value(presenter.spellAttack(entry), signed: true)] }
        for rank in entry.ranks {
            segments.append(.text("; "))
            segments.append(.bold(rankLabel(rank) + " "))
            segments += joined(rank.spells.map { spell in
                [.italic(spell.name)] + (spell.note.isEmpty ? [] : [.text(" (\(spell.note))")])
            })
        }
        return CardLine(segments)
    }

    private func abilityLines(_ ability: Ability) -> [CardLine] {
        var header: [CardSegment] = [.bold(ability.name)]
        if ability.cost != .none { header += [.text(" "), .actions(ability.cost)] }
        if !ability.traits.isEmpty { header.append(.text(" (\(ability.traits.joined(separator: ", ")))")) }
        let paragraphs = paragraphLines(ability.text, isLimited: ability.isLimited)
        guard let first = paragraphs.first else { return [CardLine(header)] }
        return [CardLine(header + [.text(" ")] + first.segments)] + paragraphs.dropFirst()
    }

    private func textLines(_ label: String, _ text: RulesText) -> [CardLine] {
        let paragraphs = paragraphLines(text, isLimited: false)
        guard let first = paragraphs.first else { return [] }
        return [CardLine([.bold(label + " ")] + first.segments)] + paragraphs.dropFirst()
    }

    /// Rules text paragraphs as indented lines; horizontal rules become breaks between lines.
    private func paragraphLines(_ text: RulesText, isLimited: Bool) -> [CardLine] {
        text.paragraphs.compactMap { paragraph in
            guard case let .runs(runs) = paragraph else { return nil }
            return CardLine(runs.flatMap { segments(for: $0, isLimited: isLimited) }, isIndented: true)
        }
    }

    private func inline(_ text: RulesText, isLimited: Bool) -> [CardSegment] {
        let segments = paragraphLines(text, isLimited: isLimited).flatMap(\.segments)
        return segments.isEmpty ? [] : [.text(" ")] + segments
    }

    private func segments(for run: RulesRun, isLimited: Bool) -> [CardSegment] {
        switch run {
        case let .text(string, .plain): return [.text(string)]
        case let .text(string, .bold): return [.bold(string)]
        case let .text(string, .italic): return [.italic(string)]
        case let .actions(cost): return [.actions(cost)]
        case let .check(check):
            let save = check.statistic == "flat" ? "flat check" : check.statistic.capitalized
            return [.text("DC "), .value(presenter.check(check), signed: false),
                    .text(" \(check.isBasic ? "basic " : "")\(save)")]
        case let .damage(parts):
            return joined(presenter.damage(parts, isLimited: isLimited).map { [.damage($0)] }, separator: " plus ")
        }
    }

    private func rankLabel(_ rank: SpellRank) -> String {
        let ordinal = Ordinal.string(rank.rank)
        switch rank.kind {
        case .cantrips: return "Cantrips (\(ordinal))"
        case .constant: return "Constant (\(ordinal))"
        case .ranked: return rank.note.isEmpty ? ordinal : "\(ordinal) (\(rank.note))"
        }
    }

    private func describe(_ adjustments: [DamageAdjustment]) -> String {
        adjustments.map { adjustment in
            var text = "\(adjustment.type) \(adjustment.value)"
            if !adjustment.exceptions.isEmpty { text += " (except \(adjustment.exceptions.joined(separator: ", ")))" }
            if !adjustment.doubleVersus.isEmpty {
                text += " (double vs. \(adjustment.doubleVersus.joined(separator: ", ")))"
            }
            return text
        }
        .joined(separator: ", ")
    }

    /// "versatile-p" reads "versatile P" and "deadly-d10" "deadly d10", as in the books.
    private func traitLabel(_ slug: String) -> String {
        let words = slug.split(separator: "-").map(String.init)
        guard words.count > 1, let last = words.last, last.count == 1 else { return words.joined(separator: " ") }
        return (words.dropLast() + [last.uppercased()]).joined(separator: " ")
    }

    /// " (text)", or nothing when the text is empty.
    private func parenthesized(_ text: String) -> [CardSegment] {
        text.isEmpty ? [] : [.text(" (\(text))")]
    }

    private func joined(_ groups: [[CardSegment]], separator: String = ", ") -> [CardSegment] {
        groups.enumerated().flatMap { index, group in index == 0 ? group : [.text(separator)] + group }
    }
}

enum Ordinal {
    static func string(_ number: Int) -> String {
        let suffix: String
        switch (number % 10, number % 100) {
        case (_, 11...13): suffix = "th"
        case (1, _): suffix = "st"
        case (2, _): suffix = "nd"
        case (3, _): suffix = "rd"
        default: suffix = "th"
        }
        return "\(number)\(suffix)"
    }
}
