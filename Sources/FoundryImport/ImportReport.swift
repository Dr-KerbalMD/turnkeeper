import CombatPadKit
import Foundation

/// What the import found and what it couldn't handle, written to `Generated/import-report.md`.
public struct ImportReport: Sendable {
    public var creatureCount = 0
    /// Spells, items, conditions, traits and abilities the cards link to.
    public var glossaryCount = 0
    /// Enricher name → how often it could not be converted.
    public var unparsedEnrichers: [String: Int] = [:]
    /// Names of PDF images that matched no creature, for `art-overrides.json`.
    public var unmatchedPdfArt: [String] = []
    /// Creatures that borrowed art from a same-named creature in another pack.
    public var borrowedArt: [String] = []

    public init() {}

    public func markdown(creatures: [Creature]) -> String {
        var lines = ["# Bestiary import report", ""]
        lines += packTable(creatures)
        lines += ["", "## Starfinder creatures without art", ""]
        lines += creatures.filter { $0.game == .starfinder && !$0.art.hasArt }
            .map { "- \($0.name) (\($0.source.pack))" }
        lines += ["", "## Art borrowed from a creature of the same name", ""]
        lines += borrowedArt.sorted().map { "- \($0)" }
        lines += ["", "## PDF art that matched no creature", ""]
        lines += Set(unmatchedPdfArt).sorted().map { "- \($0)" }
        lines += ["", "## Enrichers left as plain text", ""]
        lines += unparsedEnrichers.sorted { $0.key < $1.key }.map { "- @\($0.key): \($0.value)" }
        return lines.joined(separator: "\n") + "\n"
    }

    private func packTable(_ creatures: [Creature]) -> [String] {
        var lines = [
            "\(creatureCount) creatures and complex hazards, \(glossaryCount) linked glossary entries.", "",
            "| Pack | Creatures | Hazards | Portrait | Token | Card back |",
            "|---|---:|---:|---:|---:|---:|"
        ]
        let byPack = Dictionary(grouping: creatures) { "\($0.game.rawValue).\($0.source.pack)" }
        for (pack, members) in byPack.sorted(by: { $0.key < $1.key }) {
            let hazards = members.filter { $0.kind == .hazard }.count
            let counts = [
                members.count - hazards, hazards,
                members.filter { !$0.art.portrait.isEmpty }.count,
                members.filter { !$0.art.token.isEmpty }.count,
                members.filter { !$0.art.cardBack.isEmpty }.count
            ]
            lines.append("| \(pack) | " + counts.map(String.init).joined(separator: " | ") + " |")
        }
        return lines
    }
}
