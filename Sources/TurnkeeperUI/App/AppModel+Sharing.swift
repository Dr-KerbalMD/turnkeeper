import TurnkeeperKit
import Foundation

/// `.turnkeeper` files in both directions.
extension AppModel {
    /// The campaign as a `.turnkeeper` package.
    func exportCampaign(_ id: UUID) throws -> Data {
        try withImages(LibraryPackage.campaign(id, from: library, bestiaryRevision: bestiary.index.sourceRevision))
            .encoded()
    }

    /// The whole library for nearby sync, with its pasted images.
    func fullPackage() -> LibraryPackage {
        withImages(LibraryPackage(library: library, bestiaryRevision: bestiary.index.sourceRevision))
    }

    private func withImages(_ package: LibraryPackage) -> LibraryPackage {
        artStore.map(package.addingImages(from:)) ?? package
    }

    /// The file name an export should use, such as "PFS Season 7.turnkeeper".
    func exportFileName(for id: UUID) -> String {
        let name = library.campaigns.first { $0.id == id }?.name ?? "Turnkeeper"
        return name.replacingOccurrences(of: "/", with: "-") + ".turnkeeper"
    }

    /// Merges a `.turnkeeper` file into the library and reports what changed.
    func importLibraryFile(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            importPackage(try LibraryPackage.decode(Data(contentsOf: url)))
        } catch {
            errorMessage = "Importing \(url.lastPathComponent) failed: \(error.localizedDescription)"
        }
    }

    func importPackage(_ package: LibraryPackage) {
        do {
            if let artStore { try package.writeImages(to: artStore) }
        } catch {
            errorMessage = error.localizedDescription
        }
        var merged = library
        let summary = LibraryMerger.merge(package.library, into: &merged)
        library = merged
        if selectedCampaignID == nil { selectedCampaignID = library.activeCampaign(preferring: nil)?.id }
        statusMessage = describe(summary, package: package)
    }

    private func describe(_ summary: MergeSummary, package: LibraryPackage) -> String {
        guard summary.changedAnything else { return "Already up to date." }
        var parts = ["\(summary.added) added", "\(summary.updated) updated", "\(summary.deleted) deleted"]
        if summary.conflicts > 0 {
            parts.append("\(summary.conflicts) edited on both devices, kept as conflict copies")
        }
        var message = "Merged: " + parts.joined(separator: ", ") + "."
        if !package.bestiaryRevision.isEmpty && package.bestiaryRevision != bestiary.index.sourceRevision {
            message += " The other device has a different bestiary import; re-run the import on both to match."
        }
        return message
    }
}
