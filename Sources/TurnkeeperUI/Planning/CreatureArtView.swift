import Bestiary
import CreatureArt
import SwiftUI
import UniformTypeIdentifiers

/// Where creature art comes from (R2.3): the user's own Paizo PDFs, used where Scrollkeeper keeps them or copied
/// in, with the ones that have gone missing.
struct CreatureArtView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    // One file importer serves both buttons: SwiftUI presents only one of several on the same view.
    @State private var isChoosing = false
    @State private var choice = ArtChoice.pdfs

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Creature art comes from your own Paizo pawn, token and Battle Cards PDFs. Turnkeeper "
                         + "uses the ones Scrollkeeper downloads where they are, without copying them.")
                        .font(.callout).foregroundStyle(.secondary)
                    importButtons
                    if let progress = model.artProgress {
                        HStack { ProgressView().controlSize(.small); Text(progress).font(.callout) }
                    }
                }
                if !model.artCatalog.missingSources.isEmpty { missingSection }
                if !model.artCatalog.watchedFolders.isEmpty { foldersSection }
                pdfsSection
            }
            .formStyle(.grouped)
            .navigationTitle("Creature Art")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .fileImporter(isPresented: $isChoosing, allowedContentTypes: choice.contentTypes,
                          allowsMultipleSelection: choice == .pdfs) { result in
                if case .success(let urls) = result { chose(urls) }
            }
            .task { await model.refreshCreatureArt() }
        }
        .frame(minWidth: 520, minHeight: 560)
    }

    private var importButtons: some View {
        HStack {
            Button("Import from Scrollkeeper…", systemImage: "books.vertical", action: importFromScrollkeeper)
            Button("Add PDFs…", systemImage: "doc.badge.plus") { choose(.pdfs) }
            Spacer()
            Button("Check Again", systemImage: "arrow.clockwise") {
                Task { await model.refreshCreatureArt(addingNew: true) }
            }
        }
        // In a form row, every button fires on a tap anywhere in the row: Add PDFs… then set the picker to
        // PDFs, so Scrollkeeper's folder couldn't be opened. Borderless buttons take only their own taps.
        .buttonStyle(.borderless)
        .disabled(model.artProgress != nil)
    }

    /// On the Mac, Scrollkeeper's folder is used straight away when it's there; on the iPad, the user picks it
    /// in Files (On My iPad ▸ Scrollkeeper).
    private func importFromScrollkeeper() {
        #if os(macOS)
        let folder = URL.applicationSupportDirectory.appendingPathComponent("Scrollkeeper/Files", isDirectory: true)
        if FileManager.default.fileExists(atPath: folder.path) {
            Task { await model.importCreatureArt(fromFolder: folder) }
            return
        }
        #endif
        choose(.folder)
    }

    private func choose(_ choice: ArtChoice) {
        self.choice = choice
        isChoosing = true
    }

    private func chose(_ urls: [URL]) {
        switch choice {
        case .folder:
            guard let folder = urls.first else { return }
            Task { await model.importCreatureArt(fromFolder: folder) }
        case .pdfs:
            Task { await model.addCreatureArt(files: urls) }
        }
    }

    private var missingSection: some View {
        Section {
            ForEach(model.artCatalog.missingSources) { source in
                SourceRow(source: source)
            }
        } header: {
            Label("Missing PDFs", systemImage: "exclamationmark.triangle")
        } footer: {
            Text("These PDFs were deleted or moved, so their art can't be shown. Download them again in Scrollkeeper "
                 + "and choose Check Again, or remove them.")
        }
    }

    private var foldersSection: some View {
        Section("Watched folders") {
            ForEach(model.artCatalog.watchedFolders, id: \.self) { folder in
                HStack {
                    Text(folder).font(.callout).lineLimit(2).truncationMode(.middle)
                    Spacer()
                    Button("Stop Watching") { Task { await model.stopWatching(folder) } }
                }
            }
        }
    }

    private var pdfsSection: some View {
        Section("PDFs") {
            if model.artCatalog.sources.isEmpty {
                Text("No PDFs yet.").foregroundStyle(.secondary)
            }
            ForEach(model.artCatalog.sources.filter { !$0.isMissing }) { source in
                SourceRow(source: source)
            }
        }
    }
}

/// What the file importer is choosing: Scrollkeeper's folder, or PDFs to keep copies of.
private enum ArtChoice {
    case folder, pdfs

    var contentTypes: [UTType] { self == .folder ? [.folder] : [.pdf] }
}

/// A PDF of creature art, with how much art it gives, and a way to remove it.
private struct SourceRow: View {
    let source: ArtSourceSummary
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(source.title)
                Text(source.place).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Text("\(source.artCount) art").font(.caption).foregroundStyle(.secondary)
            Button("Remove", systemImage: "trash", role: .destructive) {
                Task { await model.removeArtSource(id: source.id) }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
        }
    }
}
