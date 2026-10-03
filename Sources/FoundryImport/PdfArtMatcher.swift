import CombatPadKit
import Foundation

/// One image extracted from a Paizo PDF by `scripts/extract_pdf_art.py`.
public struct PdfArtEntry: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable {
        case token
        case pawn
        case cardBack
    }

    public var name: String
    public var collection: String
    public var game: Game
    /// "remaster" or "legacy", used to prefer the card set that matches the creature.
    public var era: String
    public var kind: Kind
    /// Relative to the `Generated` folder.
    public var path: String
}

/// Matches PDF art to creatures by name. Names are compared as sets of words, so "AGATHION, VICUNAL"
/// matches "Vicunal Agathion"; a card title's family prefix ("AEON, AXIOMITE") is optional.
public struct PdfArtMatcher {
    private var byName: [String: [PdfArtEntry]] = [:]
    /// Manual fixes: creature name → PDF art name, from `art-overrides.json`.
    private var overrides: [String: String]

    public init(entries: [PdfArtEntry], overrides: [String: String] = [:]) {
        self.overrides = Dictionary(uniqueKeysWithValues: overrides.map { (Self.normalized($0.key), $0.value) })
        for entry in entries {
            for key in Self.keys(forArtName: entry.name) {
                byName["\(entry.game.rawValue)|\(key)", default: []].append(entry)
            }
        }
    }

    /// The best entry of each kind for a creature.
    public func art(for creature: Creature) -> [PdfArtEntry.Kind: PdfArtEntry] {
        let name = overrides[Self.normalized(creature.name)] ?? creature.name
        let candidates = Self.lookupKeys(for: name).lazy
            .compactMap { byName["\(creature.game.rawValue)|\($0)"] }
            .first ?? []
        let preferredEra = creature.source.isRemastered ? "remaster" : "legacy"
        var result: [PdfArtEntry.Kind: PdfArtEntry] = [:]
        let ordered = candidates.sorted { (eraRank($0, preferredEra), $0.path) < (eraRank($1, preferredEra), $1.path) }
        for entry in ordered where result[entry.kind] == nil {
            result[entry.kind] = entry
        }
        return result
    }

    private func eraRank(_ entry: PdfArtEntry, _ preferredEra: String) -> Int {
        entry.era == preferredEra ? 0 : 1
    }

    /// The name as is, then without "spellcaster", then without any parenthetical, so variants such
    /// as "Host Dragon (Adult, Spellcaster)" share the art of "Host Dragon (Adult)" or "Host Dragon".
    static func lookupKeys(for name: String) -> [String] {
        let full = normalized(name)
        let withoutSpellcaster = full.split(separator: " ").filter { $0 != "spellcaster" }.joined(separator: " ")
        let bare = normalized(name.replacingOccurrences(of: #"\s*\([^)]*\)"#, with: "", options: .regularExpression))
        var keys: [String] = []
        for key in [full, withoutSpellcaster, bare] where !key.isEmpty && !keys.contains(key) {
            keys.append(key)
        }
        return keys
    }

    /// Lowercased words without punctuation, sorted, so word order doesn't matter.
    static func normalized(_ name: String) -> String {
        let words = name.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "'")).inverted)
            .filter { !$0.isEmpty }
        return words.sorted().joined(separator: " ")
    }

    /// The whole name, and for "FAMILY, MEMBER" titles the member alone too.
    static func keys(forArtName name: String) -> [String] {
        var keys = [normalized(name)]
        if let comma = name.firstIndex(of: ",") {
            let member = normalized(String(name[name.index(after: comma)...]))
            if !member.isEmpty && !keys.contains(member) { keys.append(member) }
        }
        return keys
    }
}
