import CombatPadKit
import Foundation

/// The Item packs of both systems, for following `Compendium.<system>.<pack>.Item.<id or name>` links.
/// A pack's documents are indexed by ID and name the first time a link points into it.
final class CompendiumIndex {
    private let scanner: PackScanner?
    /// `<system>.<compendium name>` → pack.
    private let packs: [String: PackLocation]
    private var indexes: [String: PackIndex] = [:]

    private struct PackIndex {
        var files: [String: URL] = [:]
        var names: [String: String] = [:]
        var idsByName: [String: String] = [:]
    }

    /// An index with no packs, which resolves nothing.
    init() {
        scanner = nil
        packs = [:]
    }

    init(scanner: PackScanner) throws {
        self.scanner = scanner
        let locations = try Game.allCases.flatMap { try scanner.packs(of: $0, type: "Item") }
        packs = Dictionary(locations.map { ("\($0.game.rawValue).\($0.compendiumName)", $0) },
                           uniquingKeysWith: { first, _ in first })
    }

    /// The glossary ID, `<system>.<pack>.<_id>`, of an Item link, or nil when it leads nowhere.
    func id(forLink link: String) -> String? {
        let parts = link.split(separator: ".", maxSplits: 4).map(String.init)
        guard parts.count == 5, parts[0] == "Compendium", parts[3] == "Item" else { return nil }
        return id(inPack: "\(parts[1]).\(parts[2])", idOrName: parts[4])
    }

    /// The glossary ID of the document in a pack, `<system>.<compendium name>`, with this `_id` or name.
    func id(inPack pack: String, idOrName: String) -> String? {
        guard let index = index(of: pack) else { return nil }
        if index.files[idOrName] != nil { return "\(pack).\(idOrName)" }
        return index.idsByName[idOrName.lowercased()].map { "\(pack).\($0)" }
    }

    /// The document with this glossary ID.
    func document(_ id: String) -> JSONValue? {
        location(of: id).flatMap { index, documentID in index.files[documentID] }
            .flatMap { try? JSONValue(contentsOf: $0) }
    }

    /// The name of the document with this glossary ID.
    func name(of id: String) -> String? {
        location(of: id).flatMap { index, documentID in index.names[documentID] }
    }

    private func location(of id: String) -> (PackIndex, String)? {
        let parts = id.split(separator: ".").map(String.init)
        guard parts.count == 3, let index = index(of: "\(parts[0]).\(parts[1])") else { return nil }
        return (index, parts[2])
    }

    private func index(of pack: String) -> PackIndex? {
        if let index = indexes[pack] { return index }
        guard let scanner, let location = packs[pack] else { return nil }
        var index = PackIndex()
        for file in scanner.documentFiles(in: location) {
            guard let document = try? JSONValue(contentsOf: file) else { continue }
            let id = document["_id"].string
            guard !id.isEmpty, index.files[id] == nil else { continue }
            index.files[id] = file
            index.names[id] = document["name"].string
            let name = document["name"].string.lowercased()
            if index.idsByName[name] == nil { index.idsByName[name] = id }
        }
        indexes[pack] = index
        return index
    }
}
