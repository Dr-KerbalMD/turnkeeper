import CharacterImport
import TurnkeeperKit
import CoreGraphics
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Adds a character or a whole campaign from Demiplane, or links a quick PC to a character: by the sheet's
/// link or ID, a campaign link, a pasted image of the sheet's QR code, or (on iPad) scanning the code.
struct DemiplaneImportSheet: View {
    let partyID: UUID
    /// The quick PC being linked; nil to add new members.
    var memberID: UUID?
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var isScanning = false
    @State private var isShowingSettings = false
    /// Why the last import failed, shown here: an alert on the window would wait until this sheet closes.
    @State private var importError: String?

    private var reference: DemiplaneReference? { DemiplaneReference.parse(text) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(memberID == nil ? "Character or campaign link, or character ID"
                                              : "Character link or ID", text: $text, axis: .vertical)
                        .lineLimit(1...3)
                        .autocorrectionDisabled()
                    HStack {
                        PasteButton(payloadType: String.self) { strings in text = strings.first ?? "" }
                        PasteButton(supportedContentTypes: [.image]) { providers in readQRCode(providers) }
                            .help("Paste a picture of the character sheet's QR code")
                        #if os(iOS)
                        if QRScannerView.isAvailable {
                            Button("Scan QR Code", systemImage: "qrcode.viewfinder") { isScanning = true }
                        }
                        #endif
                    }
                } footer: {
                    Text(footer)
                }
                if let progress = model.demiplaneProgress {
                    Section { ProgressView(progress) }
                }
                if let importError {
                    Section {
                        Label(importError, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(memberID == nil ? "Add from Demiplane" : "Link to Demiplane")
            .onChange(of: text) { importError = nil }
            .toolbar { toolbar }
            .onDrop(of: [.image], isTargeted: nil) { providers in
                readQRCode(providers)
                return true
            }
            .sheet(isPresented: $isShowingSettings) { DemiplaneSettingsView() }
            .sheet(item: campaignImport, onDismiss: { dismiss() }, content: CampaignImportSheet.init(pending:))
            #if os(iOS)
            .fullScreenCover(isPresented: $isScanning) {
                QRScannerView { payload in text = payload }
            }
            #endif
        }
        .frame(minWidth: 460, minHeight: 300)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem { Button("Demiplane Settings", systemImage: "gearshape") { isShowingSettings = true } }
        ToolbarItem(placement: .confirmationAction) {
            Button("Import") { Task { await importReference() } }
                .disabled(reference == nil || model.demiplaneProgress != nil)
        }
    }

    private var footer: String {
        switch reference {
        case .campaign: return "A campaign. Importing it needs you signed in to Demiplane."
        case .character: return "A character. Importing reads its exported character sheet."
        case nil: return "Paste the link from the character sheet's address bar or QR code, or a campaign's link."
        }
    }

    /// A character closes the sheet once imported; a campaign opens the list of its characters first.
    private func importReference() async {
        guard let reference else { return }
        importError = nil
        let isCampaign: Bool
        if case .campaign = reference { isCampaign = true } else { isCampaign = false }
        guard !isCampaign || memberID == nil else { return }
        if await model.importFromDemiplane(reference, partyID: partyID, memberID: memberID) {
            if !isCampaign { dismiss() }
        } else {
            showFailure()
        }
    }

    /// Moves the model's error into this sheet, so it shows now and not again once the sheet closes.
    private func showFailure() {
        importError = model.errorMessage
        model.errorMessage = nil
    }

    private var campaignImport: Binding<PendingCampaignImport?> {
        Binding { model.campaignImport } set: { model.campaignImport = $0 }
    }

    private func readQRCode(_ providers: [NSItemProvider]) {
        Task {
            guard let data = await ArtworkPasteboard.imageData(from: providers),
                  let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return }
            let payloads = (try? QRCodeReader.payloads(in: image)) ?? []
            if let payload = payloads.first(where: { DemiplaneReference.parse($0) != nil }) {
                text = payload
            } else {
                importError = "Reading the QR code failed: the image has no Demiplane QR code."
            }
        }
    }
}

/// Chooses which of a campaign's imported characters join the party.
struct CampaignImportSheet: View {
    let pending: PendingCampaignImport
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var chosen: Set<String> = []

    private var characters: [ImportedCharacter] { pending.result.characters }

    var body: some View {
        NavigationStack {
            List {
                Section("Characters") {
                    ForEach(characters, id: \.link.characterID) { character in
                        Toggle(isOn: binding(character.link.characterID)) {
                            Text(character.sheet.name)
                            Text("Level \(character.sheet.level) \(character.sheet.player?.className ?? "")")
                        }
                    }
                }
                if !pending.result.failures.isEmpty {
                    Section("Not imported") {
                        ForEach(pending.result.failures, id: \.characterID) { Text($0.message) }
                    }
                }
            }
            .navigationTitle(pending.result.name.isEmpty ? "Campaign" : pending.result.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add \(chosen.count)") { Task { await add() } }.disabled(chosen.isEmpty)
                }
            }
            .onAppear { chosen = Set(characters.map(\.link.characterID)) }
        }
        .frame(minWidth: 420, minHeight: 360)
    }

    private func binding(_ id: String) -> Binding<Bool> {
        Binding { chosen.contains(id) } set: { isOn in
            if isOn { chosen.insert(id) } else { chosen.remove(id) }
        }
    }

    private func add() async {
        await model.add(characters.filter { chosen.contains($0.link.characterID) }, to: pending.partyID)
        dismiss()
    }
}
