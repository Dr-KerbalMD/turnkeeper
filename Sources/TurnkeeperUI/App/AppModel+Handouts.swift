import TurnkeeperKit
import Foundation

/// Scenario handouts: a name and an image kept in the art store.
extension AppModel {
    func handout(_ id: UUID?) -> Handout? {
        library.handouts.first { $0.id == id && !$0.isDeleted }
    }

    func addHandout(to scenarioID: UUID) {
        let count = library.handouts(in: scenarioID).count
        let handout = Handout(scenarioID: scenarioID, name: "Handout \(count + 1)")
        library.save(handout)
        selection = .handout(handout.id)
    }

    /// Stores an image as the handout's, downscaled off the main actor. The old file is swept at launch.
    func setImage(_ image: Data, forHandout id: UUID) async {
        guard let artStore else {
            errorMessage = "Adding the handout image failed: there's no folder to keep it in."
            return
        }
        do {
            let stored = try await Task.detached { try artStore.store(image) }.value
            guard var handout = handout(id) else { return }
            handout.fileName = stored.fileName
            handout.byteCount = stored.byteCount
            library.save(handout)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Reads an image from pasted, dropped or chosen items and makes it the handout's.
    func setImage(from providers: [NSItemProvider], forHandout id: UUID) {
        Task {
            guard let image = await ArtworkPasteboard.imageData(from: providers) else {
                errorMessage = ArtworkPasteboard.unusableMessage(for: providers)
                return
            }
            await setImage(image, forHandout: id)
        }
    }
}
