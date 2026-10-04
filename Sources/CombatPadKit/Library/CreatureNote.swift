import Foundation

/// The GM's note about a creature within a scenario, such as "The war chanter carries the vault key". It
/// shows wherever that creature appears in the scenario, in planning and on the board, and merges on its own
/// so editing it mid-fight never makes a conflict copy of the scenario.
public struct CreatureNote: LibraryRecord, Hashable {
    public var id = UUID()
    public var scenarioID: UUID
    /// The creature: a bestiary key or a custom creature's `custom.<id>` key.
    public var subject: String
    public var text: String
    public var modifiedAt = Date()
    public var deletedAt: Date?
    public var sharedVersion: Date?

    public init(scenarioID: UUID, subject: String, text: String = "") {
        self.scenarioID = scenarioID
        self.subject = subject
        self.text = text
    }
}
