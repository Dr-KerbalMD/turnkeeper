import CombatPadKit
import Foundation
import Observation

/// What the planner's detail column shows.
enum PlannerSelection: Hashable {
    case scenario(UUID)
    case encounter(UUID)
    case party(UUID)
}

/// The app's state: the library, the bestiary, and what is selected or running. Every library change is
/// saved shortly after it happens.
@Observable
@MainActor
final class AppModel {
    var library: Library {
        didSet { scheduleSave() }
    }
    let bestiary: BestiaryStore
    var selectedCampaignID: UUID?
    var selection: PlannerSelection?
    /// The fight on screen; the planner shows when nil.
    var activeSessionID: UUID?
    var errorMessage: String?
    /// A passing message, such as the result of an import.
    var statusMessage: String?

    @ObservationIgnored private let file: LibraryFile?
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    init(library: Library = Library(), bestiary: BestiaryStore = BestiaryStore(), file: LibraryFile? = nil) {
        self.library = library
        self.bestiary = bestiary
        self.file = file
        selectedCampaignID = library.activeCampaigns.first?.id
    }

    /// The app's model, with the saved library and the bundled bestiary.
    static func live() -> AppModel {
        let bestiary = BestiaryStore.locateGeneratedDirectory().flatMap { try? BestiaryStore(generatedDirectory: $0) }
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--demo") {
            let mode = arguments.indices.contains(index + 1) ? arguments[index + 1] : "planner"
            return DemoLibrary.model(mode: mode, bestiary: bestiary ?? BestiaryStore())
        }
        do {
            let file = try LibraryFile.standard()
            return AppModel(library: try file.load(), bestiary: bestiary ?? BestiaryStore(), file: file)
        } catch {
            let model = AppModel(bestiary: bestiary ?? BestiaryStore())
            model.errorMessage = error.localizedDescription
            return model
        }
    }

    var selectedCampaign: Campaign? {
        library.campaigns.first { $0.id == selectedCampaignID && !$0.isDeleted }
    }

    var game: Game { selectedCampaign?.game ?? .pathfinder }

    var activeSession: CombatSession? {
        library.sessions.first { $0.id == activeSessionID }
    }

    func entry(_ key: String) -> BestiaryIndexEntry? {
        bestiary.entry(key)
    }

    /// Saves now, for when the app goes to the background.
    func saveNow() {
        saveTask?.cancel()
        write()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self?.write()
        }
    }

    private func write() {
        guard let file else { return }
        do {
            try file.save(library)
        } catch {
            errorMessage = "Saving the library failed: \(error.localizedDescription)"
        }
    }
}
