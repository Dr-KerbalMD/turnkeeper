import CombatPadKit
import Foundation

/// Where the import reads from and writes to.
public struct ImportConfiguration: Sendable {
    /// The pf2e system repository, such as `~/git/pf2e`.
    public var repository: URL
    /// The Foundry `Data/modules` folder holding the art modules.
    public var modulesDirectory: URL
    /// The `Generated` folder. PDF art is expected in its `PdfArt` subfolder.
    public var outputDirectory: URL
    /// `art-sources.json` and `art-overrides.json` live here.
    public var configurationDirectory: URL

    public init(repository: URL, modulesDirectory: URL, outputDirectory: URL, configurationDirectory: URL) {
        self.repository = repository
        self.modulesDirectory = modulesDirectory
        self.outputDirectory = outputDirectory
        self.configurationDirectory = configurationDirectory
    }
}

/// Runs the whole import: creatures, conditions, art, and the output files.
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
        var text = RulesTextConverter(localizer: localizer, links: links)
        var report = ImportReport()
        var creatures = try readCreatures(scanner: scanner, text: &text, report: &report)
        let conditions = try ConditionImporter.conditions(scanner: scanner, text: &text)
        var glossaryParser = GlossaryEntryParser(text: text)
        let glossary = GlossaryBuilder.entries(parser: &glossaryParser)
        report.glossaryCount = glossary.count
        try assignArt(to: &creatures, report: &report)
        let unparsed = glossaryParser.text.unparsedEnrichers
        report.unparsedEnrichers = Dictionary(unparsed.map { ($0, 1) }, uniquingKeysWith: +)
        let writer = BestiaryWriter(outputDirectory: configuration.outputDirectory)
        let bestiary = ImportedBestiary(creatures: creatures, conditions: conditions, glossary: glossary)
        try writer.write(bestiary, revision: revision())
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

    private func assignArt(to creatures: inout [Creature], report: inout ImportReport) throws {
        let sources = try ArtSources(directory: configuration.configurationDirectory)
        let mapper = FoundryArtMapper(
            modulesDirectory: configuration.modulesDirectory, priority: sources.modulePriority
        )
        let copier = ArtCopier(mapper: mapper, outputDirectory: configuration.outputDirectory)
        let foundryArt = mapper.art(knownKeys: Set(creatures.map(\.key)))
        let pdfEntries = try PdfArtIndex.entries(in: configuration.outputDirectory)
        let matcher = PdfArtMatcher(entries: pdfEntries, overrides: sources.overrides)
        var usedPdfArt = Set<String>()
        for index in creatures.indices {
            if let art = foundryArt[creatures[index].key] {
                creatures[index].art = try copier.copy(art)
            }
            let pdfArt = matcher.art(for: creatures[index])
            creatures[index].art = ArtChooser.combine(creatures[index].art, pdfArt: pdfArt)
            usedPdfArt.formUnion(pdfArt.values.map(\.path))
        }
        report.borrowedArt = ArtFallback.borrow(into: &creatures)
        try copier.removeUnreferenced(keeping: Set(creatures.flatMap { [$0.art.portrait, $0.art.token] }))
        report.unmatchedPdfArt = pdfEntries.filter { !usedPdfArt.contains($0.path) }.map(\.name)
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

/// Fills art gaps from PDF art. Foundry module art wins; PDF tokens and pawns cover the rest, and
/// card backs are only ever from PDFs.
enum ArtChooser {
    static func combine(_ art: ArtReference, pdfArt: [PdfArtEntry.Kind: PdfArtEntry]) -> ArtReference {
        let token = pdfArt[.token]?.path ?? pdfArt[.pawn]?.path ?? ""
        let portrait = pdfArt[.pawn]?.path ?? pdfArt[.token]?.path ?? ""
        return ArtReference(
            portrait: art.portrait.isEmpty ? portrait : art.portrait,
            token: art.token.isEmpty ? token : art.token,
            cardBack: pdfArt[.cardBack]?.path ?? ""
        )
    }
}
