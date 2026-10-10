import Foundation

/// One piece of art in the user's art library, as the matcher sees it.
public struct LibraryArt: Sendable, Equatable {
    public var id: UUID
    public var name: String
    public var game: Game
    /// True when a remastered product (Monster Core, NPC Core, …) prints it.
    public var isRemastered: Bool
    /// True when its sharpest print is a round token's art, rather than a figure or a pawn.
    public var isToken: Bool
    /// True when some PDF printing it can be read.
    public var isAvailable: Bool
    /// The PDFs that print it.
    public var sourceTitles: [String]

    public init(id: UUID, name: String, game: Game, isRemastered: Bool, isToken: Bool, isAvailable: Bool,
                sourceTitles: [String]) {
        self.id = id
        self.name = name
        self.game = game
        self.isRemastered = isRemastered
        self.isToken = isToken
        self.isAvailable = isAvailable
        self.sourceTitles = sourceTitles
    }
}

/// A creature's art from the library: what to draw for its portrait and its token, and when art matched but
/// can't be drawn, the PDFs it needs.
public struct MatchedArt: Sendable, Equatable {
    public var portrait: UUID?
    public var token: UUID?
    /// Titles of the missing PDFs the creature's art comes from; empty when it can be drawn or there is none.
    public var missingSources: [String]

    public static let none = MatchedArt(portrait: nil, token: nil, missingSources: [])
}

/// Matches the user's art to creatures by name. Names are compared as sets of words, so "AGATHION, VICUNAL"
/// matches "Vicunal Agathion"; a card title's family prefix ("AEON, AXIOMITE") is optional.
public struct LibraryArtMatcher: Sendable {
    /// The prefix of an art path drawn from the library: `library:<entry id>`.
    public static let pathPrefix = "library:"

    private var byName: [String: [LibraryArt]] = [:]
    /// Manual fixes: creature name → the name its art has in a PDF, from `art-overrides.json`.
    private var overrides: [String: String]

    public init(art: [LibraryArt] = [], overrides: [String: String] = [:]) {
        self.overrides = Dictionary(uniqueKeysWithValues: overrides.map { (Self.normalized($0.key), $0.value) })
        for entry in art {
            for key in Self.keys(forArtName: entry.name) {
                byName["\(entry.game.rawValue)|\(key)", default: []].append(entry)
            }
        }
    }

    /// The best art for a creature: drawable before missing, then the creature's era, then figures and pawns
    /// for the portrait and tokens for the token.
    public func art(forCreatureNamed creatureName: String, game: Game, isRemastered: Bool) -> MatchedArt {
        let name = overrides[Self.normalized(creatureName)] ?? creatureName
        let candidates = Self.lookupKeys(for: name).lazy.compactMap { byName["\(game.rawValue)|\($0)"] }.first ?? []
        guard !candidates.isEmpty else { return .none }
        let ranked = candidates.sorted { first, second in
            (first.isAvailable ? 0 : 1, first.isRemastered == isRemastered ? 0 : 1)
                < (second.isAvailable ? 0 : 1, second.isRemastered == isRemastered ? 0 : 1)
        }
        let available = ranked.filter(\.isAvailable)
        let portrait = available.first { !$0.isToken } ?? available.first
        let token = available.first(where: \.isToken) ?? portrait
        let missing = available.isEmpty ? Array(Set(ranked.flatMap(\.sourceTitles))).sorted() : []
        return MatchedArt(portrait: portrait?.id, token: token?.id, missingSources: missing)
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

    /// Lowercased words without punctuation or accents, sorted, so word order doesn't matter.
    static func normalized(_ name: String) -> String {
        let words = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
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
