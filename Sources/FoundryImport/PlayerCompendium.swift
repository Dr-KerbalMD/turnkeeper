import CombatPadKit
import Foundation

/// The player-facing Item packs, linked in full so a player character's card can open any spell, feat,
/// action or item by name. Builds the name index the app looks them up in.
enum PlayerCompendium {
    /// Pack folders, the same in both systems.
    static let packFolders: Set<String> = [
        "spells", "feats", "class-features", "actions", "ancestry-features", "heritages", "equipment"
    ]

    private struct Named {
        var game: Game
        var kind: GlossaryIndex.Kind
        var name: String
        var id: String
        var isRemastered: Bool
    }

    /// Links every document in the player packs and returns their names. Remastered documents win a clash.
    static func link(scanner: PackScanner, links: LinkResolver) throws -> GlossaryIndex {
        var named: [Named] = []
        for game in Game.allCases {
            for pack in try scanner.packs(of: game, type: "Item") where packFolders.contains(pack.name) {
                named += documents(in: pack, scanner: scanner, links: links)
            }
        }
        var index = GlossaryIndex()
        for entry in named where entry.isRemastered {
            index.add(game: entry.game, kind: entry.kind, name: entry.name, id: entry.id)
        }
        for entry in named where !entry.isRemastered {
            index.add(game: entry.game, kind: entry.kind, name: entry.name, id: entry.id)
        }
        return index
    }

    /// Adds every linked trait, by its slug read as words ("versatile-p" as "versatile p").
    static func addTraits(of glossary: [GlossaryEntry], to index: inout GlossaryIndex) {
        for entry in glossary where entry.id.hasPrefix("trait.") {
            let parts = entry.id.split(separator: ".", maxSplits: 2).map(String.init)
            guard parts.count == 3, let game = Game(rawValue: parts[1]) else { continue }
            index.add(game: game, kind: .trait, name: parts[2], id: entry.id)
        }
    }

    private static func documents(in pack: PackLocation, scanner: PackScanner, links: LinkResolver) -> [Named] {
        scanner.documentFiles(in: pack).compactMap { file in
            guard let document = try? JSONValue(contentsOf: file), let kind = kind(of: document["type"].string),
                  let id = links.link(pack: "\(pack.game.rawValue).\(pack.compendiumName)",
                                      name: document["_id"].string) else { return nil }
            return Named(game: pack.game, kind: kind, name: document["name"].string, id: id,
                         isRemastered: document[path: "system.publication.remaster"].bool)
        }
    }

    static func kind(of type: String) -> GlossaryIndex.Kind? {
        switch type {
        case "spell": return .spell
        case "feat", "action", "heritage": return .ability
        case _ where GlossaryEntryParser.itemTypes.contains(type): return .item
        default: return nil
        }
    }
}
