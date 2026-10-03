import CombatPadKit
import Foundation

/// Art for one creature found in a Foundry module's `compendiumArtMappings`.
public struct FoundryArt: Sendable, Equatable {
    public var module: String
    /// Paths relative to the Foundry `Data` folder, such as `modules/x/assets/portraits/y.webp`.
    public var portrait: String
    public var token: String
}

/// Reads every module's art mapping and picks one entry per creature by module priority.
public struct FoundryArtMapper {
    public var modulesDirectory: URL
    /// Modules listed here win, in order; the others follow alphabetically.
    public var priority: [String]

    public init(modulesDirectory: URL, priority: [String]) {
        self.modulesDirectory = modulesDirectory
        self.priority = priority
    }

    /// Art by creature key (`<game>.<pack>.<id>`), for keys present in `knownKeys`.
    public func art(knownKeys: Set<String>) -> [String: FoundryArt] {
        var result: [String: FoundryArt] = [:]
        for module in orderedModules().reversed() {
            for (key, art) in mappings(of: module) where knownKeys.contains(key) {
                result[key] = art
            }
        }
        return result
    }

    private func orderedModules() -> [String] {
        let installed = (try? FileManager.default.contentsOfDirectory(atPath: modulesDirectory.path)) ?? []
        let listed = priority.filter(installed.contains)
        return listed + installed.filter { !priority.contains($0) }.sorted()
    }

    private func mappings(of module: String) -> [String: FoundryArt] {
        let manifestURL = modulesDirectory.appendingPathComponent("\(module)/module.json")
        guard let manifest = try? JSONValue(contentsOf: manifestURL) else { return [:] }
        var result: [String: FoundryArt] = [:]
        for game in Game.allCases {
            let mappingPath = manifest[path: "flags.compendiumArtMappings"][game.rawValue]["mapping"].string
            guard !mappingPath.isEmpty, let mapping = try? JSONValue(contentsOf: dataURL(mappingPath)) else { continue }
            for (packKey, actors) in mapping.object {
                let parts = packKey.split(separator: ".", maxSplits: 1).map(String.init)
                guard parts.count == 2, parts[0] == game.rawValue else { continue }
                for (actorID, entry) in actors.object {
                    result["\(game.rawValue).\(parts[1]).\(actorID)"] = FoundryArt(
                        module: module,
                        portrait: entry["actor"].string,
                        token: entry[path: "token.texture.src"].string
                    )
                }
            }
        }
        return result
    }

    /// Resolves a `modules/...` path from a mapping file against the Foundry `Data` folder.
    public func dataURL(_ path: String) -> URL {
        let decoded = path.removingPercentEncoding ?? path
        return modulesDirectory.deletingLastPathComponent().appendingPathComponent(decoded)
    }
}
