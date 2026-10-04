import CombatPadKit
import SwiftUI
import UniformTypeIdentifiers

/// A handout in the planner: its name and image, with Paste, Choose Image… and Show Players.
struct HandoutView: View {
    let handout: Handout
    @Environment(AppModel.self) private var model
    @State private var isChoosingFile = false
    @State private var isPresentingHere = false

    var body: some View {
        VStack(spacing: 16) {
            TextField("Name", text: nameBinding).titleEntry()
                .font(.title2)
                .textFieldStyle(.roundedBorder)
            controls
            if handout.hasImage {
                HandoutImage(path: handout.imagePath)
            } else {
                ContentUnavailableView("No Image", systemImage: "photo", description: Text(
                    "Paste an image copied from Pluck, choose a file, or drop one here."))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        #if os(macOS)
        .onPasteCommand(of: [.image]) { model.setImage(from: $0, forHandout: handout.id) }
        #endif
        .onDrop(of: ArtworkPasteboard.acceptedTypes, isTargeted: nil) { providers in
            model.setImage(from: providers, forHandout: handout.id)
            return true
        }
        .navigationTitle(handout.name)
        .fileImporter(isPresented: $isChoosingFile, allowedContentTypes: [.image]) { result in
            guard case .success(let url) = result else { return }
            Task { await choose(url) }
        }
        .playerPresentation(isPresented: $isPresentingHere) {
            HandoutPlayerView(name: handout.name, imagePath: handout.imagePath)
        }
    }

    /// In the page rather than the toolbar: iOS ignores a paste button it can't see in full.
    private var controls: some View {
        HStack(spacing: 12) {
            PasteButton(supportedContentTypes: [.image]) { model.setImage(from: $0, forHandout: handout.id) }
                .labelStyle(.titleAndIcon)
            Button("Choose Image…", systemImage: "folder") { isChoosingFile = true }
            Spacer()
            Button("Show Players", systemImage: "eye") {
                PlayerDisplay.shared.show(handout: handout)
                if !PlayerDisplay.shared.hasSecondScreen { isPresentingHere = true }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!handout.hasImage)
        }
        .buttonStyle(.bordered)
    }

    private var nameBinding: Binding<String> {
        Binding(get: { handout.name }, set: { name in
            var edited = handout
            edited.name = name
            model.library.save(edited)
        })
    }

    private func choose(_ url: URL) async {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }
        await model.setImage(data, forHandout: handout.id)
    }
}

/// A handout image, as large as fits.
struct HandoutImage: View {
    let path: String
    @Environment(AppModel.self) private var model
    @State private var image: CGImage?

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1).resizable().scaledToFit()
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: path) {
            guard let url = model.artURL(for: path) else { return }
            image = await ArtLoader.shared.image(at: url, maxPixels: 0)
        }
    }
}

/// What the players see for a handout: the image on black, with its name as a caption. Tap to close.
struct HandoutPlayerView: View {
    let name: String
    let imagePath: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 12) {
                HandoutImage(path: imagePath)
                Text(name).font(.title2.weight(.semibold)).foregroundStyle(.white)
            }
            .padding()
        }
        .onTapGesture { dismiss() }
        #if os(iOS)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        #else
        .frame(minWidth: 640, idealWidth: 900, minHeight: 640, idealHeight: 900)
        #endif
    }
}
