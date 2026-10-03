import Foundation

public enum Attribute: String, Codable, Sendable, CaseIterable {
    case strength
    case dexterity
    case constitution
    case intelligence
    case wisdom
    case charisma

    public var isMental: Bool { [.intelligence, .wisdom, .charisma].contains(self) }

    private static let skillAttributes: [String: Attribute] = [
        "acrobatics": .dexterity, "arcana": .intelligence, "athletics": .strength, "crafting": .intelligence,
        "deception": .charisma, "diplomacy": .charisma, "intimidation": .charisma, "medicine": .wisdom,
        "nature": .wisdom, "occultism": .intelligence, "performance": .charisma, "religion": .wisdom,
        "society": .intelligence, "stealth": .dexterity, "survival": .wisdom, "thievery": .dexterity,
        "computers": .intelligence, "piloting": .dexterity
    ]

    /// The attribute a skill uses; lore skills use Intelligence.
    public static func forSkill(_ name: String) -> Attribute {
        skillAttributes[name.lowercased()] ?? .intelligence
    }
}

/// Something a modifier can change.
public enum Statistic: Hashable, Sendable {
    case armorClass
    case fortitude
    case reflex
    case will
    case perception
    case skill(Attribute)
    /// A Strike's attack roll, by the attribute it uses.
    case strikeAttack(Attribute)
    /// A Strike's damage, by the attribute it adds.
    case strikeDamage(Attribute)
    case spellAttack
    case spellDC
    /// A DC in ability text, such as a breath weapon's save DC.
    case abilityDC
    case speed

    /// Whether the statistic is a check or DC, which "all" penalties such as frightened affect.
    public var isCheckOrDC: Bool {
        switch self {
        case .strikeDamage, .speed: return false
        default: return true
        }
    }

    public var isSave: Bool { [.fortitude, .reflex, .will].contains(self) }

    public var isAttack: Bool {
        if case .strikeAttack = self { return true }
        return self == .spellAttack
    }

    /// Whether the statistic uses Intelligence, Wisdom or Charisma. Spellcasting always does.
    public var isMentalBased: Bool {
        self == .spellAttack || self == .spellDC || attribute?.isMental == true
    }

    /// The attribute the statistic is based on, when it has one.
    public var attribute: Attribute? {
        switch self {
        case .armorClass, .reflex: return .dexterity
        case .fortitude: return .constitution
        case .will, .perception: return .wisdom
        case let .skill(attribute), let .strikeAttack(attribute), let .strikeDamage(attribute): return attribute
        case .spellAttack, .spellDC, .abilityDC, .speed: return nil
        }
    }
}

public enum ModifierType: String, Codable, Sendable {
    case status
    case circumstance
    case item
    case untyped
}

/// One bonus or penalty, with where it came from.
public struct Modifier: Hashable, Sendable {
    public var label: String
    public var value: Int
    public var type: ModifierType

    public init(label: String, value: Int, type: ModifierType) {
        self.label = label
        self.value = value
        self.type = type
    }

    /// Applies the stacking rules: of each typed bonus or penalty only the largest counts; untyped ones all
    /// count. Returns the modifiers that apply, in their original order.
    public static func applying(_ modifiers: [Modifier]) -> [Modifier] {
        var kept: [Modifier] = []
        for modifier in modifiers where modifier.value != 0 {
            guard modifier.type != .untyped else {
                kept.append(modifier)
                continue
            }
            let rival = kept.firstIndex { $0.type == modifier.type && ($0.value < 0) == (modifier.value < 0) }
            if let rival {
                if abs(modifier.value) > abs(kept[rival].value) { kept[rival] = modifier }
            } else {
                kept.append(modifier)
            }
        }
        return kept
    }
}

/// A base value with the modifiers that change it, for showing a number and its breakdown.
public struct AdjustedValue: Hashable, Sendable {
    public var base: Int
    public var modifiers: [Modifier]

    public init(base: Int, modifiers: [Modifier] = []) {
        self.base = base
        self.modifiers = Modifier.applying(modifiers)
    }

    public var value: Int { base + modifiers.reduce(0) { $0 + $1.value } }
    public var change: Int { value - base }
    public var isChanged: Bool { change != 0 }
}
