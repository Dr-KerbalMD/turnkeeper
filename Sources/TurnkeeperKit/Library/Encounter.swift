import Bestiary
import Foundation

/// One encounter of a scenario, with a creature list for each difficulty variant.
public struct Encounter: LibraryRecord, Hashable {
    public var id = UUID()
    public var scenarioID: UUID
    public var name: String
    public var notes = ""
    /// The map or room, such as "A3. Docks".
    public var location = ""
    public var sortIndex = 0
    public var variants: [EncounterVariant] = []
    public var modifiedAt = Date()
    public var deletedAt: Date?
    public var sharedVersion: Date?
    public var sharedVersions: [Date]?

    public init(scenarioID: UUID, name: String) {
        self.scenarioID = scenarioID
        self.name = name
    }

    /// The variant for a label, empty if it hasn't been planned yet.
    public func variant(_ label: String) -> EncounterVariant {
        variants.first { $0.label == label } ?? EncounterVariant(label: label)
    }

    public mutating func setVariant(_ variant: EncounterVariant) {
        if let index = variants.firstIndex(where: { $0.label == variant.label }) {
            variants[index] = variant
        } else {
            variants.append(variant)
        }
    }

    /// Copies another variant's creatures and events into a variant, as a starting point.
    public mutating func copyVariant(from source: String, to target: String) {
        var copy = variant(source)
        copy.label = target
        copy.slots = copy.slots.map { slot in
            var fresh = slot
            fresh.id = UUID()
            return fresh
        }
        copy.events = copy.events.map { event in
            var fresh = event
            fresh.id = UUID()
            return fresh
        }
        setVariant(copy)
    }
}

/// The creatures, bench and events of one difficulty of an encounter.
public struct EncounterVariant: Codable, Sendable, Hashable {
    public var label: String
    public var slots: [EncounterSlot] = []
    public var events: [EncounterEvent] = []

    public init(label: String) {
        self.label = label
    }
}

/// One line of an encounter: a number of the same creature, or a custom NPC.
public struct EncounterSlot: Codable, Sendable, Hashable, Identifiable {
    public var id = UUID()
    /// A bestiary key, or a custom creature's `custom.<id>` key.
    public var creatureKey: String
    public var count = 1
    public var template = CreatureTemplate.normal
    public var side = Side.enemy
    public var startsOnBench = false
    /// Conditions every creature from this slot starts the fight with, such as enfeebled 1.
    public var conditions: [AppliedCondition] = []
    /// Temporary HP every creature from this slot starts with.
    public var temporaryHitPoints = 0

    public init(creatureKey: String) {
        self.creatureKey = creatureKey
    }

    private enum CodingKeys: String, CodingKey {
        case id, creatureKey, count, template, side, startsOnBench
        case conditions, temporaryHitPoints
    }

    /// Fields added after the first release may be missing from saved libraries; they read as their defaults.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        creatureKey = try container.decode(String.self, forKey: .creatureKey)
        count = try container.decodeIfPresent(Int.self, forKey: .count) ?? 1
        template = try container.decodeIfPresent(CreatureTemplate.self, forKey: .template) ?? .normal
        side = try container.decodeIfPresent(Side.self, forKey: .side) ?? .enemy
        startsOnBench = try container.decodeIfPresent(Bool.self, forKey: .startsOnBench) ?? false
        conditions = try container.decodeIfPresent([AppliedCondition].self, forKey: .conditions) ?? []
        temporaryHitPoints = try container.decodeIfPresent(Int.self, forKey: .temporaryHitPoints) ?? 0
    }

    public var isCustom: Bool { CustomCreature.isCustomKey(creatureKey) }
}

/// A fight, saved so it can be continued later or on the other device.
public struct CombatSession: LibraryRecord, Hashable {
    public var id = UUID()
    public var campaignID: UUID
    public var encounterID: UUID
    public var variantLabel: String
    public var name: String
    public var state: CombatState
    /// The party the fight was started with, so a reset can rebuild it.
    public var partyID: UUID?
    /// When the fight ended. Nil while it can still be resumed.
    public var finishedAt: Date?
    public var modifiedAt = Date()
    public var deletedAt: Date?
    public var sharedVersion: Date?
    public var sharedVersions: [Date]?

    public init(context: SessionContext, state: CombatState) {
        campaignID = context.campaignID
        encounterID = context.encounterID
        variantLabel = context.variantLabel
        name = context.name
        partyID = context.partyID
        self.state = state
    }

    public var isFinished: Bool { finishedAt != nil }

    /// Unfinished, and either begun or with someone's initiative entered: closing it would lose real state.
    public var isInProgress: Bool { !isFinished && state.hasStarted }
}

/// Where a combat session comes from.
public struct SessionContext: Sendable {
    public var campaignID: UUID
    public var encounterID: UUID
    public var variantLabel: String
    public var name: String
    public var partyID: UUID?

    public init(campaignID: UUID, encounterID: UUID, variantLabel: String, name: String) {
        self.campaignID = campaignID
        self.encounterID = encounterID
        self.variantLabel = variantLabel
        self.name = name
    }
}
