import Foundation

/// Reading each kind of entry: statistics, defenses, Strikes, spells, hazard text and abilities.
extension StatBlockConverter {
    // MARK: Statistics

    mutating func readStatistic(_ entry: PluckStatBlock.Entry) -> Bool {
        let text = entry.text
        switch entry.name {
        case "Perception":
            let parts = StatBlockText.list(text, separator: ";")
            creature.senses.perception = StatBlockText.integer(parts.first ?? "") ?? 0
            creature.senses.senses = parts.dropFirst().flatMap { StatBlockText.list($0) }
        case "Languages":
            creature.languages = StatBlockText.list(text, separator: ";").flatMap { StatBlockText.list($0) }
        case "Skills": creature.skills = StatBlockText.skills(text)
        case "Str": creature.attributes = Self.attributes("Str " + text)
        case "Items": creature.items = StatBlockText.list(text)
        case "Stealth" where creature.kind == .hazard:
            let (value, note) = StatBlockText.splitParenthetical(text)
            creature.hazard?.stealth = StatBlockText.integer(value) ?? 0
            creature.hazard?.stealthDetails = note.isEmpty ? RulesText("") : StatBlockText.rulesText("(\(note))")
        default: return false
        }
        return true
    }

    static func attributes(_ text: String) -> AttributeModifiers {
        var values: [String: Int] = [:]
        for match in text.matches(of: /(?<name>Str|Dex|Con|Int|Wis|Cha)\s*(?<value>[+\-−–]?\d+)/) {
            values[String(match.output.name)] = StatBlockText.integer(String(match.output.value))
        }
        var attributes = AttributeModifiers.zero
        attributes.strength = values["Str"] ?? 0
        attributes.dexterity = values["Dex"] ?? 0
        attributes.constitution = values["Con"] ?? 0
        attributes.intelligence = values["Int"] ?? 0
        attributes.wisdom = values["Wis"] ?? 0
        attributes.charisma = values["Cha"] ?? 0
        return attributes
    }

    // MARK: Defenses

    mutating func readDefense(_ entry: PluckStatBlock.Entry) -> Bool {
        switch entry.name {
        case "AC": readArmorClass(entry.text)
        case "HP", "Hardness", "Immunities", "Weaknesses", "Resistances":
            for segment in StatBlockText.list(entry.name + " " + entry.text, separator: ";") {
                readDefenseSegment(segment)
            }
        default: return false
        }
        return true
    }

    /// "16 (18 with shield raised); Fort +5, Ref +8, Will +4; +1 status to all saves vs. magic"
    private mutating func readArmorClass(_ text: String) {
        let parts = StatBlockText.list(text, separator: ";")
        let (armorClass, note) = StatBlockText.splitParenthetical(parts.first ?? "")
        creature.defenses.armorClass = StatBlockText.integer(armorClass) ?? 0
        creature.defenses.armorClassDetails = note
        var saveNotes: [String] = []
        for part in parts.dropFirst() {
            let saves = part.matches(of: /(?<save>Fort|Ref|Will)\s*(?<value>[+\-−–]?\d+)(?:\s*\((?<note>[^)]*)\))?/)
            guard !saves.isEmpty else { saveNotes.append(part); continue }
            for save in saves {
                let value = StatBlockText.integer(String(save.output.value)) ?? 0
                switch save.output.save {
                case "Fort": creature.defenses.fortitude = value
                case "Ref": creature.defenses.reflex = value
                default: creature.defenses.will = value
                }
                if let note = save.output.note { saveNotes.append("\(save.output.save) \(note)") }
            }
        }
        creature.defenses.saveDetails = saveNotes.joined(separator: "; ")
    }

    /// One `;`-separated piece of the HP line: "HP 23, regeneration 5", "Hardness 5, HP 20 (BT 10)",
    /// "Immunities fire", "Weaknesses cold iron 2" or "Resistances physical 5 (except silver)".
    private mutating func readDefenseSegment(_ segment: String) {
        if let label = ["Immunities", "Weaknesses", "Resistances"].first(where: { segment.hasPrefix($0 + " ") }) {
            let list = String(segment.dropFirst(label.count + 1))
            switch label {
            case "Immunities": creature.defenses.immunities = StatBlockText.list(list)
            case "Weaknesses": creature.defenses.weaknesses = StatBlockText.adjustments(list)
            default: creature.defenses.resistances = StatBlockText.adjustments(list)
            }
            return
        }
        var notes: [String] = []
        for piece in StatBlockText.list(segment) {
            if let hardness = piece.firstMatch(of: /^Hardness\s+(\d+)/) {
                creature.defenses.hardness = Int(hardness.output.1) ?? 0
            } else if let hitPoints = piece.firstMatch(of: /^HP\s+(\d+)/) {
                creature.defenses.hitPoints = Int(hitPoints.output.1) ?? 0
                let rest = piece[hitPoints.range.upperBound...].trimmingCharacters(in: .whitespaces)
                if !rest.isEmpty { notes.append(rest) }
            } else {
                notes.append(piece)
            }
        }
        let note = ([creature.defenses.hitPointDetails] + notes).filter { !$0.isEmpty }.joined(separator: ", ")
        creature.defenses.hitPointDetails = note
    }

}
