import Foundation

/// The bundled bestiary: the index for browsing, with full stat blocks loaded a pack at a time.
public final class BestiaryStore: @unchecked Sendable {
    public let directory: URL
    public let index: BestiaryIndex
    public let conditions: [ConditionDefinition]
    private let entriesByKey: [String: BestiaryIndexEntry]
    private var packs: [String: [String: Creature]] = [:]
    private let lock = NSLock()

    /// Loads `Bestiary/index.json` and `Bestiary/conditions.json` from a `Generated` folder.
    public init(generatedDirectory: URL) throws {
        directory = generatedDirectory
        let bestiary = generatedDirectory.appendingPathComponent("Bestiary")
        let indexData = try Data(contentsOf: bestiary.appendingPathComponent("index.json"))
        index = try JSONDecoder().decode(BestiaryIndex.self, from: indexData)
        let conditionsData = try? Data(contentsOf: bestiary.appendingPathComponent("conditions.json"))
        conditions = conditionsData.flatMap { try? JSONDecoder().decode([ConditionDefinition].self, from: $0) } ?? []
        entriesByKey = Dictionary(index.entries.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// An empty bestiary, for previews and when nothing has been imported.
    public init() {
        directory = URL(fileURLWithPath: "/")
        index = BestiaryIndex(sourceRevision: "", entries: [])
        conditions = []
        entriesByKey = [:]
    }

    /// Finds the `Generated` folder: the `COMBAT_PAD_GENERATED` environment variable, the app bundle, or,
    /// when run from the package during development, the repository's own `Generated` folder.
    public static func locateGeneratedDirectory(sourceFile: String = #filePath) -> URL? {
        let candidates = [
            ProcessInfo.processInfo.environment["COMBAT_PAD_GENERATED"].map { URL(fileURLWithPath: $0) },
            Bundle.main.resourceURL?.appendingPathComponent("Generated"),
            URL(fileURLWithPath: sourceFile).deletingLastPathComponent()
                .appendingPathComponent("../../../Generated").standardizedFileURL
        ]
        return candidates.compactMap { $0 }.first { url in
            FileManager.default.fileExists(atPath: url.appendingPathComponent("Bestiary/index.json").path)
        }
    }

    public func entry(_ key: String) -> BestiaryIndexEntry? {
        entriesByKey[key]
    }

    /// The full stat block, loading its pack on first use.
    public func creature(_ key: String) -> Creature? {
        guard let entry = entriesByKey[key] else { return nil }
        lock.lock()
        defer { lock.unlock() }
        if packs[entry.packFile] == nil {
            packs[entry.packFile] = loadPack(entry.packFile)
        }
        return packs[entry.packFile]?[key]
    }

    public func condition(_ slug: String) -> ConditionDefinition? {
        conditions.first { $0.slug == slug }
    }

    /// A file inside `Generated`, such as a creature's art.
    public func url(for relativePath: String) -> URL? {
        relativePath.isEmpty ? nil : directory.appendingPathComponent(relativePath)
    }

    private func loadPack(_ name: String) -> [String: Creature] {
        let url = directory.appendingPathComponent("Bestiary/packs/\(name).json")
        guard let data = try? Data(contentsOf: url),
              let creatures = try? JSONDecoder().decode([Creature].self, from: data) else { return [:] }
        return Dictionary(creatures.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
    }
}
