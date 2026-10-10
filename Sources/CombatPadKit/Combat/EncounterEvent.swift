import Bestiary
import Foundation

/// When an event fires.
public enum EventTrigger: Codable, Sendable, Hashable {
    /// When the turn order passes this initiative count, after combatants with the same count.
    case initiative(Int)
    case startOfRound
    case endOfRound
    /// At the start of the turn of a combatant from this encounter slot.
    case turnStart(slotID: UUID)
    case turnEnd(slotID: UUID)
    /// When the GM ends the fight, such as treasure to hand out or a door that opens.
    case endOfCombat
}

/// Which rounds an event fires in.
public enum EventOccurrence: Codable, Sendable, Hashable {
    case everyRound
    case onlyRound(Int)
    /// Every `interval` rounds starting at round `start`, such as rounds 3, 5 and 7.
    case every(interval: Int, start: Int)

    public func includes(round: Int) -> Bool {
        switch self {
        case .everyRound: return true
        case let .onlyRound(only): return round == only
        case let .every(interval, start): return round >= start && (round - start) % max(interval, 1) == 0
        }
    }
}

/// Something that happens at a set point in the fight: a planned event or one added during combat.
public struct EncounterEvent: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var label: String
    public var text: String
    public var trigger: EventTrigger
    public var occurrence: EventOccurrence
    /// Encounter slots whose benched creatures join the fight when the event fires.
    public var bringsInSlotIDs: [UUID]
    public var isEnabled: Bool

    public init(label: String, trigger: EventTrigger, occurrence: EventOccurrence = .everyRound, text: String = "") {
        id = UUID()
        self.label = label
        self.text = text
        self.trigger = trigger
        self.occurrence = occurrence
        bringsInSlotIDs = []
        isEnabled = true
    }

    /// Whether the event fires once, when the fight ends, rather than in a round.
    public var isAtEndOfCombat: Bool { trigger == .endOfCombat }

    public var initiativeCount: Int? {
        if case let .initiative(count) = trigger { return count }
        return nil
    }
}

/// A duration arrow: an effect that lasts a number of rounds, counted at one combatant's turn.
public struct DurationMarker: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var label: String
    public var roundsRemaining: Int
    public var anchorCombatantID: UUID
    public var moment: TurnMoment

    public init(label: String, rounds: Int, anchor: UUID, moment: TurnMoment) {
        id = UUID()
        self.label = label
        roundsRemaining = rounds
        anchorCombatantID = anchor
        self.moment = moment
    }
}
