import Foundation

/// Everything the GM has planned and every saved fight. Records are never removed, only marked deleted,
/// so merges with another device can carry deletions across.
public struct Library: Codable, Sendable, Hashable {
    public var campaigns: [Campaign] = []
    public var parties: [Party] = []
    public var scenarios: [Scenario] = []
    public var encounters: [Encounter] = []
    public var sessions: [CombatSession] = []
    public var customCreatures: [CustomCreature] = []
    public var customArt: [CustomArt] = []
    public var handouts: [Handout] = []

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case campaigns, parties, scenarios, encounters, sessions, customCreatures, customArt, handouts
    }

    /// Reads each kind of record leniently: a kind missing from an older library reads as empty, and a
    /// record that can't be read is skipped rather than losing the whole library.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        campaigns = try container.lossyArray(forKey: .campaigns)
        parties = try container.lossyArray(forKey: .parties)
        scenarios = try container.lossyArray(forKey: .scenarios)
        encounters = try container.lossyArray(forKey: .encounters)
        sessions = try container.lossyArray(forKey: .sessions)
        customCreatures = try container.lossyArray(forKey: .customCreatures)
        customArt = try container.lossyArray(forKey: .customArt)
        handouts = try container.lossyArray(forKey: .handouts)
    }

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

    /// The custom creature with a key, if it hasn't been deleted.
    public func customCreature(key: String) -> CustomCreature? {
        customCreatures.first { $0.key == key && !$0.isDeleted }
    }

    /// The pasted art for a creature, the newest when both devices pasted some.
    public func customArt(for subject: String) -> CustomArt? {
        customArt.filter { $0.subject == subject && !$0.isDeleted }.max { $0.modifiedAt < $1.modifiedAt }
    }

    /// The image files that live art and handout records point to.
    public var liveImageFileNames: Set<String> {
        Set(customArt.filter { !$0.isDeleted }.map(\.fileName))
            .union(handouts.filter { !$0.isDeleted && $0.hasImage }.map(\.fileName))
    }

    public func handouts(in scenarioID: UUID) -> [Handout] {
        handouts.filter { $0.scenarioID == scenarioID && !$0.isDeleted }.sorted { $0.name < $1.name }
    }

    public func customCreatures(in campaignID: UUID) -> [CustomCreature] {
        customCreatures.filter { $0.campaignID == campaignID && !$0.isDeleted }
            .sorted { $0.creature.name < $1.creature.name }
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
    public mutating func save(_ custom: CustomCreature) { upsert(custom, into: \.customCreatures) }

    /// Points `art.subject` at new art, retiring whatever it had before.
    public mutating func save(_ art: CustomArt) {
        deleteCustomArt(for: art.subject)
        upsert(art, into: \.customArt)
    }

    public mutating func save(_ handout: Handout) { upsert(handout, into: \.handouts) }
    public mutating func deleteHandout(_ id: UUID) { mark(\.handouts, ChangeClock.now()) { $0.id == id } }

    public mutating func deleteCustomArt(for subject: String) {
        mark(\.customArt, ChangeClock.now()) { $0.subject == subject }
    }

    /// Marks a campaign and everything in it deleted.
    public mutating func deleteCampaign(_ id: UUID) {
        let now = ChangeClock.now()
        mark(\.campaigns, now) { $0.id == id }
        mark(\.parties, now) { $0.campaignID == id }
        let scenarioIDs = Set(scenarios.filter { $0.campaignID == id }.map(\.id))
        mark(\.scenarios, now) { scenarioIDs.contains($0.id) }
        mark(\.encounters, now) { scenarioIDs.contains($0.scenarioID) }
        mark(\.handouts, now) { scenarioIDs.contains($0.scenarioID) }
        mark(\.sessions, now) { $0.campaignID == id }
        mark(\.customCreatures, now) { $0.campaignID == id }
    }

    public mutating func deleteScenario(_ id: UUID) {
        let now = ChangeClock.now()
        mark(\.scenarios, now) { $0.id == id }
        mark(\.encounters, now) { $0.scenarioID == id }
        mark(\.handouts, now) { $0.scenarioID == id }
    }

    public mutating func deleteParty(_ id: UUID) { mark(\.parties, ChangeClock.now()) { $0.id == id } }
    public mutating func deleteEncounter(_ id: UUID) { mark(\.encounters, ChangeClock.now()) { $0.id == id } }
    public mutating func deleteSession(_ id: UUID) { mark(\.sessions, ChangeClock.now()) { $0.id == id } }
    public mutating func deleteCustomCreature(_ id: UUID) { mark(\.customCreatures, ChangeClock.now()) { $0.id == id } }

    private mutating func upsert<Record: LibraryRecord>(
        _ record: Record, into path: WritableKeyPath<Library, [Record]>
    ) {
        var stamped = record
        stamped.modifiedAt = ChangeClock.now()
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

/// Wraps a value that might fail to decode, so one bad record doesn't fail the array around it.
private struct Lossy<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: Decoder) throws {
        value = try? decoder.singleValueContainer().decode(Value.self)
    }
}

extension KeyedDecodingContainer {
    /// An array that may be missing (read as empty) and whose unreadable elements are skipped.
    func lossyArray<Element: Decodable>(forKey key: Key) throws -> [Element] {
        (try decodeIfPresent([Lossy<Element>].self, forKey: key) ?? []).compactMap(\.value)
    }
}
