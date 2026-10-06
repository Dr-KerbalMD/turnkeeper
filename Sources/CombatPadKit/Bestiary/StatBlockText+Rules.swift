import Foundation

/// Spells and rules text, the two parts of a stat block with their own small grammar.
public extension StatBlockText {
    /// "5th dispel magic, wall of fire (×2); Cantrips (4th) light; Constant (5th) see invisibility" into ranks.
    static func spellRanks(_ text: String) -> [SpellRank] {
        list(text, separator: ";").compactMap { segment in
            guard let match = segment.firstMatch(of: rankPattern) else { return nil }
            let kindWord = capture(match, "kind").lowercased()
            let kind: SpellRank.Kind = kindWord.isEmpty
                ? .ranked : (kindWord.hasPrefix("cantrip") ? .cantrips : .constant)
            let rank = Int(capture(match, "number")) ?? 1
            let spells = list(String(segment[match.range.upperBound...])).map { piece -> SpellEntry in
                let (name, note) = splitParenthetical(piece)
                return SpellEntry(name: name, note: note)
            }
            let note = capture(match, "note")
            return SpellRank(kind: kind, rank: rank, spells: spells, note: kind == .ranked ? note : "")
        }
    }

    static func format(_ ranks: [SpellRank]) -> String {
        ranks.map { rank in
            let ordinal = ordinalText(rank.rank)
            let label: String
            switch rank.kind {
            case .cantrips: label = "Cantrips (\(ordinal))"
            case .constant: label = "Constant (\(ordinal))"
            case .ranked: label = rank.note.isEmpty ? ordinal : "\(ordinal) (\(rank.note))"
            }
            let spells = rank.spells.map { $0.note.isEmpty ? $0.name : "\($0.name) (\($0.note))" }
            return label + " " + spells.joined(separator: ", ")
        }
        .joined(separator: "; ")
    }

    /// Plain rules text into `RulesText`: "DC 22 basic Reflex" becomes a check, "2d6 fire" damage, and action
    /// symbols (◆ ◆◆ ◆◆◆ ⤾ ◇, or "[two-actions]") become glyphs, so templates and conditions adjust them.
    /// `**bold**`, `*italic*` and line breaks are kept.
    static func rulesText(_ text: String) -> RulesText {
        var markup = text.replacingOccurrences(of: "\r", with: "")
        for (pattern, token) in glyphs {
            markup = markup.replacingOccurrences(of: pattern, with: token)
        }
        markup = markup.replacing(checkPattern) { match -> String in
            let statistic = capture(match, "statistic").lowercased()
            let check = CheckReference(statistic: statistic == "flat check" ? "flat" : statistic,
                                       difficultyClass: Int(capture(match, "dc")) ?? 0,
                                       isBasic: !capture(match, "basic").isEmpty)
            return RulesRun.check(check).markup
        }
        markup = markup.replacing(damagePattern) { match -> String in
            let found = String(markup[match.range])
            let parts = damage(found)
            return parts.isEmpty ? found : RulesRun.damage(parts).markup
        }
        return RulesText(markup.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }.joined(separator: "\n"))
    }

    /// `RulesText` back into the plain text the editor shows.
    static func plainText(_ text: RulesText) -> String {
        text.paragraphs.map { paragraph in
            guard case let .runs(runs) = paragraph else { return "---" }
            return runs.map(plain).joined()
        }
        .joined(separator: "\n")
    }

    private static func plain(_ run: RulesRun) -> String {
        switch run {
        case let .check(check):
            let statistic = check.statistic == "flat" ? "flat check" : check.statistic.capitalized
            return "DC \(check.difficultyClass) \(check.isBasic ? "basic " : "")\(statistic)"
        case let .damage(parts): return format(parts)
        case let .actions(cost): return glyphs.first { $0.1 == RulesRun.actions(cost).markup }?.0 ?? ""
        case let .link(label, _, emphasis): return RulesRun.text(label, emphasis).markup
        default: return run.markup
        }
    }

    private static let glyphs: [(String, String)] = [
        ("◆◆◆", "{{actions:3}}"), ("◆◆", "{{actions:2}}"), ("◆", "{{actions:1}}"), ("⤾", "{{actions:reaction}}"),
        ("↺", "{{actions:reaction}}"), ("◇", "{{actions:free}}"), ("[three-actions]", "{{actions:3}}"),
        ("[two-actions]", "{{actions:2}}"), ("[one-action]", "{{actions:1}}"),
        ("[reaction]", "{{actions:reaction}}"), ("[free-action]", "{{actions:free}}")
    ]

    private static let statistics = [
        "Fortitude", "Reflex", "Will", "Perception", "flat check", "Acrobatics", "Arcana", "Athletics", "Crafting",
        "Deception", "Diplomacy", "Intimidation", "Medicine", "Nature", "Occultism", "Performance", "Religion",
        "Society", "Stealth", "Survival", "Thievery", "Computers", "Piloting"
    ]

    private static let damageTypes = [
        "bludgeoning", "piercing", "slashing", "fire", "cold", "electricity", "acid", "sonic", "force", "mental",
        "poison", "bleed", "vitality", "void", "spirit", "untyped", "precision", "positive", "negative",
        "chaotic", "lawful", "good", "evil"
    ]

    // Built from strings so the patterns can be shared lists; matches are read by capture name.
    private static var rankPattern: Regex<AnyRegexOutput> {
        pattern(#"^\s*(?:(?<kind>Cantrips|Constant)\s*\()?(?<number>\d+)(?:st|nd|rd|th)\)?(?:\s*\((?<note>[^)]*)\))?"#)
    }

    private static var checkPattern: Regex<AnyRegexOutput> {
        pattern("DC (?<dc>\\d+) (?<basic>basic )?(?<statistic>" + statistics.joined(separator: "|") + ")")
    }

    private static var damagePattern: Regex<AnyRegexOutput> {
        pattern(#"\b\d+d\d+(?:\s*[+\-−–]\s*\d+)?(?: persistent)? (?:"# + damageTypes.joined(separator: "|") + #")\b"#)
    }

    private static func pattern(_ source: String) -> Regex<AnyRegexOutput> {
        // The sources above are constants, so a failure here is a programming error caught by the tests.
        (try? Regex(source).ignoresCase()) ?? Regex(verbatim: "\u{0}")
    }

    private static func capture(_ match: Regex<AnyRegexOutput>.Match, _ name: String) -> String {
        match.output[name]?.substring.map(String.init) ?? ""
    }

    private static func ordinalText(_ number: Int) -> String {
        let suffix: String
        switch (number % 10, number % 100) {
        case (_, 11...13): suffix = "th"
        case (1, _): suffix = "st"
        case (2, _): suffix = "nd"
        case (3, _): suffix = "rd"
        default: suffix = "th"
        }
        return "\(number)\(suffix)"
    }
}
