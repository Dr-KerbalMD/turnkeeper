import CombatPadKit
import Foundation

/// One compendium pack folder in the pf2e repository.
public struct PackLocation: Sendable {
    public var game: Game
    public var name: String
    public var directory: URL
}

/// Finds packs through the system manifests and lists their documents.
public struct PackScanner {
    public var repository: URL

    public init(repository: URL) {
        self.repository = repository
    }

    /// Every Actor pack of both games, in manifest order.
    public func actorPacks() throws -> [PackLocation] {
        try Game.allCases.flatMap { try packs(of: $0, type: "Actor") }
    }

    public func packs(of game: Game, type: String) throws -> [PackLocation] {
        let manifest = try JSONValue(contentsOf: repository.appendingPathComponent("system.\(game.rawValue).json"))
        return manifest["packs"].array.filter { $0["type"].string == type }.map { pack in
            let folder = (pack["path"].string as NSString).lastPathComponent
            return PackLocation(
                game: game,
                name: folder,
                directory: repository.appendingPathComponent("packs/\(game.rawValue)/\(folder)")
            )
        }
    }

    /// The JSON documents in a pack, searched recursively and sorted, without folder files.
    public func documentFiles(in pack: PackLocation) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: pack.directory, includingPropertiesForKeys: nil)
        else { return [] }
        return enumerator.compactMap { $0 as? URL }
            .filter { $0.pathExtension == "json" && !$0.lastPathComponent.hasPrefix("_") }
            .sorted { $0.path < $1.path }
    }
}
