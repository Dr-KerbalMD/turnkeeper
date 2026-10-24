import Bestiary
import Foundation

/// An iconic pregen at one of its levels, ready to join a party as a Table Buddy.
public struct Pregen: Sendable, Hashable {
    /// Its key, such as `ezren`, the same at every level.
    public var key: String
    public var name: String
    public var level: Int
    public var sheet: Creature
    public var hitPoints: Int
    /// How many of the sheet's spells, abilities and items lead to the glossary, out of how many.
    public var linkedNames = 0
    public var totalNames = 0

    public init(key: String, name: String, level: Int, sheet: Creature, hitPoints: Int) {
        self.key = key
        self.name = name
        self.level = level
        self.sheet = sheet
        self.hitPoints = hitPoints
    }
}

/// Where Table Buddies come from: the iconics, exported from Foundry.
public protocol PregenSource: Sendable {
    /// The levels a pregen comes at.
    func levels(of key: String) -> [Int]
    func pregen(_ key: String, level: Int) -> Pregen?
}

public extension PartyMember {
    /// A pregen the GM added to fill out the table.
    var isTableBuddy: Bool { link?.source == .pregen }

    /// Puts a pregen's sheet, level and max HP on the member. Nothing changes when it already has that level.
    internal mutating func play(_ pregen: Pregen) {
        guard level != pregen.level || sheet == nil else { return }
        sheet = pregen.sheet
        level = pregen.level
        maxHitPoints = pregen.hitPoints
        link = CharacterLink(source: .pregen, characterID: pregen.key, game: pregen.sheet.game)
        link?.linkedNames = pregen.linkedNames
        link?.totalNames = pregen.totalNames
    }
}

public extension Party {
    /// Adds a pregen at the party's level, or the nearest level it comes at below, and gives the new member's
    /// ID. Nil when the source has no such pregen.
    @discardableResult
    mutating func addTableBuddy(_ key: String, from source: any PregenSource) -> UUID? {
        guard let level = PregenLevel.available(self.level, among: source.levels(of: key)),
              let pregen = source.pregen(key, level: level) else { return nil }
        var member = PartyMember(name: pregen.name)
        member.play(pregen)
        members.append(member)
        return member.id
    }

    /// The party with each Table Buddy at the level a scenario calls for, or at the party's level when the
    /// scenario has no levels yet. A Table Buddy the Guide doesn't allow there keeps its level; see
    /// `allowsTableBuddies`.
    func settlingTableBuddies(game: Game, levelRange: String, source: any PregenSource) -> Party {
        guard let wanted = tableBuddyLevel(game: game, levelRange: levelRange) else { return self }
        var party = self
        for index in party.members.indices where party.members[index].isTableBuddy {
            guard let key = party.members[index].link?.characterID,
                  let level = PregenLevel.available(wanted, among: source.levels(of: key)),
                  let pregen = source.pregen(key, level: level) else { continue }
            party.members[index].play(pregen)
        }
        return party
    }

    /// The Guide adds no pregens to Pathfinder adventures for level 7 and up.
    func allowsTableBuddies(game: Game, levelRange: String) -> Bool {
        tableBuddyLevel(game: game, levelRange: levelRange) != nil
    }

    /// The party whose challenge points pick a scenario's difficulty: Table Buddies settled, and left out
    /// where the Guide allows none.
    func countingTableBuddies(game: Game, levelRange: String, source: any PregenSource) -> Party {
        var party = settlingTableBuddies(game: game, levelRange: levelRange, source: source)
        if !allowsTableBuddies(game: game, levelRange: levelRange) { party.members.removeAll(where: \.isTableBuddy) }
        return party
    }

    /// The present Table Buddies, for saying what levels they play at.
    var presentTableBuddies: [PartyMember] { presentMembers.filter(\.isTableBuddy) }

    /// The level Table Buddies should play at; nil when the Guide allows none.
    private func tableBuddyLevel(game: Game, levelRange: String) -> Int? {
        guard let lowest = ChallengePoints.lowestLevel(in: levelRange) else { return level }
        if game == .starfinder { return lowest }
        let realLevels = presentMembers.filter { !$0.isTableBuddy }.map { $0.level ?? level }
        return PregenLevel.pathfinder(baseLevel: lowest, realLevels: realLevels)
    }
}
