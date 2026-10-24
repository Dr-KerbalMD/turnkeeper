import Bestiary
import Foundation

/// What putting an imported sheet on a party member changed, for the message after an import or refresh.
public enum SheetUpdate: Equatable, Sendable {
    /// A new member joined with the sheet.
    case added
    /// A member's sheet changed; the changes read like "AC 18 → 19".
    case updated([String])
    /// The sheet is the same as before: the player may not have saved their changes on Demiplane yet.
    case unchanged
}

extension Party {
    /// Puts an imported sheet on `memberID` (a quick PC being linked, or a refresh), else on the member linked to
    /// the same character, else on a new member. The member keeps its name and the GM's max HP.
    public mutating func apply(_ sheet: Creature, link: CharacterLink, to memberID: UUID? = nil) -> SheetUpdate {
        let index = members.firstIndex { $0.id == memberID }
            ?? members.firstIndex { $0.link?.characterID == link.characterID }
        let previous = index.flatMap { members[$0].sheet }
        let target = index ?? members.endIndex
        if index == nil { members.append(PartyMember(name: sheet.name)) }
        members[target].sheet = sheet
        members[target].link = link
        members[target].level = sheet.level
        guard index != nil else { return .added }
        guard let previous else { return .updated([]) }
        return previous == sheet ? .unchanged : .updated(SheetComparison.changes(from: previous, to: sheet))
    }

    /// Takes each member's sheet from `other` where it was fetched later there, as when a member was refreshed
    /// on one device while the party was edited on another.
    public mutating func keepNewerSheets(from other: Party) {
        for index in members.indices {
            guard let theirs = other.members.first(where: { $0.id == members[index].id }),
                  let theirLink = theirs.link,
                  theirLink.fetchedAt > members[index].link?.fetchedAt ?? .distantPast
            else { continue }
            members[index].sheet = theirs.sheet
            members[index].link = theirLink
            members[index].level = theirs.level
        }
    }
}

/// The differences between two sheets of the same character that a GM would care about at the table.
enum SheetComparison {
    static func changes(from old: Creature, to new: Creature) -> [String] {
        numberChanges(from: old, to: new) + listChanges(from: old, to: new)
    }

    private static func numberChanges(from old: Creature, to new: Creature) -> [String] {
        let numbers: [(String, KeyPath<Creature, Int>)] = [
            ("Level", \.level), ("AC", \.defenses.armorClass), ("Fort", \.defenses.fortitude),
            ("Ref", \.defenses.reflex), ("Will", \.defenses.will), ("Perception", \.senses.perception),
            ("Class DC", \.classDifficultyClass)
        ]
        return numbers.compactMap { label, path in
            old[keyPath: path] == new[keyPath: path] ? nil : "\(label) \(old[keyPath: path]) → \(new[keyPath: path])"
        }
    }

    private static func listChanges(from old: Creature, to new: Creature) -> [String] {
        var changes: [String] = []
        if old.skills != new.skills { changes.append("skills") }
        if old.strikes != new.strikes { changes.append("Strikes") }
        if old.spellcasting != new.spellcasting { changes.append("spells") }
        if old.player?.feats != new.player?.feats { changes.append("feats") }
        if old.items != new.items { changes.append("items") }
        return changes
    }
}

private extension Creature {
    var classDifficultyClass: Int { player?.classDC ?? 0 }
}
