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
    /// A bestiary key, or empty for a custom NPC.
    public var creatureKey: String
    /// The name for a custom NPC, or a rename such as "Captain Vex" for a bestiary creature.
    public var customName = ""
    public var customHitPoints = 0
    public var customLevel = 0
    public var count = 1
    public var template = CreatureTemplate.normal
    public var side = Side.enemy
    public var startsOnBench = false

    public init(creatureKey: String) {
        self.creatureKey = creatureKey
    }

    public static func customNPC(name: String, level: Int, hitPoints: Int) -> EncounterSlot {
        var slot = EncounterSlot(creatureKey: "")
        slot.customName = name
        slot.customLevel = level
        slot.customHitPoints = hitPoints
        slot.side = .ally
        return slot
    }

    public var isCustom: Bool { creatureKey.isEmpty }
}

/// A fight, saved so it can be continued later or on the other device.
public struct CombatSession: LibraryRecord, Hashable {
    public var id = UUID()
    public var campaignID: UUID
    public var encounterID: UUID
    public var variantLabel: String
    public var name: String
    public var state: CombatState
    public var scratchNotes = ""
    public var modifiedAt = Date()
    public var deletedAt: Date?
    public var sharedVersion: Date?

    public init(context: SessionContext, state: CombatState) {
        campaignID = context.campaignID
        encounterID = context.encounterID
        variantLabel = context.variantLabel
        name = context.name
        self.state = state
    }
}

/// Where a combat session comes from.
public struct SessionContext: Sendable {
    public var campaignID: UUID
    public var encounterID: UUID
    public var variantLabel: String
    public var name: String

    public init(campaignID: UUID, encounterID: UUID, variantLabel: String, name: String) {
        self.campaignID = campaignID
        self.encounterID = encounterID
        self.variantLabel = variantLabel
        self.name = name
    }
}
