import Bestiary
import TurnkeeperKit
import Foundation

/// Turns an exported pregen into a character `Creature` for its battle card, as `DemiplaneSheetReader` does
/// for a Demiplane sheet. The key is left empty; the party member supplies it.
public enum PregenSheetReader {
    public static func creature(from pregen: PregenSheet, game: Game) -> Creature {
        var sheet = Creature(key: "", name: pregen.name, game: game)
        sheet.kind = .character
        sheet.level = pregen.level
        sheet.traits = TraitLine(rarity: "common", size: sizes[pregen.size] ?? "Medium",
                                 traits: TraitSlugs.slugs(pregen.traits))
        sheet.source = Source(pack: "iconics", title: "Iconic Pregenerated Characters", isRemastered: true)
        sheet.senses = Senses(perception: pregen.perception, details: "", senses: pregen.senses)
        sheet.languages = pregen.languages.map(\.capitalized)
        sheet.skills = (pregen.skills + pregen.lores).map { Skill(name: $0.name, modifier: $0.modifier) }
        sheet.attributes = attributes(pregen.attributes)
        sheet.items = pregen.items
        sheet.defenses = defenses(pregen)
        sheet.speeds = pregen.speeds.filter { $0.feet > 0 }.map { Speed(type: $0.type, feet: $0.feet) }
        sheet.strikes = pregen.strikes.map(strike)
        sheet.spellcasting = pregen.spellcasting.map { spellcasting($0, level: pregen.level) }
        sheet.abilities = pregen.abilities.map(ability)
        sheet.player = player(pregen)
        return sheet
    }

    private static let sizes = ["tiny": "Tiny", "sm": "Small", "med": "Medium", "lg": "Large", "huge": "Huge",
                                "grg": "Gargantuan"]

    private static func attributes(_ values: [String: Int]) -> AttributeModifiers {
        AttributeModifiers(strength: values["str"] ?? 0, dexterity: values["dex"] ?? 0,
                           constitution: values["con"] ?? 0, intelligence: values["int"] ?? 0,
                           wisdom: values["wis"] ?? 0, charisma: values["cha"] ?? 0)
    }

    private static func defenses(_ pregen: PregenSheet) -> Defenses {
        var details = DefenseDetails()
        if pregen.shieldBonus > 0 { details.armorClass = "+\(pregen.shieldBonus) with shield raised" }
        return Defenses(armorClass: pregen.armorClass, fortitude: pregen.fortitude, reflex: pregen.reflex,
                        will: pregen.will, hitPoints: 0, details: details)
    }

    private static func player(_ pregen: PregenSheet) -> PlayerDetails {
        var player = PlayerDetails(ancestry: pregen.ancestry, heritage: pregen.heritage,
                                   background: pregen.background, className: pregen.className)
        player.classDC = pregen.classDC
        player.feats = pregen.feats
        player.classFeatures = pregen.classFeatures
        return player
    }

    // MARK: Offense

    private static func strike(_ attack: PregenSheet.Attack) -> Strike {
        Strike(name: attack.name, isRanged: attack.ranged, attackBonus: attack.attack,
               traits: TraitSlugs.slugs(attack.traits), damage: DamageFormula.parts(attack.damage))
    }

    /// Prepared, spontaneous and innate spells by rank, highest first, then cantrips, heightened to half the
    /// character's level rounded up.
    private static func spellcasting(_ casting: PregenSheet.Casting, level: Int) -> Spellcasting {
        let ranked = Dictionary(grouping: casting.spells.filter { !$0.isCantrip }, by: \.rank)
            .sorted { $0.key > $1.key }
            .map { SpellRank(kind: .ranked, rank: $0.key, spells: entries($0.value)) }
        let cantrips = casting.spells.filter(\.isCantrip)
        let cantripRank = SpellRank(kind: .cantrips, rank: (level + 1) / 2, spells: entries(cantrips))
        return Spellcasting(name: casting.name, difficultyClass: casting.dc, attack: casting.attack,
                            ranks: ranked + (cantrips.isEmpty ? [] : [cantripRank]))
    }

    private static func entries(_ spells: [PregenSheet.Spell]) -> [SpellEntry] {
        spells.map { SpellEntry(name: $0.name) }
    }

    /// Actions go with the attacks; reactions with the defenses.
    private static func ability(_ activity: PregenSheet.Activity) -> Ability {
        let cost: ActionCost = switch activity.actionType {
        case "reaction": .reaction
        case "free": .free
        default: ActionCost(actions: activity.actions ?? 1)
        }
        var ability = Ability(name: activity.name, cost: cost, section: cost == .reaction ? .defensive : .offensive,
                              text: RulesText(activity.text))
        ability.traits = TraitSlugs.slugs(activity.traits)
        ability.frequency = activity.frequency
        return ability
    }
}

/// Foundry's damage formulas as parts: "1d4 + 1 + 2 piercing" is 1d4+3 piercing, and "(2d8 + 1 + 4) fire +
/// 3 persistent fire" is 2d8+5 fire plus 3 persistent fire.
enum DamageFormula {
    static func parts(_ text: String) -> [DamagePart] {
        // An amount (parenthesized, or dice and constants), then "persistent" maybe, then the damage type.
        let pattern = #/
            (?<amount> \( [^)]* \) | \d+ (?:d\d+)? (?: \s* [+-] \s* \d+ (?!d) )* )
            \s+ (?<persistent> persistent \s+ )? (?<type> [a-z]+ )
            /#
        let parts = text.matches(of: pattern).map { match in
            DamagePart(formula: simplified(String(match.output.amount)), type: String(match.output.type),
                       isPersistent: match.output.persistent != nil)
        }
        return parts.isEmpty ? [DamagePart(formula: text, type: "")] : parts
    }

    /// "(2d8 + 1 + 4)" as "2d8+5"; "1d4 - 1" as "1d4-1"; "(1 + 1)" as "2".
    static func simplified(_ amount: String) -> String {
        let terms = amount.filter { !"() ".contains($0) }.matches(of: /[+-]?[^+-]+/).map { String($0.output) }
        let dice = terms.filter { $0.contains("d") }.map { $0.hasPrefix("+") ? String($0.dropFirst()) : $0 }
        let constant = terms.filter { !$0.contains("d") }.compactMap { Int($0) }.reduce(0, +)
        guard !dice.isEmpty else { return String(constant) }
        let sign = constant > 0 ? "+\(constant)" : constant < 0 ? "\(constant)" : ""
        return dice.joined(separator: "+") + sign
    }
}
