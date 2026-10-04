import Foundation

/// Everything the GM has planned and every saved fight. Records are never removed, only marked deleted,
/// so merges with another device can carry deletions across.
public struct Library: Codable, Sendable, Hashable {
    public var campaigns: [Campaign] = []
    public var parties: [Party] = []
    public var scenarios: [Scenario] = []
    public var encounters: [Encounter] = []
    public var sessions: [CombatSession] = []

    public init() {}

    // MARK: Queries (deleted records left out)

    public var activeCampaigns: [Campaign] { campaigns.filter { !$0.isDeleted }.sorted { $0.name < $1.name } }

    public func parties(in campaignID: UUID) -> [Party] {
        parties.filter { $0.campaignID == campaignID && !$0.isDeleted }.sorted { $0.name < $1.name }
    }

    public func scenarios(in campaignID: UUID) -> [Scenario] {
        scenarios.filter { $0.campaignID == campaignID && !$0.isDeleted }
            .sorted { ($0.sortIndex, $0.name) < ($1.sortIndex, $1.name) }
    }

    public func encounters(in scenarioID: UUID) -> [Encounter] {
        encounters.filter { $0.scenarioID == scenarioID && !$0.isDeleted }
            .sorted { ($0.sortIndex, $0.name) < ($1.sortIndex, $1.name) }
    }

    /// The fight for an encounter at a difficulty that hasn't ended, newest first if there are several.
    public func unfinishedSession(encounterID: UUID, variantLabel: String) -> CombatSession? {
        sessions.filter { $0.encounterID == encounterID && $0.variantLabel == variantLabel }
            .filter { !$0.isDeleted && !$0.isFinished }
            .max { $0.modifiedAt < $1.modifiedAt }
    }

    public func sessions(in campaignID: UUID) -> [CombatSession] {
        sessions.filter { $0.campaignID == campaignID && !$0.isDeleted }.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    // MARK: Changes (each stamps modifiedAt)

    public mutating func save(_ campaign: Campaign) { upsert(campaign, into: \.campaigns) }
    public mutating func save(_ party: Party) { upsert(party, into: \.parties) }
    public mutating func save(_ scenario: Scenario) { upsert(scenario, into: \.scenarios) }
    public mutating func save(_ encounter: Encounter) { upsert(encounter, into: \.encounters) }
    public mutating func save(_ session: CombatSession) { upsert(session, into: \.sessions) }

    /// Marks a campaign and everything in it deleted.
    public mutating func deleteCampaign(_ id: UUID) {
        let now = Date()
        mark(\.campaigns, now) { $0.id == id }
        mark(\.parties, now) { $0.campaignID == id }
        let scenarioIDs = Set(scenarios.filter { $0.campaignID == id }.map(\.id))
        mark(\.scenarios, now) { scenarioIDs.contains($0.id) }
        mark(\.encounters, now) { scenarioIDs.contains($0.scenarioID) }
        mark(\.sessions, now) { $0.campaignID == id }
    }

    public mutating func deleteScenario(_ id: UUID) {
        let now = Date()
        mark(\.scenarios, now) { $0.id == id }
        mark(\.encounters, now) { $0.scenarioID == id }
    }

    public mutating func deleteParty(_ id: UUID) { mark(\.parties, Date()) { $0.id == id } }
    public mutating func deleteEncounter(_ id: UUID) { mark(\.encounters, Date()) { $0.id == id } }
    public mutating func deleteSession(_ id: UUID) { mark(\.sessions, Date()) { $0.id == id } }

    private mutating func upsert<Record: LibraryRecord>(
        _ record: Record, into path: WritableKeyPath<Library, [Record]>
    ) {
        var stamped = record
        stamped.modifiedAt = Date()
        if let index = self[keyPath: path].firstIndex(where: { $0.id == record.id }) {
            self[keyPath: path][index] = stamped
        } else {
            self[keyPath: path].append(stamped)
        }
    }

    private mutating func mark<Record: LibraryRecord>(
        _ path: WritableKeyPath<Library, [Record]>, _ time: Date, where matches: (Record) -> Bool
    ) {
        for index in self[keyPath: path].indices where matches(self[keyPath: path][index]) {
            guard self[keyPath: path][index].deletedAt == nil else { continue }
            self[keyPath: path][index].deletedAt = time
            self[keyPath: path][index].modifiedAt = time
        }
    }
}
