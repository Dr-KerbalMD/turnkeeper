import CombatPadKit
import Foundation

/// Turns links in Foundry data into glossary IDs, and remembers each ID it hands out until the glossary
/// builder takes them, so the glossary holds exactly what is linked.
final class LinkResolver {
    private let compendium: CompendiumIndex
    let traits: TraitGlossary
    /// A creature's own items that are linked, by glossary ID `<creature key>.<item _id>`.
    private var embedded: [String: JSONValue] = [:]
    private var pending: Set<String> = []

    /// What a glossary ID leads to.
    enum Source {
        case document(JSONValue, game: Game)
        case trait(slug: String, game: Game)
        case missing
    }

    /// A resolver that links nothing.
    convenience init() {
        self.init(compendium: CompendiumIndex(), traits: TraitGlossary())
    }

    init(compendium: CompendiumIndex, traits: TraitGlossary) {
        self.compendium = compendium
        self.traits = traits
    }

    /// The ID for a `Compendium.…` link. Effect packs only automate rules, so they aren't linked.
    func link(compendium uuid: String) -> String? {
        guard !uuid.contains("-effects."), let id = compendium.id(forLink: uuid) else { return nil }
        return recorded(id)
    }

    /// The name of the compendium document with this ID.
    func name(of id: String) -> String? {
        compendium.name(of: id)
    }

    /// The ID for a document in a pack, `<system>.<compendium name>`, by name.
    func link(pack: String, name: String) -> String? {
        compendium.id(inPack: pack, idOrName: name).map(recorded)
    }

    /// `trait.<game>.<slug>`, when the trait has a description.
    func link(trait slug: String, game: Game) -> String? {
        traits.describedSlug(slug, game: game).map { recorded("trait.\(game.rawValue).\($0)") }
    }

    /// The ID for a creature's own copy of an item, kept for the glossary.
    func link(embedded item: JSONValue, owner: String) -> String {
        let id = "\(owner).\(item["_id"].string)"
        embedded[id] = item
        return recorded(id)
    }

    /// The IDs handed out since the last call, sorted.
    func takeLinked() -> [String] {
        defer { pending = [] }
        return pending.sorted()
    }

    func source(of id: String) -> Source {
        let game = Game(rawValue: String(id.prefix { $0 != "." })) ?? .pathfinder
        if let item = embedded[id] { return .document(item, game: game) }
        if id.hasPrefix("trait.") {
            let parts = id.split(separator: ".", maxSplits: 2).map(String.init)
            guard parts.count == 3, let traitGame = Game(rawValue: parts[1]) else { return .missing }
            return .trait(slug: parts[2], game: traitGame)
        }
        return compendium.document(id).map { .document($0, game: game) } ?? .missing
    }

    private func recorded(_ id: String) -> String {
        pending.insert(id)
        return id
    }
}
