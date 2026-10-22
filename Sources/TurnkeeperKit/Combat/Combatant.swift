import Bestiary
import Foundation

/// What a combatant is, which sets its magnet color and what the board tracks for it.
public enum CombatantKind: String, Codable, Sendable {
    /// Blue. Players track their own HP, so only conditions and initiative are kept.
    case playerCharacter
    /// Red, or green when an ally. Bestiary and custom creatures alike.
    case creature
    /// Gray. A complex hazard from the bestiary.
    case hazard
}

public enum Side: String, Codable, Sendable {
    case enemy
    case ally
}

/// Where a combatant sits on the board.
public enum PadPlace: String, Codable, Sendable {
    /// In initiative order.
    case ladder
    /// Waiting off to the side. Sessions saved before delayed strips stayed on the ladder have it; they
    /// decode as ladder combatants with `isDelaying` set.
    case delaying
    /// On the bench, not yet in the fight.
    case bench
}

/// One participant in a fight.
public struct Combatant: Codable, Sendable, Identifiable, Hashable {
    public var id: UUID
    public var kind: CombatantKind
    public var side: Side
    public var name: String
    /// The creature's key, from the bestiary or `custom.<id>`; `pc.<member id>` for a linked PC, else empty.
    public var creatureKey: String
    /// The encounter slot this combatant came from, so planned turn events can find it.
    public var slotID: UUID?
    public var template: CreatureTemplate
    /// Damage is tracked rather than current HP, so changing the template keeps the damage taken.
    public var damageTaken: Int
    public var temporaryHitPoints: Int
    /// The rolled initiative. Ties can be broken with halves, such as 17.5.
    public var initiative: Double?
    public var place: PadPlace
    /// Delaying: still on the ladder, but its turns are skipped until it returns.
    public var isDelaying: Bool
    /// Delayed after its turn began. As the Delay rule says, its end of turn came at once; when it returns it
    /// takes the rest of that turn, without start- or end-of-turn reminders again.
    public var delayedMidTurn: Bool
    public var conditions: [AppliedCondition]
    public var notes: String
    /// The real person playing a PC, from the party; blank for creatures.
    public var playerName: String

    public init(kind: CombatantKind, name: String, side: Side = .enemy, creatureKey: String = "") {
        id = UUID()
        self.kind = kind
        self.side = kind == .playerCharacter ? .ally : side
        self.name = name
        self.creatureKey = creatureKey
        slotID = nil
        template = .normal
        damageTaken = 0
        temporaryHitPoints = 0
        initiative = nil
        place = .ladder
        isDelaying = false
        delayedMidTurn = false
        conditions = []
        notes = ""
        playerName = ""
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, side, name, creatureKey, slotID, template, damageTaken, temporaryHitPoints, initiative
        case place, isDelaying, delayedMidTurn, conditions, notes, playerName
    }

    /// Sessions saved before delayed strips stayed on the ladder have no `isDelaying`, and keep delayed
    /// combatants off the ladder; those come back to it, still delaying.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(CombatantKind.self, forKey: .kind)
        side = try container.decode(Side.self, forKey: .side)
        name = try container.decode(String.self, forKey: .name)
        creatureKey = try container.decode(String.self, forKey: .creatureKey)
        slotID = try container.decodeIfPresent(UUID.self, forKey: .slotID)
        template = try container.decode(CreatureTemplate.self, forKey: .template)
        damageTaken = try container.decode(Int.self, forKey: .damageTaken)
        temporaryHitPoints = try container.decode(Int.self, forKey: .temporaryHitPoints)
        initiative = try container.decodeIfPresent(Double.self, forKey: .initiative)
        let savedPlace = try container.decode(PadPlace.self, forKey: .place)
        place = savedPlace == .delaying ? .ladder : savedPlace
        isDelaying = try container.decodeIfPresent(Bool.self, forKey: .isDelaying) ?? (savedPlace == .delaying)
        delayedMidTurn = try container.decodeIfPresent(Bool.self, forKey: .delayedMidTurn) ?? false
        conditions = try container.decode([AppliedCondition].self, forKey: .conditions)
        notes = try container.decode(String.self, forKey: .notes)
        playerName = try container.decodeIfPresent(String.self, forKey: .playerName) ?? ""
    }

    public var tracksHitPoints: Bool { kind != .playerCharacter }

    /// The magnet's color.
    public var magnet: Magnet {
        switch kind {
        case .playerCharacter: return .blue
        case .hazard: return .gray
        case .creature: return side == .enemy ? .red : .green
        }
    }

    public func condition(_ slug: String) -> AppliedCondition? {
        conditions.first { $0.slug == slug }
    }

    public var isDying: Bool { condition(ConditionSlug.dying) != nil }
}

public enum Magnet: String, Codable, Sendable {
    case red
    case blue
    case green
    case gray
}
