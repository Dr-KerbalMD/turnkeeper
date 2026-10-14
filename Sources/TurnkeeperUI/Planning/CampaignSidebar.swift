import AppNotices
import Bestiary
import TurnkeeperKit
import SwiftUI
import UniformTypeIdentifiers

/// The list of campaigns, with adding, deleting, importing and exporting.
struct CampaignSidebar: View {
    @Environment(AppModel.self) private var model
    @State private var isAdding = false
    @State private var isImporting = false
    @State private var isSyncing = false
    @State private var isShowingDemiplane = false
    @State private var isShowingCreatureArt = false
    @State private var isShowingAbout = false
    @State private var exportDocument: LibraryDocument?
    @State private var renaming: Campaign?

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
            ToolbarItem { Button("Demiplane", systemImage: "person.badge.key") { isShowingDemiplane = true } }
            ToolbarItem {
                Button("Creature Art", systemImage: "photo.on.rectangle.angled") { isShowingCreatureArt = true }
                    .badge(model.artCatalog.missingSources.count)
            }
            // The Mac has About in the app menu.
            #if os(iOS)
            ToolbarItem { Button("About", systemImage: "info.circle") { isShowingAbout = true } }
            #endif
        }
        .sheet(isPresented: $isAdding) { CampaignSheet(campaign: nil) }
        .sheet(item: $renaming) { campaign in CampaignSheet(campaign: campaign) }
        .sheet(isPresented: $isSyncing) { NearbySyncSheet() }
        .sheet(isPresented: $isShowingDemiplane) { DemiplaneSettingsView() }
        .sheet(isPresented: $isShowingCreatureArt) { CreatureArtView() }
        .sheet(isPresented: $isShowingAbout) { AboutSheet(info: .turnkeeper) }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.turnkeeperLibrary, .json]) { result in
            if case let .success(url) = result { model.importLibraryFile(url) }
        }
        .fileExporter(isPresented: exportBinding, document: exportDocument, contentType: .turnkeeperLibrary,
                      defaultFilename: exportDocument?.fileName) { _ in exportDocument = nil }
        .onChange(of: model.selectedCampaignID) { model.selection = nil }
    }

    @ViewBuilder
    private func menu(for campaign: Campaign) -> some View {
        Button("Rename…", systemImage: "pencil") { renaming = campaign }
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

/// Asks for a campaign's name and game, for a new campaign or to rename one.
private struct CampaignSheet: View {
    /// The campaign being renamed, or nil to add one.
    let campaign: Campaign?
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var game = Game.pathfinder

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name, prompt: Text("PFS Season 7"))
                    .nameEntry()
                Picker("Game", selection: $game) {
                    Text("Pathfinder").tag(Game.pathfinder)
                    Text("Starfinder").tag(Game.starfinder)
                }
                .pickerStyle(.segmented)
            }
            .formStyle(.grouped)
            .navigationTitle(campaign == nil ? "New Campaign" : "Rename Campaign")
            .onAppear {
                name = campaign?.name ?? ""
                game = campaign?.game ?? .pathfinder
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(campaign == nil ? "Add" : "Save", action: save)
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
        .frame(minWidth: 360, minHeight: 200)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    private func save() {
        if var campaign {
            campaign.name = trimmedName
            campaign.game = game
            model.library.save(campaign)
        } else {
            model.addCampaign(name: trimmedName, game: game)
        }
        dismiss()
    }
}

/// A `.turnkeeper` file for the exporter.
struct LibraryDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.turnkeeperLibrary]
    var data: Data
    var fileName: String

    init(data: Data, fileName: String) {
        self.data = data
        self.fileName = fileName
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
        fileName = configuration.file.filename ?? "Turnkeeper.turnkeeper"
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
