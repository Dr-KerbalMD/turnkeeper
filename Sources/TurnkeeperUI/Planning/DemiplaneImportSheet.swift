import CharacterImport
import TurnkeeperKit
import CoreGraphics
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Adds a shared character from Demiplane, or links a quick PC to one: by the sheet's link or ID, a pasted
/// image of the sheet's QR code, or (on iPad) scanning the code.
struct DemiplaneImportSheet: View {
    let partyID: UUID
    /// The quick PC being linked; nil to add new members.
    var memberID: UUID?
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var isScanning = false
    /// Why the last import failed, shown here: an alert on the window would wait until this sheet closes.
    @State private var importError: String?

    private var reference: DemiplaneReference? { DemiplaneReference.parse(text) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Character link or ID", text: $text, axis: .vertical)
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
        ToolbarItem(placement: .confirmationAction) {
            Button("Import") { Task { await importReference() } }
                .disabled(reference == nil || model.demiplaneProgress != nil)
        }
    }

    private var footer: String {
        reference == nil
            ? "Paste the link from the character sheet's address bar or QR code. The player must share the "
                + "character by link on Demiplane."
            : "A character. Importing has Demiplane export its sheet and reads it."
    }

    private func importReference() async {
        guard let reference else { return }
        importError = nil
        if await model.importFromDemiplane(reference, partyID: partyID, memberID: memberID) {
            dismiss()
        } else {
            showFailure()
        }
    }

    /// Moves the model's error into this sheet, so it shows now and not again once the sheet closes.
    private func showFailure() {
        importError = model.errorMessage
        model.errorMessage = nil
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
