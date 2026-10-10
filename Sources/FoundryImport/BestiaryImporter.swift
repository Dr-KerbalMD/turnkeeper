import CombatPadKit
import Foundation

/// Where the import reads from and writes to.
public struct ImportConfiguration: Sendable {
    /// The pf2e system repository, such as `~/git/pf2e`.
    public var repository: URL
    /// The `Generated` folder.
    public var outputDirectory: URL
    /// Where the optional `art-overrides.json` lives.
    public var configurationDirectory: URL

    public init(repository: URL, outputDirectory: URL, configurationDirectory: URL) {
        self.repository = repository
        self.outputDirectory = outputDirectory
        self.configurationDirectory = configurationDirectory
    }
}

/// Runs the whole import: creatures, conditions, the glossary and the output files. Art is matched on the device,
/// from the user's own PDFs; the import only passes on `art-overrides.json`.
public struct BestiaryImporter {
    public var configuration: ImportConfiguration

    public init(configuration: ImportConfiguration) {
        self.configuration = configuration
    }

    public func run() throws -> ImportReport {
        let languages = configuration.repository.appendingPathComponent("static/lang")
        let localizer = try Localizer(languageDirectory: languages)
        let scanner = PackScanner(repository: configuration.repository)
        let links = LinkResolver(
            compendium: try CompendiumIndex(scanner: scanner),
            traits: TraitGlossary(repository: configuration.repository, localizer: localizer)
        )
        var glossaryIndex = try PlayerCompendium.link(scanner: scanner, links: links)
        var text = RulesTextConverter(localizer: localizer, links: links)
        var report = ImportReport()
        let creatures = try readCreatures(scanner: scanner, text: &text, report: &report)
        let conditions = try ConditionImporter.conditions(scanner: scanner, text: &text)
        var glossaryParser = GlossaryEntryParser(text: text)
        let glossary = GlossaryBuilder.entries(parser: &glossaryParser)
        report.glossaryCount = glossary.count
        PlayerCompendium.addTraits(of: glossary, to: &glossaryIndex)
        report.glossaryNameCount = glossaryIndex.count
        let unparsed = glossaryParser.text.unparsedEnrichers
        report.unparsedEnrichers = Dictionary(unparsed.map { ($0, 1) }, uniquingKeysWith: +)
        let writer = BestiaryWriter(outputDirectory: configuration.outputDirectory)
        let bestiary = ImportedBestiary(
            creatures: creatures, conditions: conditions, glossary: glossary, glossaryIndex: glossaryIndex
        )
        try writer.write(bestiary, revision: revision())
        try copyArtOverrides()
        try writer.writeReport(report.markdown(creatures: creatures))
        return report
    }

    private func readCreatures(
        scanner: PackScanner, text: inout RulesTextConverter, report: inout ImportReport
    ) throws -> [Creature] {
        var parser = CreatureParser(text: text)
        var creatures: [Creature] = []
        for pack in try scanner.actorPacks() {
            for file in scanner.documentFiles(in: pack) {
                let document = try JSONValue(contentsOf: file)
                if let creature = parser.creature(from: document, game: pack.game, pack: pack.name) {
                    creatures.append(creature)
                }
            }
        }
        text = parser.text
        report.creatureCount = creatures.count
        return creatures.sorted { $0.key < $1.key }
    }

    /// Creature names whose art has another name in the PDFs, for matching art on the device.
    private func copyArtOverrides() throws {
        let overrides = configuration.configurationDirectory.appendingPathComponent("art-overrides.json")
        let destination = configuration.outputDirectory.appendingPathComponent("Bestiary/art-overrides.json")
        try? FileManager.default.removeItem(at: destination)
        guard FileManager.default.fileExists(atPath: overrides.path) else { return }
        try FileManager.default.copyItem(at: overrides, to: destination)
    }

    private func revision() -> String {
        let head = configuration.repository.appendingPathComponent(".git/HEAD")
        let contents = try? String(contentsOf: head, encoding: .utf8)
        guard let reference = contents?.trimmingCharacters(in: .whitespacesAndNewlines) else { return "" }
        guard reference.hasPrefix("ref: ") else { return reference }
        let refFile = configuration.repository.appendingPathComponent(".git/" + reference.dropFirst(5))
        let commit = try? String(contentsOf: refFile, encoding: .utf8)
        return commit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
