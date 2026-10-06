import CombatPadKit
import Foundation

/// Reads Demiplane's exported character sheet PDF, a fillable form holding the computed numbers, into a
/// character `Creature` for the PC's battle card. The key is left empty; the party member supplies it.
public enum DemiplaneSheetReader {
    /// The sheet for a game, or, without one, the game the sheet's own fields show.
    public static func sheet(fromPDF data: Data, game: Game?) throws -> Creature {
        let fields = try SheetFields(pdf: data)
        return sheet(from: fields, game: game ?? (fields.isStarfinder ? .starfinder : .pathfinder))
    }

    static func sheet(from fields: SheetFields, game: Game) -> Creature {
        var sheet = Creature(key: "", name: fields.string("character_name"), game: game)
        sheet.kind = .character
        sheet.level = fields.int("level")
        sheet.traits = TraitLine(rarity: "common", size: fields.string("size").ifEmpty("Medium"),
                                 traits: TraitSlugs.slugs(fields.list("traits")))
        sheet.source = Source(pack: "demiplane", title: "Demiplane", isRemastered: true)
        sheet.senses = Senses(perception: fields.int("perception"), details: "", senses: fields.list("senses_notes"))
        sheet.languages = fields.list("languages")
        sheet.skills = skills(fields, game: game)
        sheet.attributes = attributes(fields)
        sheet.items = fields.numbered("item_")
        sheet.defenses = defenses(fields)
        sheet.speeds = speeds(fields)
        sheet.strikes = strikes(fields)
        sheet.spellcasting = spellcasting(fields)
        sheet.abilities = actions(fields) + reactions(fields)
        sheet.player = player(fields)
        return sheet
    }

    private static func player(_ fields: SheetFields) -> PlayerDetails {
        var player = PlayerDetails(ancestry: fields.string("ancestry"), heritage: fields.string("heritage"),
                                   background: fields.string("background"), className: fields.string("class"))
        player.classDC = fields.int("class_dc")
        player.feats = fields.numbered("feat_")
        player.classFeatures = fields.numbered("class_feature_")
        return player
    }

    private static func attributes(_ fields: SheetFields) -> AttributeModifiers {
        AttributeModifiers(
            strength: fields.int("strength"), dexterity: fields.int("dexterity"),
            constitution: fields.int("constitution"), intelligence: fields.int("intelligence"),
            wisdom: fields.int("wisdom"), charisma: fields.int("charisma")
        )
    }

    // MARK: Defenses

    private static func defenses(_ fields: SheetFields) -> Defenses {
        var details = DefenseDetails()
        let shield = fields.int("shield_bonus")
        if shield > 0 { details.armorClass = "+\(shield) with shield raised" }
        details.immunities = fields.list("immunities")
        details.resistances = fields.list("resistances").compactMap(adjustment)
        return Defenses(armorClass: fields.int("armor_class"), fortitude: fields.int("fortitude"),
                        reflex: fields.int("reflex"), will: fields.int("will"), hitPoints: 0, details: details)
    }

    /// "fire 5" as a resistance; text without a trailing number is left out.
    private static func adjustment(_ text: String) -> DamageAdjustment? {
        guard let match = text.wholeMatch(of: /(?<type>.+?)\s+(?<value>\d+)/), let value = Int(match.output.value)
        else { return nil }
        return DamageAdjustment(type: String(match.output.type), value: value)
    }

    private static func speeds(_ fields: SheetFields) -> [Speed] {
        let land = fields.int("speed")
        let others = ["burrow", "climb", "fly", "swim"].compactMap { type -> Speed? in
            let feet = fields.int("\(type)_speed")
            return feet > 0 ? Speed(type: type, feet: feet) : nil
        }
        return (land > 0 ? [Speed(type: "land", feet: land)] : []) + others
    }

    // MARK: Skills

    private static let skillNames = [
        "acrobatics", "arcana", "athletics", "crafting", "deception", "diplomacy", "intimidation", "medicine",
        "nature", "occultism", "performance", "religion", "society", "stealth", "survival", "thievery"
    ]

    /// Every skill with its modifier, Starfinder's Computers and Piloting when present, then the lores.
    private static func skills(_ fields: SheetFields, game: Game) -> [Skill] {
        let names = skillNames + (game == .starfinder ? ["computers", "piloting"] : [])
        let skills = names.sorted().compactMap { name -> Skill? in
            fields.string(name).isEmpty ? nil : Skill(name: name.capitalized, modifier: fields.int(name))
        }
        let lores = fields.numbers(prefix: "lore_skill_").compactMap { index -> Skill? in
            let topic = fields.string("lore_skill_\(index)")
            return topic.isEmpty ? nil : Skill(name: "\(topic) Lore", modifier: fields.int("lore_\(index)"))
        }
        return skills + lores
    }
}

extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
