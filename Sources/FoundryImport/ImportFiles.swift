import CombatPadKit
import Foundation

struct ImportedBestiary {
    var creatures: [Creature]
    var conditions: [ConditionDefinition]
    var glossary: [GlossaryEntry]
    var glossaryIndex: GlossaryIndex
}

/// Writes the bestiary files. Keys are sorted and arrays ordered, so the same input gives the same bytes.
struct BestiaryWriter {
    var outputDirectory: URL

    private var bestiaryDirectory: URL { outputDirectory.appendingPathComponent("Bestiary") }

    func write(_ bestiary: ImportedBestiary, revision: String) throws {
        let creatures = bestiary.creatures
        let packsDirectory = bestiaryDirectory.appendingPathComponent("packs")
        try? FileManager.default.removeItem(at: packsDirectory)
        try FileManager.default.createDirectory(at: packsDirectory, withIntermediateDirectories: true)
        let index = BestiaryIndex(sourceRevision: revision, entries: creatures.map(BestiaryIndexEntry.init))
        try encode(index, to: bestiaryDirectory.appendingPathComponent("index.json"))
        try encode(bestiary.conditions, to: bestiaryDirectory.appendingPathComponent("conditions.json"))
        try encode(bestiary.glossary, to: bestiaryDirectory.appendingPathComponent("glossary.json"))
        try encode(bestiary.glossaryIndex, to: bestiaryDirectory.appendingPathComponent("glossary-index.json"))
        let byPack = Dictionary(grouping: creatures) { BestiaryIndexEntry(creature: $0).packFile }
        for (pack, members) in byPack {
            try encode(members, to: packsDirectory.appendingPathComponent("\(pack).json"))
        }
    }

    func writeReport(_ markdown: String) throws {
        let url = outputDirectory.appendingPathComponent("import-report.md")
        try markdown.write(to: url, atomically: true, encoding: .utf8)
    }

    private func encode<Value: Encodable>(_ value: Value, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(value).write(to: url, options: .atomic)
    }
}
