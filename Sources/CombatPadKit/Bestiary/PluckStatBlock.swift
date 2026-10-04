import Foundation

/// A stat block copied from Pluck: the JSON it puts on the pasteboard under `typeIdentifier`, or its plain
/// text read back into the same shape.
public struct PluckStatBlock: Codable, Sendable, Equatable {
    public static let typeIdentifier = "io.github.scooper4711.pluck.statblock"

    /// A run of text with its styling. Action glyphs are tokens such as `[two-actions]`.
    public struct Run: Codable, Sendable, Equatable {
        public var text: String
        public var isBold = false
        public var isItalic = false

        public init(_ text: String, isBold: Bool = false, isItalic: Bool = false) {
            self.text = text
            self.isBold = isBold
            self.isItalic = isItalic
        }
    }

    /// One labeled line, such as `Perception +6; darkvision`. Later labels such as Fort or Damage stay in the
    /// runs, in bold.
    public struct Entry: Codable, Sendable, Equatable {
        public var name: String
        public var runs: [Run]

        public init(name: String, runs: [Run]) {
            self.name = name
            self.runs = runs
        }

        /// The text after the label, without styling.
        public var text: String { runs.map(\.text).joined().trimmingCharacters(in: .whitespaces) }

        /// The text after the label with `**bold**` and `*italic*` marks, for rules text.
        public var markdown: String {
            runs.map { run in
                let trimmed = run.text.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty, run.isBold || run.isItalic else { return run.text }
                let mark = run.isBold ? "**" : "*"
                let leading = run.text.prefix { $0 == " " }
                let trailing = String(run.text.reversed().prefix { $0 == " " })
                return leading + mark + trimmed + mark + trailing
            }
            .joined()
            .trimmingCharacters(in: .whitespaces)
        }
    }

    /// The name as printed, usually in capitals.
    public var name: String
    /// "Creature 1" or "Hazard 3".
    public var level: String
    /// The trait boxes as printed: rarity, alignment, size, then the rest.
    public var traits: [String]
    public var entries: [Entry]
    /// The organized-play subtier the block belongs to, such as "1-2".
    public var variant: String?
    /// The document the block came from.
    public var source: String?

    public init(name: String, level: String, traits: [String] = [], entries: [Entry] = [],
                variant: String? = nil, source: String? = nil) {
        self.name = name
        self.level = level
        self.traits = traits
        self.entries = entries
        self.variant = variant
        self.source = source
    }

    /// The blocks in Pluck's pasteboard JSON, `{ "format": 1, "blocks": [...] }`.
    public static func blocks(from data: Data) throws -> [PluckStatBlock] {
        try JSONDecoder().decode(Payload.self, from: data).blocks
    }

    private struct Payload: Codable {
        var format: Int
        var blocks: [PluckStatBlock]
    }

    /// The index of the printed section each entry is in: 0 before AC, 1 for the defenses up to Speed,
    /// 2 from Speed on.
    public func section(ofEntryAt index: Int) -> Int {
        let defenseStart = entries.firstIndex { $0.name == "AC" } ?? entries.count
        let offenseStart = entries.firstIndex { $0.name == "Speed" } ?? entries.count
        if index >= max(defenseStart, offenseStart) { return 2 }
        return index >= defenseStart ? 1 : 0
    }
}
