import CreatureArt
import Foundation

/// The creature art from the user's own Paizo PDFs (R2.3), kept by Tabletop Kit's art store.
extension CreatureArtStore {
    /// The store in `Application Support/Turnkeeper/Creature Art`, apart from pasted art's `Art` folder, whose
    /// unused files are swept at launch.
    static func standard() throws -> CreatureArtStore {
        try CreatureArtStore(folder: URL.applicationSupportDirectory.appendingPathComponent("Turnkeeper/Creature Art"))
    }
}
