import Foundation

/// Turns a stat block copied from Pluck into a `Creature`. Each labeled entry is read with the same parsers
/// as the custom creature editor; whatever can't be read is kept as ability text and reported.
public struct StatBlockConverter {
    public struct Conversion: Sendable {
        public var creature: Creature
        /// Lines that were kept as text, such as "Melee: couldn't read the attack bonus".
        public var warnings: [String]
    }

    let block: PluckStatBlock
    var creature: Creature
    var warnings: [String] = []

    public static func convert(_ block: PluckStatBlock, key: String, game: Game) -> Conversion {
        var converter = StatBlockConverter(block: block, key: key, game: game)
        converter.readEntries()
        return Conversion(creature: converter.creature, warnings: converter.warnings)
    }

    private init(block: PluckStatBlock, key: String, game: Game) {
        self.block = block
        creature = Creature(key: key, name: Self.titleCase(block.name), game: game)
        creature.source = Source(pack: "custom", title: block.source ?? "Custom", isRemastered: true)
        let levelWords = block.level.split(separator: " ")
        creature.kind = levelWords.first?.lowercased() == "hazard" ? .hazard : .creature
        creature.level = levelWords.last.flatMap { StatBlockText.integer(String($0)) } ?? 0
        creature.traits = Self.traitLine(block.traits)
        creature.speeds = []
        if creature.kind == .hazard {
            creature.hazard = HazardDetails(stealth: 0, description: RulesText(""))
            creature.initiativeStatistic = "stealth"
        }
    }

    private mutating func readEntries() {
        for (index, entry) in block.entries.enumerated() {
            if !readStatistic(entry), !readDefense(entry), !readOffense(entry) {
                readAbility(entry, section: block.section(ofEntryAt: index))
            }
        }
        if creature.kind == .hazard, creature.abilities.contains(where: { $0.name == "Routine" }) == false,
           creature.hazard?.routine.markup.isEmpty ?? true {
            warnings.append("No Routine: a simple hazard, which doesn't take turns")
        }
    }

    // MARK: Basics

    static func titleCase(_ name: String) -> String {
        name.lowercased().split(separator: " ").map { word in
            word.split(separator: "-", omittingEmptySubsequences: false)
                .map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: "-")
        }
        .joined(separator: " ")
    }

    private static let rarities = ["uncommon", "rare", "unique"]
    private static let sizes = ["tiny", "small", "medium", "large", "huge", "gargantuan"]
    private static let alignments: Set<String> = ["lg", "ng", "cg", "ln", "n", "cn", "le", "ne", "ce"]

    static func traitLine(_ printed: [String]) -> TraitLine {
        let traits = printed.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        let rarity = traits.first { rarities.contains($0) } ?? "common"
        let size = traits.first { sizes.contains($0) }?.capitalized ?? "Medium"
        let rest = traits.filter { !rarities.contains($0) && !sizes.contains($0) && !alignments.contains($0) }
        return TraitLine(rarity: rarity, size: size, traits: rest)
    }

    mutating func warn(_ entry: PluckStatBlock.Entry, _ problem: String) {
        warnings.append("\(entry.name.isEmpty ? "Text" : entry.name): \(problem)")
    }

    /// Keeps an entry that couldn't be read as an ability, so nothing is lost.
    mutating func keepAsText(_ entry: PluckStatBlock.Entry, section: Int, problem: String) {
        warn(entry, problem)
        readAbility(entry, section: section)
    }
}
