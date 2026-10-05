import Foundation

/// What a combatant is, which sets its magnet color and what the pad tracks for it.
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

/// Where a combatant sits on the pad.
public enum PadPlace: String, Codable, Sendable {
    /// In initiative order.
    case ladder
    /// Waiting off to the side; it comes back by taking its turn now.
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
    public var conditions: [AppliedCondition]
    public var notes: String

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
        conditions = []
        notes = ""
    }

    public var tracksHitPoints: Bool { kind != .playerCharacter }

    /// The magnet color on the paper pad.
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
}

public enum Magnet: String, Codable, Sendable {
    case red
    case blue
    case green
    case gray
}
