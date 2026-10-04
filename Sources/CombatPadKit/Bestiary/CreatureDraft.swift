import Foundation

/// A creature as the custom creature editor shows it: mostly text written the way stat blocks print it,
/// turned into a `Creature` on every change for the live card.
public struct CreatureDraft: Sendable, Equatable {
    public var name = ""
    public var isHazard = false
    public var level = 1
    public var rarity = "common"
    public var size = "Medium"
    public var traits = ""
    public var perception = 0
    public var senses = ""
    public var languages = ""
    public var skills = ""
    public var attributes = AttributeModifiers.zero
    public var items = ""
    public var armorClass = 10
    public var armorClassNote = ""
    public var fortitude = 0
    public var reflex = 0
    public var will = 0
    public var saveNote = ""
    public var hitPoints = 1
    public var hitPointNote = ""
    public var hardness = 0
    public var immunities = ""
    public var weaknesses = ""
    public var resistances = ""
    public var speeds = "25 feet"
    public var strikes: [StrikeDraft] = []
    public var spellcasting: [SpellcastingDraft] = []
    public var abilities: [AbilityDraft] = []
    public var hazard = HazardDraft()

    public init() {}

    /// A draft of an existing creature, for editing.
    public init(_ creature: Creature) {
        name = creature.name
        isHazard = creature.kind == .hazard
        level = creature.level
        rarity = creature.traits.rarity
        size = creature.traits.size
        traits = creature.traits.traits.joined(separator: ", ")
        perception = creature.senses.perception
        senses = (creature.senses.senses + (creature.senses.details.isEmpty ? [] : [creature.senses.details]))
            .joined(separator: ", ")
        languages = creature.languages.joined(separator: ", ")
        skills = StatBlockText.format(creature.skills)
        attributes = creature.attributes
        items = creature.items.joined(separator: ", ")
        setDefenses(creature.defenses)
        speeds = StatBlockText.format(creature.speeds)
        strikes = creature.strikes.map(StrikeDraft.init)
        spellcasting = creature.spellcasting.map(SpellcastingDraft.init)
        abilities = creature.abilities.map(AbilityDraft.init)
        hazard = creature.hazard.map(HazardDraft.init) ?? HazardDraft()
    }

    /// The creature the draft describes, keeping the key, game, source and art of `original`.
    public func creature(from original: Creature) -> Creature {
        var creature = original
        creature.name = name.trimmingCharacters(in: .whitespaces)
        creature.kind = isHazard ? .hazard : .creature
        creature.level = level
        let traitList = StatBlockText.list(traits).map { $0.lowercased() }
        creature.traits = TraitLine(rarity: rarity, size: size, traits: traitList)
        creature.senses = Senses(perception: perception, details: "", senses: StatBlockText.list(senses))
        creature.languages = StatBlockText.list(languages)
        creature.skills = StatBlockText.skills(skills)
        creature.attributes = attributes
        creature.items = StatBlockText.list(items)
        creature.defenses = defenses
        creature.speeds = StatBlockText.speeds(speeds)
        creature.strikes = strikes.filter { !$0.name.isEmpty }.map(\.strike)
        creature.spellcasting = spellcasting.filter { !$0.name.isEmpty }.map(\.spellcasting)
        creature.abilities = abilities.filter { !$0.name.isEmpty }.map(\.ability)
        creature.initiativeStatistic = isHazard ? "stealth" : "perception"
        creature.hazard = isHazard ? hazard.details : nil
        return creature
    }

    private var defenses: Defenses {
        var details = DefenseDetails()
        details.armorClass = armorClassNote
        details.saves = saveNote
        details.hitPoints = hitPointNote
        details.hardness = hardness
        details.immunities = StatBlockText.list(immunities)
        details.weaknesses = StatBlockText.adjustments(weaknesses)
        details.resistances = StatBlockText.adjustments(resistances)
        return Defenses(armorClass: armorClass, fortitude: fortitude, reflex: reflex, will: will,
                        hitPoints: hitPoints, details: details)
    }

    private mutating func setDefenses(_ defenses: Defenses) {
        armorClass = defenses.armorClass
        armorClassNote = defenses.armorClassDetails
        fortitude = defenses.fortitude
        reflex = defenses.reflex
        will = defenses.will
        saveNote = defenses.saveDetails
        hitPoints = defenses.hitPoints
        hitPointNote = defenses.hitPointDetails
        hardness = defenses.hardness
        immunities = defenses.immunities.joined(separator: ", ")
        weaknesses = StatBlockText.format(defenses.weaknesses)
        resistances = StatBlockText.format(defenses.resistances)
    }
}

/// A Strike in the editor.
public struct StrikeDraft: Sendable, Equatable, Identifiable {
    public var id = UUID()
    public var name = ""
    public var isRanged = false
    public var attackBonus = 0
    public var traits = ""
    /// Such as "2d8+11 bludgeoning plus 1d6 fire".
    public var damage = ""
    public var effects = ""

    public init() {}

    init(_ strike: Strike) {
        name = strike.name
        isRanged = strike.isRanged
        attackBonus = strike.attackBonus
        traits = strike.traits.joined(separator: ", ")
        damage = StatBlockText.format(strike.damage)
        effects = strike.effects.joined(separator: ", ")
    }

    var strike: Strike {
        var strike = Strike(name: name, isRanged: isRanged, attackBonus: attackBonus,
                            traits: StatBlockText.list(traits), damage: StatBlockText.damage(damage))
        strike.effects = StatBlockText.list(effects)
        return strike
    }
}

/// A spellcasting entry in the editor; the ranks are one line, as printed.
public struct SpellcastingDraft: Sendable, Equatable, Identifiable {
    public var id = UUID()
    public var name = "Arcane Innate Spells"
    public var difficultyClass = 0
    public var attack = 0
    /// Such as "3rd fireball; Cantrips (2nd) light, shield".
    public var ranks = ""

    public init() {}

    init(_ entry: Spellcasting) {
        name = entry.name
        difficultyClass = entry.difficultyClass
        attack = entry.attack
        ranks = StatBlockText.format(entry.ranks)
    }

    var spellcasting: Spellcasting {
        Spellcasting(name: name, difficultyClass: difficultyClass, attack: attack,
                     ranks: StatBlockText.spellRanks(ranks))
    }
}

/// An ability in the editor, its text written plainly.
public struct AbilityDraft: Sendable, Equatable, Identifiable {
    public var id = UUID()
    public var name = ""
    public var cost = ActionCost.none
    public var traits = ""
    public var section = AbilitySection.offensive
    public var frequency = ""
    public var text = ""

    public init() {}

    init(_ ability: Ability) {
        name = ability.name
        cost = ability.cost
        traits = ability.traits.joined(separator: ", ")
        section = ability.section
        frequency = ability.frequency
        text = StatBlockText.plainText(ability.text)
    }

    var ability: Ability {
        var ability = Ability(name: name, cost: cost, section: section, text: StatBlockText.rulesText(text))
        ability.traits = StatBlockText.list(traits)
        ability.frequency = frequency
        return ability
    }
}

/// A complex hazard's own text in the editor.
public struct HazardDraft: Sendable, Equatable {
    public var stealth = 0
    public var stealthNote = ""
    public var description = ""
    public var disable = ""
    public var routine = ""
    public var reset = ""

    public init() {}

    init(_ hazard: HazardDetails) {
        stealth = hazard.stealth
        stealthNote = StatBlockText.plainText(hazard.stealthDetails)
        description = StatBlockText.plainText(hazard.description)
        disable = StatBlockText.plainText(hazard.disable)
        routine = StatBlockText.plainText(hazard.routine)
        reset = StatBlockText.plainText(hazard.reset)
    }

    var details: HazardDetails {
        var details = HazardDetails(stealth: stealth, description: StatBlockText.rulesText(description))
        details.stealthDetails = StatBlockText.rulesText(stealthNote)
        details.disable = StatBlockText.rulesText(disable)
        details.routine = StatBlockText.rulesText(routine)
        details.reset = StatBlockText.rulesText(reset)
        return details
    }
}
