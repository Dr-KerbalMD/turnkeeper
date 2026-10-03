import CombatPadKit
import SwiftUI
import UniformTypeIdentifiers

/// The list of campaigns, with adding, deleting, importing and exporting.
struct CampaignSidebar: View {
    @Environment(AppModel.self) private var model
    @State private var isAdding = false
    @State private var isImporting = false
    @State private var isSyncing = false
    @State private var exportDocument: LibraryDocument?

    var body: some View {
        @Bindable var model = model
        List(selection: $model.selectedCampaignID) {
            ForEach(model.library.activeCampaigns) { campaign in
                Label(campaign.name, systemImage: campaign.game == .starfinder ? "sparkles" : "shield")
                    .tag(campaign.id)
                    .contextMenu { menu(for: campaign) }
            }
        }
        .navigationTitle("Campaigns")
        .toolbar {
            ToolbarItem { Button("Add Campaign", systemImage: "plus") { isAdding = true } }
            ToolbarItem { Button("Import…", systemImage: "square.and.arrow.down") { isImporting = true } }
            ToolbarItem {
                Button("Sync with Nearby Device", systemImage: "arrow.triangle.2.circlepath") { isSyncing = true }
            }
        }
        .sheet(isPresented: $isAdding) { NewCampaignSheet() }
        .sheet(isPresented: $isSyncing) { NearbySyncSheet() }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.combatPadLibrary, .json]) { result in
            if case let .success(url) = result { model.importLibraryFile(url) }
        }
        .fileExporter(isPresented: exportBinding, document: exportDocument, contentType: .combatPadLibrary,
                      defaultFilename: exportDocument?.fileName) { _ in exportDocument = nil }
        .onChange(of: model.selectedCampaignID) { model.selection = nil }
    }

    @ViewBuilder
    private func menu(for campaign: Campaign) -> some View {
        Button("Export…", systemImage: "square.and.arrow.up") { export(campaign) }
        Button("Delete", systemImage: "trash", role: .destructive) { model.deleteCampaign(campaign.id) }
    }

    private func export(_ campaign: Campaign) {
        do {
            exportDocument = LibraryDocument(data: try model.exportCampaign(campaign.id),
                                             fileName: model.exportFileName(for: campaign.id))
        } catch {
            model.errorMessage = "Exporting \(campaign.name) failed: \(error.localizedDescription)"
        }
    }

    private var exportBinding: Binding<Bool> {
        Binding(get: { exportDocument != nil }, set: { if !$0 { exportDocument = nil } })
    }
}

/// Asks for a new campaign's name and game.
private struct NewCampaignSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var game = Game.pathfinder

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name, prompt: Text("PFS Season 7"))
                Picker("Game", selection: $game) {
                    Text("Pathfinder").tag(Game.pathfinder)
                    Text("Starfinder").tag(Game.starfinder)
                }
                .pickerStyle(.segmented)
            }
            .formStyle(.grouped)
            .navigationTitle("New Campaign")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        model.addCampaign(name: name.isEmpty ? "New campaign" : name, game: game)
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 360, minHeight: 200)
    }
}

/// A `.combatpad` file for the exporter.
struct LibraryDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.combatPadLibrary]
    var data: Data
    var fileName: String

    init(data: Data, fileName: String) {
        self.data = data
        self.fileName = fileName
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
        fileName = configuration.file.filename ?? "Combat Pad.combatpad"
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
