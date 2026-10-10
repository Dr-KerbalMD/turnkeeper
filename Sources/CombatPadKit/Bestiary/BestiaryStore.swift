import Foundation

/// The bundled bestiary: the index for browsing, with full stat blocks loaded a pack at a time.
public final class BestiaryStore: @unchecked Sendable {
    public let directory: URL
    public let index: BestiaryIndex
    public let conditions: [ConditionDefinition]
    /// Whether the import wrote a glossary, so cards can link to it.
    public let hasGlossary: Bool
    /// Creature name → the name its art has in the PDFs, from `art-overrides.json`.
    public let artOverrides: [String: String]
    private let entriesByKey: [String: BestiaryIndexEntry]
    private var packs: [String: [String: Creature]] = [:]
    private var glossary: [String: GlossaryEntry]?
    private var glossaryIndex: GlossaryIndex?
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
        hasGlossary = FileManager.default.fileExists(atPath: bestiary.appendingPathComponent("glossary.json").path)
        let overrides = try? Data(contentsOf: bestiary.appendingPathComponent("art-overrides.json"))
        artOverrides = overrides.flatMap { try? JSONDecoder().decode([String: String].self, from: $0) } ?? [:]
    }

    /// An empty bestiary, for previews and when nothing has been imported.
    public init() {
        directory = URL(fileURLWithPath: "/")
        index = BestiaryIndex(sourceRevision: "", entries: [])
        conditions = []
        entriesByKey = [:]
        hasGlossary = false
        artOverrides = [:]
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

    /// A linked spell, item, condition or trait, loading `Bestiary/glossary.json` on first use.
    public func glossaryEntry(_ id: String) -> GlossaryEntry? {
        lock.lock()
        defer { lock.unlock() }
        if glossary == nil { glossary = loadGlossary() }
        return glossary?[id]
    }

    /// The glossary ID for a player character's spell, ability, item or trait, by name, loading
    /// `Bestiary/glossary-index.json` on first use.
    public func glossaryID(game: Game, kind: GlossaryIndex.Kind, name: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        if glossaryIndex == nil { glossaryIndex = loadGlossaryIndex() }
        return glossaryIndex?.id(game: game, kind: kind, name: name)
    }

    public func condition(_ slug: String) -> ConditionDefinition? {
        conditions.first { $0.slug == slug }
    }

    /// A file inside `Generated`, such as a creature's art.
    public func url(for relativePath: String) -> URL? {
        relativePath.isEmpty ? nil : directory.appendingPathComponent(relativePath)
    }

    private func loadGlossary() -> [String: GlossaryEntry] {
        let url = directory.appendingPathComponent("Bestiary/glossary.json")
        guard let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([GlossaryEntry].self, from: data) else { return [:] }
        return Dictionary(entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private func loadGlossaryIndex() -> GlossaryIndex {
        let url = directory.appendingPathComponent("Bestiary/glossary-index.json")
        guard let data = try? Data(contentsOf: url) else { return GlossaryIndex() }
        return (try? JSONDecoder().decode(GlossaryIndex.self, from: data)) ?? GlossaryIndex()
    }

    private func loadPack(_ name: String) -> [String: Creature] {
        let url = directory.appendingPathComponent("Bestiary/packs/\(name).json")
        guard let data = try? Data(contentsOf: url),
              let creatures = try? JSONDecoder().decode([Creature].self, from: data) else { return [:] }
        return Dictionary(creatures.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
    }
}
