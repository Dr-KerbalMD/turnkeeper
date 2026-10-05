import CombatPadKit
import Foundation

/// Turns a linked Foundry document or trait into a glossary entry.
struct GlossaryEntryParser {
    var text: RulesTextConverter

    private var links: LinkResolver { text.links }

    /// The entry for a glossary ID, or nil when the ID leads nowhere.
    mutating func entry(_ id: String) -> GlossaryEntry? {
        switch links.source(of: id) {
        case let .document(document, game): return documentEntry(id, document, game: game)
        case let .trait(slug, game): return traitEntry(id, slug: slug, game: game)
        case .missing: return nil
        }
    }

    private mutating func documentEntry(_ id: String, _ document: JSONValue, game: Game) -> GlossaryEntry {
        let system = document["system"]
        let level = Self.level(document)
        let description = system[path: "description.value"].string
            .replacingOccurrences(of: "(@item.level)", with: "\(level)")
            .replacingOccurrences(of: "(@item.rank)", with: "\(level)")
        let details = document["type"].string == "spell" ? SpellDetails.markup(system) : ""
        let body = text.convert(description).markup
        let markup = [details, body].filter { !$0.isEmpty }.joined(separator: "\n---\n")
        var entry = GlossaryEntry(id: id, name: document["name"].string,
                                  category: Self.category(document, id: id, level: level), text: RulesText(markup))
        entry.cost = AbilityParser.cost(system)
        let rarity = system[path: "traits.rarity"].string
        entry.traits = (rarity.isEmpty || rarity == "common" ? [] : [rarity]) + system[path: "traits.value"].strings
        for slug in entry.traits {
            if let target = links.link(trait: slug, game: game) { entry.links.add(.trait, slug, target: target) }
        }
        return entry
    }

    private mutating func traitEntry(_ id: String, slug: String, game: Game) -> GlossaryEntry {
        let name = slug.split(separator: "-").map(\.capitalized).joined(separator: " ")
        return GlossaryEntry(id: id, name: name, category: "Trait",
                             text: text.convert(links.traits.description(of: slug, game: game)))
    }

    /// A spell's heightened rank on a creature, else its rank or item level.
    private static func level(_ document: JSONValue) -> Int {
        document[path: "system.location.heightenedLevel"].optionalInt ?? document[path: "system.level.value"].int
    }

    static let itemTypes: Set<String> = [
        "weapon", "armor", "shield", "equipment", "consumable", "treasure", "backpack", "ammo", "kit"
    ]

    /// "Spell 3", "Cantrip 1", "Item 5", "Condition", "Action" and the like.
    static func category(_ document: JSONValue, id: String, level: Int) -> String {
        let type = document["type"].string
        if itemTypes.contains(type) { return "Item \(level)" }
        switch type {
        case "spell": return "\(spellKind(document)) \(level)"
        case "feat": return "Feat \(level)"
        case "condition": return "Condition"
        case "action": return id.contains(".actions") ? "Action" : "Ability"
        default: return type.capitalized
        }
    }

    private static func spellKind(_ document: JSONValue) -> String {
        let traits = document[path: "system.traits.value"].strings
        if traits.contains("cantrip") { return "Cantrip" }
        if traits.contains("focus") { return "Focus" }
        return document[path: "system.ritual"].isNull ? "Spell" : "Ritual"
    }
}

/// The lines above a spell's text: cast, range, area and targets, then defense and duration.
enum SpellDetails {
    static func markup(_ system: JSONValue) -> String {
        let first = [
            field("Cast", cast(system[path: "time.value"].string)),
            field("Range", system[path: "range.value"].string),
            field("Area", area(system["area"])),
            field("Targets", system[path: "target.value"].string)
        ]
        let second = [field("Defense", defense(system[path: "defense.save"])), field("Duration", duration(system))]
        return [first, second].map { $0.compactMap { $0 }.joined(separator: "; ") }
            .filter { !$0.isEmpty }.joined(separator: "\n")
    }

    private static func field(_ label: String, _ value: String) -> String? {
        value.isEmpty ? nil : "**\(label)** \(value)"
    }

    private static let glyphs = ["1": "1", "2": "2", "3": "3", "reaction": "reaction", "free": "free"]

    /// "2" becomes the two-action glyph and "1 to 3" two glyphs; "1 minute" stays as written.
    private static func cast(_ time: String) -> String {
        if let glyph = glyphs[time] { return "{{actions:\(glyph)}}" }
        let range = time.split(separator: " ")
        if range.count == 3, range[1] == "to", let low = glyphs[String(range[0])], let high = glyphs[String(range[2])] {
            return "{{actions:\(low)}} to {{actions:\(high)}}"
        }
        return time
    }

    private static func area(_ area: JSONValue) -> String {
        guard let size = area["value"].optionalInt else { return "" }
        return "\(size)-foot \(area["type"].string)"
    }

    private static func defense(_ save: JSONValue) -> String {
        let statistic = save["statistic"].string
        guard !statistic.isEmpty else { return "" }
        return (save["basic"].bool ? "basic " : "") + statistic.capitalized
    }

    private static func duration(_ system: JSONValue) -> String {
        let value = system[path: "duration.value"].string
        guard system[path: "duration.sustained"].bool else { return value }
        return value.isEmpty ? "sustained" : "sustained up to \(value)"
    }
}

/// Builds the glossary: every entry linked so far, then every entry those link to, and no further.
enum GlossaryBuilder {
    static let depth = 2

    static func entries(parser: inout GlossaryEntryParser) -> [GlossaryEntry] {
        var entries: [String: GlossaryEntry] = [:]
        var linked = parser.text.links.takeLinked()
        for _ in 1...depth {
            for id in linked where entries[id] == nil {
                entries[id] = parser.entry(id)
            }
            linked = parser.text.links.takeLinked()
        }
        return entries.values.sorted { $0.id < $1.id }
    }
}
