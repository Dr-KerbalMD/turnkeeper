import CombatPadKit
import Foundation

/// Strikes, actions, reactions and spells from the sheet's numbered fields.
extension DemiplaneSheetReader {
    static func strikes(_ fields: SheetFields) -> [Strike] {
        strikes(fields, prefix: "weapon_", isRanged: false) + strikes(fields, prefix: "ranged_weapon_", isRanged: true)
    }

    /// Strikes need a weapon name and damage dice. Demiplane also lists runes as weapons (damage "2+0").
    /// Starfinder sheets have no damage type, and add a ranged weapon's range, magazine and expend.
    private static func strikes(_ fields: SheetFields, prefix: String, isRanged: Bool) -> [Strike] {
        fields.numbers(prefix: prefix).compactMap { index -> Strike? in
            let name = fields.string("\(prefix)\(index)")
            let formula = fields.string("\(prefix)damage_\(index)")
            guard !name.isEmpty, formula.contains("d") else { return nil }
            let types = [("bludg", "bludgeoning"), ("pierce", "piercing"), ("slash", "slashing")]
            let type = types.first { fields.isChecked("\(prefix)\($0.0)_\(index)") }?.1 ?? ""
            let traits = fields.list("\(prefix)traits_notes_\(index)") + (isRanged ? rangedNotes(fields, index) : [])
            return Strike(name: name, isRanged: isRanged, attackBonus: fields.int("\(prefix)bonus_\(index)"),
                          traits: TraitSlugs.slugs(traits),
                          damage: [DamagePart(formula: withoutZero(formula), type: type)])
        }
    }

    /// "range 60 ft.", "magazine 6" and "expend 1". Magazines and expends are numbered from 0.
    private static func rangedNotes(_ fields: SheetFields, _ index: Int) -> [String] {
        let range = fields.string("ranged_weapon_\(index)_range")
        let magazine = fields.string("Mag_\(index - 1)")
        let expend = fields.string("Exp_\(index - 1)")
        return [range.isEmpty ? "" : "range \(range)", magazine.isEmpty ? "" : "magazine \(magazine)",
                expend.isEmpty ? "" : "expend \(expend)"].filter { !$0.isEmpty }
    }

    /// "1d6+0" as "1d6".
    private static func withoutZero(_ formula: String) -> String {
        formula.hasSuffix("+0") ? String(formula.dropLast(2)) : formula
    }

    /// The Actions and Activities column.
    static func actions(_ fields: SheetFields) -> [Ability] {
        fields.numbers(prefix: "action_name_").compactMap { index -> Ability? in
            let name = fields.string("action_name_\(index)")
            guard !name.isEmpty else { return nil }
            var ability = Ability(name: name, cost: ActionCost(actions: fields.int("action_actions_\(index)")),
                                  section: .offensive, text: RulesText(fields.string("action_effects_\(index)")))
            ability.traits = TraitSlugs.slugs(fields.list("action_traits_\(index)"))
            return ability
        }
    }

    /// The Reactions and Free Actions column: reactions go with the defenses, free actions with the rest.
    static func reactions(_ fields: SheetFields) -> [Ability] {
        fields.numbers(prefix: "action_rxn_name_").compactMap { index -> Ability? in
            let name = fields.string("action_rxn_name_\(index)")
            guard !name.isEmpty else { return nil }
            let isFree = fields.isChecked("is_free_\(index)")
            let trigger = fields.string("action_rxn_trigger_\(index)")
            let effect = fields.string("action_rxn_effects_\(index)")
            let text = trigger.isEmpty ? effect : "**Trigger** \(trigger); **Effect** \(effect)"
            var ability = Ability(name: name, cost: isFree ? .free : .reaction,
                                  section: isFree ? .offensive : .defensive, text: RulesText(text))
            ability.traits = TraitSlugs.slugs(fields.list("action_rxn_traits_\(index)"))
            return ability
        }
    }

    // MARK: Spells

    /// The spell page: the main spells by rank, then focus spells, innate spells and rituals, each its
    /// own entry with the sheet's spell DC and attack.
    static func spellcasting(_ fields: SheetFields) -> [Spellcasting] {
        let dc = fields.int("spell_dc_total")
        let attack = fields.int("spell_attack_total")
        let entry = { (name: String, ranks: [SpellRank]) -> Spellcasting? in
            ranks.isEmpty ? nil : Spellcasting(name: name, difficultyClass: dc, attack: attack, ranks: ranks)
        }
        return [
            entry(mainName(fields), mainRanks(fields)),
            entry("Focus Spells", rank(fields, prefix: "spells_focus_", rank: fields.int("spells_focus_rank"))),
            entry("Innate Spells", innateRanks(fields)),
            entry("Rituals", ritualRanks(fields))
        ].compactMap { $0 }
    }

    /// "Occult Prepared Spells", "Arcane Spontaneous Spells" or just "Spells".
    private static func mainName(_ fields: SheetFields) -> String {
        let tradition = ["arcane", "divine", "occult", "primal"].first { fields.isChecked("tradition_\($0)_yn") }
        let style = fields.isChecked("prepared_caster_yn") ? "Prepared"
            : fields.isChecked("spontaneous_caster_yn") ? "Spontaneous" : ""
        return ([tradition?.capitalized ?? "", style, "Spells"]).filter { !$0.isEmpty }.joined(separator: " ")
    }

    private static func mainRanks(_ fields: SheetFields) -> [SpellRank] {
        let spells = fields.numbers(prefix: "spells_").map { index in
            (rank: fields.int("spells_rank_\(index)"), name: fields.string("spells_\(index)"))
        }
        let ranked = Dictionary(grouping: spells.filter { !$0.name.isEmpty }, by: \.rank)
            .sorted { $0.key > $1.key }
            .map { SpellRank(kind: .ranked, rank: $0.key, spells: $0.value.map { SpellEntry(name: $0.name) }) }
        let cantrips = fields.numbers(prefix: "spells_cantrip_").map { fields.string("spells_cantrip_\($0)") }
            .filter { !$0.isEmpty }.map { SpellEntry(name: $0) }
        let cantripRank = SpellRank(kind: .cantrips, rank: fields.int("spells_cantrip_rank"), spells: cantrips)
        return ranked + (cantrips.isEmpty ? [] : [cantripRank])
    }

    private static func rank(_ fields: SheetFields, prefix: String, rank: Int) -> [SpellRank] {
        let spells = fields.numbers(prefix: prefix).map { fields.string("\(prefix)\($0)") }
            .filter { !$0.isEmpty }.map { SpellEntry(name: $0) }
        return spells.isEmpty ? [] : [SpellRank(kind: .ranked, rank: rank, spells: spells)]
    }

    /// Innate spells have no rank on the sheet, only a frequency, shown as the spell's note. They are
    /// heightened to half the character's level, rounded up.
    private static func innateRanks(_ fields: SheetFields) -> [SpellRank] {
        let spells = fields.numbers(prefix: "spells_innate_").compactMap { index -> SpellEntry? in
            let name = fields.string("spells_innate_\(index)")
            return name.isEmpty ? nil : SpellEntry(name: name, note: fields.string("spells_innate_\(index)_freq"))
        }
        let rank = (fields.int("level") + 1) / 2
        return spells.isEmpty ? [] : [SpellRank(kind: .ranked, rank: rank, spells: spells)]
    }

    private static func ritualRanks(_ fields: SheetFields) -> [SpellRank] {
        let rituals = fields.numbers(prefix: "spells_ritual_").map { index in
            (rank: fields.int("spells_ritual_\(index)_rank"), name: fields.string("spells_ritual_\(index)"))
        }
        return Dictionary(grouping: rituals.filter { !$0.name.isEmpty }, by: \.rank)
            .sorted { $0.key > $1.key }
            .map { SpellRank(kind: .ranked, rank: $0.key, spells: $0.value.map { SpellEntry(name: $0.name) }) }
    }
}

/// Trait words from the sheet as slugs, the way Foundry writes them: "thrown 10 ft." becomes
/// `thrown-10-ft` and "versatile S" `versatile-s`. Repeats are dropped, as is a bare trait that a longer
/// one already covers ("thrown" next to "thrown 10 ft.").
enum TraitSlugs {
    static func slugs(_ words: [String]) -> [String] {
        var seen = Set<String>()
        let slugs = words.map(slug).filter { !$0.isEmpty && seen.insert($0).inserted }
        return slugs.filter { slug in !slugs.contains { $0 != slug && $0.hasPrefix(slug + "-") } }
    }

    static func slug(_ word: String) -> String {
        word.lowercased().split { !$0.isLetter && !$0.isNumber }.joined(separator: "-")
    }
}
