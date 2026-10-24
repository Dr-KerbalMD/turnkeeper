import Bestiary
import TurnkeeperKit
import Foundation

/// The iconic pregens a GM can add as Table Buddies, read from the exported files in `Generated/Pregens`.
public struct PregenCatalog: PregenSource {
    /// A pregen as the Add Table Buddy menu lists it.
    public struct Character: Sendable, Hashable, Identifiable {
        public var key: String
        public var name: String
        public var className: String
        public var game: Game
        public var id: String { key }
    }

    private let sheets: [String: [Int: (sheet: PregenSheet, game: Game)]]

    /// No pregens, for builds without the exported files.
    public init() {
        sheets = [:]
    }

    /// Reads every `*-pregens.json` in a folder; a file that can't be read is skipped.
    public init(folder: URL) {
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        let files = urls.filter { $0.lastPathComponent.hasSuffix("-pregens.json") }
            .compactMap { try? JSONDecoder().decode(PregenFile.self, from: Data(contentsOf: $0)) }
        self.init(files: files)
    }

    init(files: [PregenFile]) {
        var sheets: [String: [Int: (sheet: PregenSheet, game: Game)]] = [:]
        for file in files {
            let game = Game(rawValue: file.system) ?? .pathfinder
            for pregen in file.pregens where !pregen.isCompanion {
                sheets[pregen.key, default: [:]][pregen.level] = (pregen, game)
            }
        }
        self.sheets = sheets
    }

    /// The pregens for a game, by name.
    public func characters(for game: Game) -> [Character] {
        sheets.compactMap { key, levels -> Character? in
            guard let first = levels.values.first, first.game == game else { return nil }
            return Character(key: key, name: first.sheet.name, className: first.sheet.className, game: game)
        }
        .sorted { $0.name < $1.name }
    }

    public func levels(of key: String) -> [Int] {
        (sheets[key]?.keys).map { $0.sorted() } ?? []
    }

    public func pregen(_ key: String, level: Int) -> Pregen? {
        guard let entry = sheets[key]?[level] else { return nil }
        let sheet = PregenSheetReader.creature(from: entry.sheet, game: entry.game)
        return Pregen(key: key, name: entry.sheet.name, level: level, sheet: sheet, hitPoints: entry.sheet.hitPoints)
    }
}
