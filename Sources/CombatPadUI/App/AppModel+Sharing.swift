import CombatPadKit
import Foundation

/// `.combatpad` files in both directions.
extension AppModel {
    /// The campaign as a `.combatpad` package.
    func exportCampaign(_ id: UUID) throws -> Data {
        try LibraryPackage.campaign(id, from: library, bestiaryRevision: bestiary.index.sourceRevision).encoded()
    }

    /// The file name an export should use, such as "PFS Season 7.combatpad".
    func exportFileName(for id: UUID) -> String {
        let name = library.campaigns.first { $0.id == id }?.name ?? "Combat Pad"
        return name.replacingOccurrences(of: "/", with: "-") + ".combatpad"
    }

    /// Merges a `.combatpad` file into the library and reports what changed.
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
        var merged = library
        let summary = LibraryMerger.merge(package.library, into: &merged)
        library = merged
        if selectedCampaignID == nil { selectedCampaignID = library.activeCampaigns.first?.id }
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
