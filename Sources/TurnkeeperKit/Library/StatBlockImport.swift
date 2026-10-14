import Bestiary
import Foundation

/// Plans the import of stat blocks copied from Pluck into an encounter: each block becomes a custom creature,
/// placed in the variant matching its subtier, or else the variant being edited.
public struct StatBlockImport: Sendable {
    public struct Item: Sendable {
        public var custom: CustomCreature
        public var variantLabel: String
        public var warnings: [String]
    }

    public var items: [Item]

    public init(blocks: [PluckStatBlock], scenario: Scenario, game: Game, currentLabel: String) {
        items = blocks.map { block in
            var custom = CustomCreature(campaignID: scenario.campaignID, game: game, name: "")
            custom.scenarioID = scenario.id
            custom.subtier = block.variant ?? ""
            let conversion = StatBlockConverter.convert(block, key: custom.key, game: game)
            custom.creature = conversion.creature
            let label = block.variant.flatMap { Self.variantLabel(forSubtier: $0, among: scenario.variantLabels) }
            return Item(custom: custom, variantLabel: label ?? currentLabel, warnings: conversion.warnings)
        }
    }

    /// The variant whose label names the same subtier, such as "1-2" for "1–2" or "Subtier 1–2".
    public static func variantLabel(forSubtier subtier: String, among labels: [String]) -> String? {
        let wanted = normalized(subtier)
        return labels.first { normalized($0) == wanted }
            ?? labels.first { normalized($0).hasSuffix(wanted) && !wanted.isEmpty }
    }

    private static func normalized(_ label: String) -> String {
        label.lowercased().replacingOccurrences(of: "–", with: "-").replacingOccurrences(of: "—", with: "-")
            .filter { !$0.isWhitespace }
    }

    /// Such as "Added Gwibble (Creature 3) and Rusty Spear Trap (Hazard 2). 1 line kept as text."
    public var summary: String {
        let names = items.map { item in
            let creature = item.custom.creature
            return "\(creature.name) (\(creature.kind == .hazard ? "Hazard" : "Creature") \(creature.level))"
        }
        var text = "Added " + Self.joined(names) + "."
        let warningCount = items.map(\.warnings.count).reduce(0, +)
        if warningCount > 0 { text += " \(warningCount) \(warningCount == 1 ? "note" : "notes") to review." }
        return text
    }

    /// "A", "A and B", "A, B and C": the app's text is English whatever the system's language.
    static func joined(_ names: [String]) -> String {
        guard let last = names.last, names.count > 1 else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " and " + last
    }

    public var warnings: [String] {
        items.flatMap { item in item.warnings.map { "\(item.custom.creature.name): \($0)" } }
    }
}
