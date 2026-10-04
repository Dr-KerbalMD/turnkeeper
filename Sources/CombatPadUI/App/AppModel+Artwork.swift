import CombatPadKit
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
            guard let image = await ArtworkPasteboard.imageData(from: providers) else { return }
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

/// Reads images from pasted or dropped items: image data such as Pluck's PNG, or an image file.
enum ArtworkPasteboard {
    static let acceptedTypes: [UTType] = [.image, .fileURL]

    @MainActor
    static func imageData(from providers: [NSItemProvider]) async -> Data? {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier),
               let data = await data(from: provider, type: UTType.image.identifier) {
                return data
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
