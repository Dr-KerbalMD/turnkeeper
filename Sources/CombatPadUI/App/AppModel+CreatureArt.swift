import CombatPadKit
import CoreGraphics
import Foundation

/// Creature art from the user's own PDFs (R2.3): reading them into the art library, matching it to creatures, and
/// drawing it.
extension AppModel {
    /// Reads what the art library holds and matches it to creatures again; with `addingNew`, first adds the PDFs
    /// that have appeared in the watched folders, as at launch.
    func refreshCreatureArt(addingNew: Bool = false) async {
        guard let creatureArt else { return }
        if addingNew {
            artProgress = "Looking for new PDFs…"
            let summary = await creatureArt.addNewFiles(progress: progressReporter())
            if summary.pdfs > 0 { statusMessage = summary.message }
        }
        let catalog = await creatureArt.catalog()
        artCatalog = catalog
        artMatcher = LibraryArtMatcher(art: catalog.art, overrides: bestiary.artOverrides)
        artProgress = nil
    }

    /// Watches Scrollkeeper's download folder and uses the PDFs of creature art in it, where they are.
    func importCreatureArt(fromFolder folder: URL) async {
        guard let creatureArt else { return }
        artProgress = "Reading Scrollkeeper's PDFs…"
        let summary = await creatureArt.importFolder(folder, progress: progressReporter())
        statusMessage = summary.message
        await refreshCreatureArt()
    }

    /// Keeps copies of PDFs the user chose and uses their creature art.
    func addCreatureArt(files: [URL]) async {
        guard let creatureArt else { return }
        artProgress = "Reading PDFs…"
        let summary = await creatureArt.addFiles(files, progress: progressReporter())
        statusMessage = summary.message
        await refreshCreatureArt()
    }

    func removeArtSource(id: String) async {
        do {
            try await creatureArt?.removeSource(id: id)
        } catch {
            errorMessage = error.localizedDescription
        }
        await refreshCreatureArt()
    }

    func stopWatching(_ folder: String) async {
        do {
            try await creatureArt?.unwatch(folder)
        } catch {
            errorMessage = error.localizedDescription
        }
        await refreshCreatureArt()
    }

    /// The art the library has for a bestiary creature.
    func matchedArt(for entry: BestiaryIndexEntry) -> MatchedArt {
        artMatcher.art(forCreatureNamed: entry.name, game: entry.game, isRemastered: entry.source.isRemastered)
    }

    /// The creature with its art from the library, when it has no other art.
    func withLibraryArt(_ entry: BestiaryIndexEntry) -> BestiaryIndexEntry {
        let match = matchedArt(for: entry)
        guard let portrait = match.portrait else { return entry }
        var entry = entry
        let prefix = LibraryArtMatcher.pathPrefix
        entry.art = ArtReference(portrait: prefix + portrait.uuidString,
                                 token: prefix + (match.token ?? portrait).uuidString)
        return entry
    }

    /// The PDFs a creature's art needs that have gone missing; empty when it has art or never had any.
    func missingArtSources(for key: String) -> [String] {
        guard library.customArt(for: key) == nil, let entry = bestiary.entry(key) else { return [] }
        return matchedArt(for: entry).missingSources
    }

    /// The picture behind an art path, at most `maxPixels` on its long side (0 for full size): drawn from the art
    /// library for `library:` paths, else read from its file.
    func artPicture(for path: String, maxPixels: Int) async -> CGImage? {
        let prefix = LibraryArtMatcher.pathPrefix
        if path.hasPrefix(prefix) {
            guard let id = UUID(uuidString: String(path.dropFirst(prefix.count))) else { return nil }
            return await creatureArt?.picture(id: id, maxPixels: maxPixels > 0 ? maxPixels : Self.fullArtPixels)
        }
        guard let url = artURL(for: path) else { return nil }
        return await ArtLoader.shared.image(at: url, maxPixels: maxPixels)
    }

    /// Art drawn "full size" from a PDF is drawn this large on its long side.
    static let fullArtPixels = 1600

    /// Shows each file's name as it is read.
    private func progressReporter() -> @Sendable (String) -> Void {
        { name in Task { @MainActor in self.artProgress = "Reading \(name)…" } }
    }
}
