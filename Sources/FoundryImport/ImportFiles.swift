import CombatPadKit
import Foundation

/// `art-sources.json` and the optional `art-overrides.json`.
struct ArtSources {
    var modulePriority: [String]
    /// Creature name → the name its art has in a PDF, for names that differ.
    var overrides: [String: String]

    init(directory: URL) throws {
        let sources = try JSONValue(contentsOf: directory.appendingPathComponent("art-sources.json"))
        modulePriority = sources["foundryModulePriority"].strings
        let overridesURL = directory.appendingPathComponent("art-overrides.json")
        let overridesFile = (try? JSONValue(contentsOf: overridesURL)) ?? .null
        overrides = overridesFile.object.compactMapValues { $0.string.isEmpty ? nil : $0.string }
    }
}

/// Reads `Generated/PdfArt/pdf-art-index.json`, written by `scripts/extract_pdf_art.py`.
enum PdfArtIndex {
    private struct File: Decodable {
        var entries: [PdfArtEntry]
    }

    static func entries(in outputDirectory: URL) throws -> [PdfArtEntry] {
        let url = outputDirectory.appendingPathComponent("PdfArt/pdf-art-index.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode(File.self, from: Data(contentsOf: url)).entries
    }
}

/// Copies Foundry module art into `Generated/Art`, skipping files already copied.
struct ArtCopier {
    var mapper: FoundryArtMapper
    var outputDirectory: URL

    private var artDirectory: URL { outputDirectory.appendingPathComponent("Art") }

    /// Copies a creature's art and returns its paths relative to `Generated`.
    func copy(_ art: FoundryArt) throws -> ArtReference {
        ArtReference(portrait: try copyFile(art.portrait), token: try copyFile(art.token))
    }

    private func copyFile(_ dataPath: String) throws -> String {
        let source = mapper.dataURL(dataPath)
        guard !dataPath.isEmpty, FileManager.default.fileExists(atPath: source.path) else { return "" }
        let relative = "Art/" + (source.path.components(separatedBy: "/modules/").last ?? source.lastPathComponent)
        let destination = outputDirectory.appendingPathComponent(relative)
        if !isSameSize(source, destination) {
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: source, to: destination)
        }
        return relative
    }

    private func isSameSize(_ first: URL, _ second: URL) -> Bool {
        let manager = FileManager.default
        guard let firstSize = try? manager.attributesOfItem(atPath: first.path)[.size] as? Int,
              let secondSize = try? manager.attributesOfItem(atPath: second.path)[.size] as? Int else { return false }
        return firstSize == secondSize
    }

    /// Deletes copied art no creature uses any more, such as after a module drops an image.
    func removeUnreferenced(keeping referenced: Set<String>) throws {
        let files = FileManager.default.enumerator(at: artDirectory, includingPropertiesForKeys: nil)
        guard let files else { return }
        let prefix = outputDirectory.standardizedFileURL.path + "/"
        for case let file as URL in files where !file.hasDirectoryPath {
            let relative = file.standardizedFileURL.path.replacingOccurrences(of: prefix, with: "")
            if !referenced.contains(relative) { try FileManager.default.removeItem(at: file) }
        }
    }
}

/// Writes the bestiary files. Keys are sorted and arrays ordered, so the same input gives the same bytes.
struct BestiaryWriter {
    var outputDirectory: URL

    private var bestiaryDirectory: URL { outputDirectory.appendingPathComponent("Bestiary") }

    func write(creatures: [Creature], conditions: [ConditionDefinition], revision: String) throws {
        let packsDirectory = bestiaryDirectory.appendingPathComponent("packs")
        try? FileManager.default.removeItem(at: packsDirectory)
        try FileManager.default.createDirectory(at: packsDirectory, withIntermediateDirectories: true)
        let index = BestiaryIndex(sourceRevision: revision, entries: creatures.map(BestiaryIndexEntry.init))
        try encode(index, to: bestiaryDirectory.appendingPathComponent("index.json"))
        try encode(conditions, to: bestiaryDirectory.appendingPathComponent("conditions.json"))
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
