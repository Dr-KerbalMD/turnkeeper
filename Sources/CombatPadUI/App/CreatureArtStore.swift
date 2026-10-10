import ArtExtraction
import CombatPadKit
import CoreGraphics
import Foundation

/// A PDF in the art library, as the settings show it.
struct ArtSourceSummary: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    /// Where it is: "Kept in Combat Pad", or the file's path.
    let place: String
    let isMissing: Bool
    /// How many pieces of art the library has from it.
    let artCount: Int
}

/// What the art library holds, for matching creatures and for the settings.
struct ArtCatalog: Sendable {
    var art: [LibraryArt] = []
    var sources: [ArtSourceSummary] = []
    /// The folders whose new PDFs are added, such as Scrollkeeper's downloads.
    var watchedFolders: [String] = []

    var missingSources: [ArtSourceSummary] { sources.filter(\.isMissing) }
}

/// What adding PDFs did, for a status message.
struct ArtImportSummary: Sendable {
    var pdfs = 0
    var added = 0
    var failures: [String] = []

    var message: String {
        var text = pdfs == 0 ? "No new PDFs of creature art." : "Read \(pdfs) PDF\(pdfs == 1 ? "" : "s"): \(added) "
            + "new pieces of creature art."
        if !failures.isEmpty { text += " Could not read: \(failures.joined(separator: "; "))." }
        return text
    }
}

/// The creature art from the user's own Paizo PDFs (R2.3), kept by Tabletop Kit's art library in Application
/// Support. Reading PDFs and drawing art take a while, so they happen here, off the main thread.
actor CreatureArtStore {
    /// Products whose art is the remastered art.
    static let remasteredProducts = ["Monster Core", "NPC Core", "Alien Core", "Howl of the Wild", "Rage of Elements"]

    private let library: ArtLibrary
    private let pictures = NSCache<NSString, CGImage>()

    init(folder: URL) throws {
        library = try ArtLibrary(folder: folder)
    }

    /// The store in `Application Support/Combat Pad/Creature Art`, apart from pasted art's `Art` folder, whose
    /// unused files are swept at launch.
    static func standard() throws -> CreatureArtStore {
        try CreatureArtStore(folder: URL.applicationSupportDirectory.appendingPathComponent("Combat Pad/Creature Art"))
    }

    /// What the library holds now, each PDF checked again for whether it is still there.
    func catalog() -> ArtCatalog {
        library.refreshStatuses()
        let sourcesByID = Dictionary(uniqueKeysWithValues: library.sources.map { ($0.id, $0) })
        let art = library.entries.map { entry in
            let titles = Set(entry.prints.compactMap { sourcesByID[$0.sourceID]?.title }).sorted()
            let game: Game = entry.game == .starfinder ? .starfinder : .pathfinder
            return LibraryArt(id: entry.id, name: entry.name, game: game,
                              isRemastered: titles.contains { title in
                                  Self.remasteredProducts.contains { title.localizedCaseInsensitiveContains($0) }
                              },
                              isToken: entry.prints.first?.kind == .token,
                              isAvailable: library.isAvailable(entry), sourceTitles: titles)
        }
        let sources = library.sources.map { source in
            ArtSourceSummary(id: source.id, title: source.title, place: Self.place(of: source),
                             isMissing: library.status(of: source) == .missing,
                             artCount: library.entries(from: source).count)
        }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        return ArtCatalog(art: art, sources: sources, watchedFolders: library.watchedFolders.map(\.path))
    }

    /// Watches `folder` (Scrollkeeper's downloads) and adds its PDFs of art by reference.
    func importFolder(_ folder: URL, progress: @Sendable (String) -> Void) -> ArtImportSummary {
        let accessing = folder.startAccessingSecurityScopedResource()
        defer { if accessing { folder.stopAccessingSecurityScopedResource() } }
        do {
            try library.watch(folder)
        } catch {
            return ArtImportSummary(failures: [error.localizedDescription])
        }
        return addNewFiles(progress: progress)
    }

    /// Adds the PDFs that have appeared in the watched folders since they were last read.
    func addNewFiles(progress: @Sendable (String) -> Void = { _ in }) -> ArtImportSummary {
        var summary = ArtImportSummary()
        for result in library.addNewFiles(progress: progress) {
            summary.pdfs += 1
            switch result {
            case .success(let report): summary.added += report.added
            case .failure(let error): summary.failures.append(error.localizedDescription)
            }
        }
        return summary
    }

    /// Adds PDFs the user chose, keeping copies of them.
    func addFiles(_ files: [URL], progress: @Sendable (String) -> Void) -> ArtImportSummary {
        var summary = ArtImportSummary()
        for file in files {
            progress(file.lastPathComponent)
            let accessing = file.startAccessingSecurityScopedResource()
            defer { if accessing { file.stopAccessingSecurityScopedResource() } }
            do {
                let report = try library.add(file, keeping: true)
                if !report.wasImported { summary.pdfs += 1 }
                summary.added += report.added
            } catch {
                summary.failures.append("\(file.lastPathComponent): \(error.localizedDescription)")
            }
        }
        return summary
    }

    /// Takes a PDF and the art only it prints out of the library.
    func removeSource(id: String) throws {
        guard let source = library.source(id: id) else { return }
        try library.remove(source)
        pictures.removeAllObjects()
    }

    func unwatch(_ path: String) throws {
        for folder in library.watchedFolders where folder.path == path { try library.unwatch(folder) }
    }

    /// A piece of art drawn alone and upright, at most `maxPixels` on its long side; nil when it can't be drawn.
    func picture(id: UUID, maxPixels: Int) -> CGImage? {
        let key = "\(id.uuidString)#\(maxPixels)" as NSString
        if let cached = pictures.object(forKey: key) { return cached }
        guard let entry = library.entries.first(where: { $0.id == id }),
              let image = library.picture(of: entry, maxPixels: maxPixels) else { return nil }
        pictures.setObject(image, forKey: key)
        return image
    }

    private static func place(of source: ArtSource) -> String {
        switch source.location {
        case .kept: "Kept in Combat Pad"
        case .referenced(let reference): reference.path
        case .inFolder(let folder, let relativePath): (folder.path as NSString).appendingPathComponent(relativePath)
        }
    }
}
