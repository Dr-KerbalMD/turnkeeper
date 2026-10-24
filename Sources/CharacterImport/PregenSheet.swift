import Foundation

/// One file from `scripts/foundry/export-pregens.js`: every iconic pregen at every level, with the numbers
/// Foundry worked out.
public struct PregenFile: Codable, Sendable {
    /// `pf2e` or `sf2e`.
    public var system: String
    public var version: String
    public var pregens: [PregenSheet]
}

/// An iconic pregen at one level, as the export writes it.
public struct PregenSheet: Codable, Sendable, Hashable {
    public struct Modifier: Codable, Sendable, Hashable {
        public var name: String
        public var modifier: Int
    }

    public struct Movement: Codable, Sendable, Hashable {
        public var type: String
        public var feet: Int
    }

    public struct Attack: Codable, Sendable, Hashable {
        public var name: String
        public var attack: Int
        /// Foundry's formula, such as "1d4 + 1 + 2 piercing" or "(2d8 + 2) fire + 2 persistent fire".
        public var damage: String
        public var traits: [String]
        public var ranged: Bool
    }

    public struct Spell: Codable, Sendable, Hashable {
        public var name: String
        public var rank: Int
        public var isCantrip: Bool
        public var isFocus: Bool
    }

    public struct Casting: Codable, Sendable, Hashable {
        public var name: String
        public var tradition: String
        /// `prepared`, `spontaneous`, `innate` or `focus`.
        public var category: String
        public var dc: Int
        public var attack: Int
        public var spells: [Spell]
    }

    public struct Activity: Codable, Sendable, Hashable {
        public var name: String
        /// `action`, `reaction` or `free`.
        public var actionType: String
        public var actions: Int?
        public var traits: [String]
        public var frequency: String
        public var text: String
    }

    public var key: String
    public var name: String
    public var level: Int
    public var ancestry: String
    public var heritage: String
    public var background: String
    public var className: String
    public var size: String
    public var traits: [String]
    public var attributes: [String: Int]
    public var armorClass: Int
    public var shieldBonus: Int
    public var fortitude: Int
    public var reflex: Int
    public var will: Int
    public var perception: Int
    public var senses: [String]
    public var hitPoints: Int
    public var speeds: [Movement]
    public var languages: [String]
    public var skills: [Modifier]
    public var lores: [Modifier]
    public var classDC: Int
    public var strikes: [Attack]
    public var spellcasting: [Casting]
    public var abilities: [Activity]
    public var feats: [String]
    public var classFeatures: [String]
    public var items: [String]

    /// An animal or construct companion, which comes with its pregen rather than joining on its own.
    public var isCompanion: Bool { traits.contains("minion") }
}
