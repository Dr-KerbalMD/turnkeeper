import Foundation

/// Rules text in a compact markup that keeps checks and damage structured, so templates and conditions
/// can adjust them when shown.
///
/// - Paragraphs are separated by newlines. A paragraph of `---` is a horizontal rule.
/// - `**bold**` and `*italic*` mark emphasis.
/// - `{{check:reflex:34:basic}}` is a save or check against a DC (`basic` is optional).
/// - `{{damage:2d6+4|fire;1d6|bleed|persistent}}` is one or more damage parts.
/// - `{{actions:2}}` is an action glyph: `1`, `2`, `3`, `free` or `reaction`.
public struct RulesText: Codable, Sendable, Hashable, ExpressibleByStringLiteral {
    public var markup: String

    public init(_ markup: String = "") {
        self.markup = markup
    }

    public init(stringLiteral value: String) {
        markup = value
    }

    public init(from decoder: Decoder) throws {
        markup = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(markup)
    }

    public var isEmpty: Bool { markup.isEmpty }

    /// The text split into paragraphs of runs, ready to render.
    public var paragraphs: [RulesParagraph] {
        markup.split(separator: "\n", omittingEmptySubsequences: true).map { line in
            line == "---" ? .rule : .runs(RulesMarkupParser.runs(in: String(line)))
        }
    }
}

public enum RulesParagraph: Sendable, Hashable {
    case rule
    case runs([RulesRun])
}

public enum TextEmphasis: Sendable, Hashable {
    case plain
    case bold
    case italic
}

public struct CheckReference: Sendable, Hashable {
    /// "fortitude", "reflex", "will", "flat", or a skill slug.
    public var statistic: String
    public var difficultyClass: Int
    public var isBasic: Bool

    public init(statistic: String, difficultyClass: Int, isBasic: Bool = false) {
        self.statistic = statistic
        self.difficultyClass = difficultyClass
        self.isBasic = isBasic
    }
}

public enum RulesRun: Sendable, Hashable {
    case text(String, TextEmphasis)
    case check(CheckReference)
    case damage([DamagePart])
    case actions(ActionCost)

    /// The run written back as markup.
    public var markup: String { RulesMarkupParser.markup(for: self) }
}
