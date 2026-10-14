import Bestiary
import Foundation

/// A creature or complex hazard the GM made, by hand or from a stat block copied out of a PDF. It belongs
/// to a campaign and works everywhere a bestiary creature does, under the key `custom.<id>`.
public struct CustomCreature: LibraryRecord, Hashable {
    public var id = UUID()
    public var campaignID: UUID
    /// The scenario it was made for, if any, so the browser can list it first there.
    public var scenarioID: UUID?
    public var creature: Creature
    /// The organized-play subtier the stat block was printed for, such as "1-2", when known.
    public var subtier = ""
    public var modifiedAt = Date()
    public var deletedAt: Date?
    public var sharedVersion: Date?

    public static let keyPrefix = "custom."

    /// A new custom creature for a campaign, named and in the campaign's game, with everything else empty.
    public init(campaignID: UUID, game: Game, name: String) {
        self.campaignID = campaignID
        creature = Creature(key: Self.keyPrefix + id.uuidString, name: name, game: game)
        creature.source = Source(pack: "custom", title: "Custom", isRemastered: true)
    }

    public var key: String { creature.key }

    public static func isCustomKey(_ key: String) -> Bool { key.hasPrefix(keyPrefix) }
}
