import CombatPadKit
import SwiftUI
import UniformTypeIdentifiers

/// Toolbar controls for a creature's pasted artwork: Paste (the system button, so iOS doesn't ask), and a
/// menu to choose an image file or go back to the bundled art.
struct ArtworkControls: ToolbarContent {
    let key: String
    @Environment(AppModel.self) private var model
    @State private var isChoosingFile = false

    var body: some ToolbarContent {
        ToolbarItem {
            PasteButton(supportedContentTypes: [.image]) { providers in
                model.setArtwork(from: providers, for: key)
            }
            .help("Use the copied image as this creature's art")
        }
        ToolbarItem {
            Menu("Artwork", systemImage: "photo") {
                Button("Choose Image…", systemImage: "folder") { isChoosingFile = true }
                if model.hasPastedArtwork(key) {
                    Button("Remove Pasted Artwork", systemImage: "trash", role: .destructive) {
                        model.removeArtwork(for: key)
                    }
                }
            }
            .fileImporter(isPresented: $isChoosingFile, allowedContentTypes: [.image]) { result in
                guard case .success(let url) = result else { return }
                Task { await choose(url) }
            }
        }
    }

    private func choose(_ url: URL) async {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }
        await model.setArtwork(data, for: key)
    }
}

extension View {
    /// Takes a dropped image, or on the Mac a pasted one (⌘V), as the creature's art.
    func acceptsArtwork(for key: String, model: AppModel) -> some View {
        self
            #if os(macOS)
            .onPasteCommand(of: [.image]) { providers in model.setArtwork(from: providers, for: key) }
            #endif
            .onDrop(of: ArtworkPasteboard.acceptedTypes, isTargeted: nil) { providers in
                model.setArtwork(from: providers, for: key)
                return true
            }
    }
}
