import CombatPadKit
import Foundation

/// Reads the statistics part of a Foundry actor: traits, senses, skills, attributes and defenses.
enum StatisticsParser {
    static let sizes = [
        "tiny": "Tiny", "sm": "Small", "med": "Medium", "lg": "Large", "huge": "Huge", "grg": "Gargantuan"
    ]

    static func traitLine(_ traits: JSONValue) -> TraitLine {
        let size = traits[path: "size.value"].string
        return TraitLine(
            rarity: traits["rarity"].string.isEmpty ? "common" : traits["rarity"].string,
            size: sizes[size] ?? size.capitalized,
            traits: traits["value"].strings
        )
    }

    static func source(_ publication: JSONValue, pack: String) -> Source {
        Source(pack: pack, title: publication["title"].string, isRemastered: publication["remaster"].bool)
    }

    static func senses(_ perception: JSONValue) -> Senses {
        Senses(
            perception: perception["mod"].int,
            details: perception["details"].string,
            senses: perception["senses"].array.map(sense)
        )
    }

    private static func sense(_ sense: JSONValue) -> String {
        var text = Words.label(sense["type"].string)
        let acuity = sense["acuity"].string
        if !acuity.isEmpty && acuity != "precise" { text += " (\(acuity))" }
        if let range = sense["range"].optionalInt { text += " \(range) feet" }
        return text
    }

    static func languages(_ languages: JSONValue) -> [String] {
        let names = languages["value"].strings.map(Words.label).map(\.capitalized)
        let details = languages["details"].string
        return details.isEmpty ? names : names + [details]
    }

    /// Skills from `system.skills`, sorted by name, then lore skills from `lore` items.
    static func skills(_ skills: JSONValue, items: [JSONValue]) -> [Skill] {
        let standard = skills.object.keys.sorted().map { slug in
            Skill(name: Words.label(slug).capitalized, modifier: skills[slug]["base"].int)
        }
        let lore = items.filter { $0["type"].string == "lore" }.map { item in
            Skill(name: item["name"].string, modifier: item[path: "system.mod.value"].int)
        }
        return standard + lore
    }

    static func attributes(_ abilities: JSONValue) -> AttributeModifiers {
        AttributeModifiers(
            strength: abilities[path: "str.mod"].int,
            dexterity: abilities[path: "dex.mod"].int,
            constitution: abilities[path: "con.mod"].int,
            intelligence: abilities[path: "int.mod"].int,
            wisdom: abilities[path: "wis.mod"].int,
            charisma: abilities[path: "cha.mod"].int
        )
    }

    private static let inventoryTypes: Set<String> = [
        "weapon", "armor", "shield", "equipment", "consumable", "treasure", "backpack", "ammo"
    ]

    static func inventory(_ items: [JSONValue]) -> [String] {
        items.filter { inventoryTypes.contains($0["type"].string) }.map { item in
            let name = item["name"].string.lowercased()
            let quantity = item[path: "system.quantity"].int
            return quantity > 1 ? "\(name) (\(quantity))" : name
        }
    }

    static func speeds(_ speed: JSONValue) -> [Speed] {
        let land = speed["value"].int
        let others = speed["otherSpeeds"].array.map { Speed(type: $0["type"].string, feet: $0["value"].int) }
        return (land > 0 ? [Speed(type: "land", feet: land)] : []) + others
    }

    static func defenses(_ system: JSONValue) -> Defenses {
        let attributes = system["attributes"]
        var details = DefenseDetails()
        details.armorClass = attributes[path: "ac.details"].string
        details.saves = attributes[path: "allSaves.value"].string
        details.hitPoints = attributes[path: "hp.details"].string
        details.hardness = attributes["hardness"].int
        details.immunities = attributes["immunities"].array.map { Words.label($0["type"].string) }
        details.resistances = attributes["resistances"].array.map(adjustment)
        details.weaknesses = attributes["weaknesses"].array.map(adjustment)
        return Defenses(
            armorClass: attributes[path: "ac.value"].int,
            fortitude: system[path: "saves.fortitude.value"].int,
            reflex: system[path: "saves.reflex.value"].int,
            will: system[path: "saves.will.value"].int,
            hitPoints: attributes[path: "hp.max"].int,
            details: details
        )
    }

    /// Exceptions are usually slugs, but some packs store `{ "label": … }` objects.
    private static func exceptionLabel(_ exception: JSONValue) -> String {
        Words.label(exception.string.isEmpty ? exception["label"].string : exception.string)
    }

    private static func adjustment(_ entry: JSONValue) -> DamageAdjustment {
        DamageAdjustment(
            type: Words.label(entry["type"].string),
            value: entry["value"].int,
            exceptions: entry["exceptions"].array.map(exceptionLabel),
            doubleVersus: entry["doubleVs"].array.map { Words.label($0.string) }
        )
    }
}

/// Turns Foundry slugs into stat-block words.
enum Words {
    private static let special = [
        "low-light-vision": "low-light vision", "all-damage": "all", "cold-iron": "cold iron",
        "fear-effects": "fear effects", "critical-hits": "critical hits", "object-immunities": "object immunities"
    ]

    static func label(_ slug: String) -> String {
        special[slug] ?? slug.replacingOccurrences(of: "-", with: " ")
    }
}
