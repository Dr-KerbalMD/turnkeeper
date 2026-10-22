import Bestiary
import Foundation

/// A record that can be shared between devices: it has a stable ID, the time it last changed, and a
/// tombstone instead of being removed, so a deletion on one device reaches the other.
public protocol LibraryRecord: Codable, Sendable, Identifiable where ID == UUID {
    var id: UUID { get }
    var modifiedAt: Date { get set }
    var deletedAt: Date? { get set }
    /// The `modifiedAt` of the version last shared with another device, so a merge can tell an update
    /// made on one side from edits made on both.
    var sharedVersion: Date? { get set }
}

public extension LibraryRecord {
    var isDeleted: Bool { deletedAt != nil }
}

/// A campaign or organized play season. Its game sets the board's look and the bestiary's default.
public struct Campaign: LibraryRecord, Hashable {
    public var id = UUID()
    public var name: String
    public var game: Game
    public var modifiedAt = Date()
    public var deletedAt: Date?
    public var sharedVersion: Date?

    public init(name: String, game: Game) {
        self.name = name
        self.game = game
    }
}

/// The player characters. Players track their own HP, so a member is a name and level, with a character
/// sheet when linked to one.
public struct Party: LibraryRecord, Hashable {
    public var id = UUID()
    public var campaignID: UUID
    public var name: String
    public var level: Int
    public var members: [PartyMember]
    public var modifiedAt = Date()
    public var deletedAt: Date?
    public var sharedVersion: Date?

    public init(campaignID: UUID, name: String, level: Int, members: [PartyMember] = []) {
        self.campaignID = campaignID
        self.name = name
        self.level = level
        self.members = members
    }

    /// The players at the table this session, which is what encounter budgets are worked out for.
    public var presentMembers: [PartyMember] { members.filter { !$0.isAway } }

    /// An encounter budget for this party's level and the players present.
    public var budget: EncounterBudget { EncounterBudget(partyLevel: level, partySize: presentMembers.count) }
}

public struct PartyMember: Codable, Sendable, Hashable, Identifiable {
    public var id = UUID()
    public var name: String
    /// Not at the table this session: left out of budgets, and waiting on the bench in fights.
    public var isAway = false
    /// The character's own level, for challenge points. Nil means the party's level.
    public var level: Int?
    /// The imported character sheet, for the PC's battle card. Nil for a quick PC.
    public var sheet: Creature?
    /// Where the sheet came from, so it can be refreshed.
    public var link: CharacterLink?
    /// Max HP typed by the GM, shown on the card only; imports never change it.
    public var maxHitPoints: Int?
    /// The real person playing the character, shown after its name in the GM's view when turned on.
    public var playerName = ""
    /// The GM's notes about the player, such as their Discord handle.
    public var notes = ""

    public init(name: String) {
        self.name = name
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, isAway, level, sheet, link, maxHitPoints, playerName, notes
    }

    /// Libraries saved before players could be away have no `isAway`, and read as present; ones saved before
    /// player names and notes have neither, and read as blank.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        isAway = try container.decodeIfPresent(Bool.self, forKey: .isAway) ?? false
        level = try container.decodeIfPresent(Int.self, forKey: .level)
        sheet = try container.decodeIfPresent(Creature.self, forKey: .sheet)
        link = try container.decodeIfPresent(CharacterLink.self, forKey: .link)
        maxHitPoints = try container.decodeIfPresent(Int.self, forKey: .maxHitPoints)
        playerName = try container.decodeIfPresent(String.self, forKey: .playerName) ?? ""
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }
}

/// A scenario or adventure chapter: ordered encounters, each planned at every difficulty in the scheme.
public struct Scenario: LibraryRecord, Hashable {
    public var id = UUID()
    public var campaignID: UUID
    public var name: String
    public var notes = ""
    public var levelRange = ""
    /// Difficulty labels, such as "10–12 CP" and "16–18 CP", or "Easier", "Base" and "Harder".
    public var variantLabels: [String]
    /// The variant last run, offered first next time.
    public var lastVariantLabel = ""
    public var sortIndex = 0
    public var modifiedAt = Date()
    public var deletedAt: Date?
    public var sharedVersion: Date?

    public init(campaignID: UUID, name: String, variantLabels: [String] = VariantScheme.single.labels) {
        self.campaignID = campaignID
        self.name = name
        self.variantLabels = variantLabels.isEmpty ? VariantScheme.single.labels : variantLabels
    }

    /// The difficulty an encounter opens at, when the party's challenge points pick none: Base for a new
    /// encounter (nothing planned yet), else the one last run, else Base, else the first.
    public func startingVariantLabel(for encounter: Encounter) -> String {
        let base = variantLabels.contains(VariantScheme.baseLabel) ? VariantScheme.baseLabel : variantLabels[0]
        let isNew = encounter.variants.allSatisfy { $0.slots.isEmpty && $0.events.isEmpty }
        guard !isNew, variantLabels.contains(lastVariantLabel) else { return base }
        return lastVariantLabel
    }
}

/// Preset difficulty schemes. The labels stay editable; these just fill them in.
public enum VariantScheme: String, CaseIterable, Sendable {
    case challengePointsLowTier
    case challengePointsHighTier
    case easierBaseHarder
    case single

    /// The middle difficulty of Easier, Base and Harder.
    public static let baseLabel = "Base"

    public var title: String {
        switch self {
        case .challengePointsLowTier: return "Challenge Points, low tier"
        case .challengePointsHighTier: return "Challenge Points, high tier"
        case .easierBaseHarder: return "Easier, Base, Harder"
        case .single: return "One version"
        }
    }

    public var labels: [String] {
        switch self {
        case .challengePointsLowTier: return ["10–11 CP", "12–13 CP", "14–15 CP", "16–18 CP"]
        case .challengePointsHighTier: return ["19–22 CP", "23–27 CP", "28–32 CP", "33+ CP"]
        case .easierBaseHarder: return ["Easier", "Base", "Harder"]
        case .single: return ["Standard"]
        }
    }
}
