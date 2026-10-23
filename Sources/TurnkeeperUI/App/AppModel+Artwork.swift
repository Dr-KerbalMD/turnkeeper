import TurnkeeperKit
import Foundation
import UniformTypeIdentifiers

/// Pasted artwork: stored as files in the art store, pointed to by `CustomArt` records.
extension AppModel {
    /// Stores an image as a creature's art, downscaling it off the main actor.
    func setArtwork(_ image: Data, for key: String) async {
        guard let artStore else {
            errorMessage = "Adding the artwork failed: there's no folder to keep it in."
            return
        }
        do {
            let art = try await Task.detached { try artStore.add(image, for: key) }.value
            library.save(art)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Reads an image from pasted, dropped or chosen items and stores it as the creature's art.
    func setArtwork(from providers: [NSItemProvider], for key: String) {
        Task {
            guard let image = await ArtworkPasteboard.imageData(from: providers) else {
                errorMessage = ArtworkPasteboard.unusableMessage(for: providers)
                return
            }
            await setArtwork(image, for: key)
        }
    }

    /// Back to the bundled art; the file is swept at the next launch.
    func removeArtwork(for key: String) {
        library.deleteCustomArt(for: key)
    }

    func hasPastedArtwork(_ key: String) -> Bool {
        library.customArt(for: key) != nil
    }
}

/// Reads images from pasted or dropped items: image data such as Pluck's PNG, PDF data, an image copied from
/// a PDF viewer as rich text, or an image or PDF file.
enum ArtworkPasteboard {
    static let acceptedTypes: [UTType] = [.image, .pdf, RichTextAttachments.flatRTFD, .fileURL]
    /// What turns Paste on: anything, so a clipboard without an image says what it holds instead of
    /// leaving the button dimmed with no reason given.
    static let pasteTypes: [UTType] = acceptedTypes + [.item]

    @MainActor
    static func imageData(from providers: [NSItemProvider]) async -> Data? {
        for provider in providers {
            for type in [UTType.image, .pdf] where provider.hasItemConformingToTypeIdentifier(type.identifier) {
                if let data = await data(from: provider, type: type.identifier) { return data }
            }
            let richText = RichTextAttachments.flatRTFD.identifier
            if provider.hasItemConformingToTypeIdentifier(richText),
               let data = await data(from: provider, type: richText),
               let image = RichTextAttachments.firstImage(inFlatRTFD: data) {
                return image
            }
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
               let reference = await data(from: provider, type: UTType.fileURL.identifier),
               let url = URL(dataRepresentation: reference, relativeTo: nil),
               let data = try? Data(contentsOf: url) {
                return data
            }
        }
        return nil
    }

    /// Why nothing could be used, naming what the items held.
    static func unusableMessage(for providers: [NSItemProvider]) -> String {
        let held = providers.flatMap(\.registeredTypeIdentifiers).map { UTType($0)?.localizedDescription ?? $0 }
        let list = Array(NSOrderedSet(array: held)).compactMap { $0 as? String }.joined(separator: ", ")
        return "Pasting failed: there's no image or PDF to use"
            + (list.isEmpty ? "." : ". The clipboard holds: \(list).")
    }

    @MainActor
    private static func data(from provider: NSItemProvider, type: String) async -> Data? {
        await withCheckedContinuation { continuation in
            _ = provider.loadDataRepresentation(forTypeIdentifier: type, completionHandler: resume(continuation))
        }
    }

    /// Built outside the main actor: the provider calls back on its own queue.
    private nonisolated static func resume(
        _ continuation: CheckedContinuation<Data?, Never>
    ) -> @Sendable (Data?, (any Error)?) -> Void {
        { data, _ in continuation.resume(returning: data) }
    }
}
