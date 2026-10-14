import Bestiary
import TurnkeeperKit
import Foundation

/// A linked PC for the demos: Valeros at level 3, as if imported from Demiplane, linked to the glossary.
enum DemoCharacters {
    static func valeros(bestiary: BestiaryStore) -> PartyMember {
        var member = PartyMember(name: "Valeros")
        let linked = CharacterGlossaryLinker(glossary: bestiary).link(valerosSheet())
        member.sheet = linked.sheet
        var link = CharacterLink(source: .demiplane, characterID: "demo-valeros", game: .pathfinder)
        link.linkedNames = linked.linkedNames
        link.totalNames = linked.totalNames
        member.link = link
        member.maxHitPoints = 45
        return member
    }

    private static func valerosSheet() -> Creature {
        var sheet = Creature(key: "", name: "Valeros", game: .pathfinder)
        sheet.kind = .character
        sheet.level = 3
        sheet.traits = TraitLine(rarity: "common", size: "Medium", traits: ["human", "humanoid"])
        sheet.senses = Senses(perception: 7, details: "", senses: [])
        sheet.languages = ["Common"]
        sheet.skills = [Skill(name: "Athletics", modifier: 9), Skill(name: "Intimidation", modifier: 6)]
        sheet.attributes = AttributeModifiers(strength: 4, dexterity: 2, constitution: 2, intelligence: 0,
                                              wisdom: 0, charisma: 1)
        sheet.items = ["Healing Potion, Minor", "Longsword", "Shortbow"]
        sheet.defenses = Defenses(armorClass: 18, fortitude: 9, reflex: 7, will: 6, hitPoints: 0)
        sheet.speeds = [Speed(type: "land", feet: 25)]
        sheet.strikes = [
            Strike(name: "Longsword", isRanged: false, attackBonus: 11, traits: ["versatile-p"],
                   damage: [DamagePart(formula: "1d8+4", type: "slashing")]),
            Strike(name: "Shortbow", isRanged: true, attackBonus: 9, traits: ["deadly-d10"],
                   damage: [DamagePart(formula: "1d6", type: "piercing")])
        ]
        var charge = Ability(name: "Sudden Charge", cost: .two, section: .offensive, text: "Demiplane text.")
        charge.traits = ["flourish", "fighter", "open"]
        sheet.abilities = [charge, Ability(name: "Reactive Strike", cost: .reaction, section: .defensive,
                                           text: "Demiplane text.")]
        var player = PlayerDetails(ancestry: "Human", heritage: "Skilled Human", background: "Farmhand",
                                   className: "Fighter")
        player.classDC = 19
        player.feats = ["Sudden Charge", "Toughness"]
        player.classFeatures = ["Shield Block"]
        sheet.player = player
        return sheet
    }
}
