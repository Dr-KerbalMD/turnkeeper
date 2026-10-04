import Foundation

/// Stat blocks read from plain text, as Pluck writes it for other apps or as copied from a PDF:
/// a header line ("Gwibble (1-2) — Creature 1" or "GWIBBLE CREATURE 1"), an optional trait line, then one
/// line per entry. Best effort: a line that can't be given a label is kept as unlabeled text.
public extension PluckStatBlock {
    static func blocks(fromPlainText text: String) -> [PluckStatBlock] {
        var blocks: [PluckStatBlock] = []
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            if let header = header(trimmed) {
                blocks.append(header)
            } else if let last = blocks.indices.last {
                blocks[last].add(line: trimmed)
            }
        }
        return blocks
    }

    /// Labels that open a line of a stat block.
    static let lineLabels = [
        "Perception", "Languages", "Skills", "Str", "Items", "AC", "HP", "Hardness", "Immunities", "Weaknesses",
        "Resistances", "Speed", "Melee", "Ranged", "Stealth", "Description", "Disable", "Routine", "Reset",
        "Rituals"
    ]

    /// Labels that carry on the line before rather than starting a new entry.
    private static let continuationLabels = [
        "Trigger", "Effect", "Requirements", "Requirement", "Frequency", "Critical Success", "Success",
        "Failure", "Critical Failure", "Saving Throw", "Maximum Duration", "Onset", "Stage"
    ]

    private static let glyphs = ["◆◆◆", "◆◆", "◆", "⤾", "↺", "◇", "[one-action]", "[two-actions]",
                                 "[three-actions]", "[reaction]", "[free-action]"]

    private static func header(_ line: String) -> PluckStatBlock? {
        let pattern = /^(?<name>.+?)\s*[—–-]?\s*(?<level>(?i:creature|hazard)\s+[-−]?\d+)$/
        guard let match = line.firstMatch(of: pattern) else { return nil }
        var name = String(match.output.name).trimmingCharacters(in: .whitespaces)
        var variant: String?
        if let subtier = name.firstMatch(of: /\s*\((?<subtier>\d+\s*[-–]\s*\d+)\)$/) {
            variant = String(subtier.output.subtier)
            name = String(name[..<subtier.range.lowerBound])
        }
        let level = String(match.output.level).capitalized
        return PluckStatBlock(name: name, level: level, variant: variant)
    }

    private mutating func add(line: String) {
        if let label = Self.label(of: line) {
            let text = String(line.dropFirst(label.count))
            entries.append(Entry(name: label, runs: [Run(text)]))
        } else if entries.isEmpty, traits.isEmpty {
            traits = StatBlockText.list(line)
        } else if let continuation = Self.continuationLabels.first(where: { line.hasPrefix($0 + " ") }) {
            let run = Run(" **\(continuation)**" + line.dropFirst(continuation.count))
            if entries.isEmpty { entries.append(Entry(name: "", runs: [])) }
            entries[entries.count - 1].runs.append(run)
        } else if let glyph = Self.glyphs.compactMap({ line.range(of: $0) }).min(by: { $0.lowerBound < $1.lowerBound }),
                  glyph.lowerBound > line.startIndex {
            let name = line[..<glyph.lowerBound].trimmingCharacters(in: .whitespaces)
            entries.append(Entry(name: name, runs: [Run(" " + line[glyph.lowerBound...])]))
        } else {
            entries.append(Entry(name: "", runs: [Run(line)]))
        }
    }

    private static func label(of line: String) -> String? {
        if let spells = line.firstMatch(of: /^(?<label>(?:[A-Z][a-z]+ ){1,3}(?:Spells|Rituals))\s/) {
            return String(spells.output.label)
        }
        return lineLabels.first { line == $0 || line.hasPrefix($0 + " ") }
    }
}
