import Foundation

/// A member taken out of a party, kept so the removal reaches the other device instead of the member
/// coming back from its copy.
public struct RemovedMember: Codable, Sendable, Hashable {
    public var id: UUID
    public var removedAt: Date

    public init(id: UUID, removedAt: Date) {
        self.id = id
        self.removedAt = removedAt
    }
}

extension Party {
    /// The party to save: members that changed since `stored` are stamped `now`, and members no longer in it
    /// are recorded as removed.
    func stampingMembers(against stored: Party?, at now: Date) -> Party {
        var party = self
        let before = Dictionary(stored?.members.map { ($0.id, $0) } ?? [], uniquingKeysWith: { first, _ in first })
        for index in party.members.indices {
            let member = party.members[index]
            if let old = before[member.id], member.isSame(as: old) { continue }
            party.members[index].modifiedAt = now
        }
        let present = Set(party.members.map(\.id))
        let removed = (stored?.members ?? []).filter { !present.contains($0.id) }
        party.removedMembers += removed.map { RemovedMember(id: $0.id, removedAt: now) }
        party.removedMembers.removeAll { present.contains($0.id) }
        return party
    }

    /// Two devices' edits of the same party: `newer`'s name, level and order, each member's latest version,
    /// members added on either side, and members removed on either side after their last edit left out.
    static func merging(newer: Party, older: Party) -> Party {
        var party = newer
        let removals = latestRemovals(newer.removedMembers + older.removedMembers)
        let olderMembers = Dictionary(older.members.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let newerIDs = Set(newer.members.map(\.id))
        let members = newer.members.map { member in olderMembers[member.id].map { member.merged(with: $0) } ?? member }
            + older.members.filter { !newerIDs.contains($0.id) }
        party.members = members.filter { member in removals[member.id].map { $0 < member.modifiedAt } ?? true }
        let kept = Set(party.members.map(\.id))
        party.removedMembers = removals.filter { !kept.contains($0.key) }
            .map { RemovedMember(id: $0.key, removedAt: $0.value) }
            .sorted { $0.id.uuidString < $1.id.uuidString }
        return party
    }

    private static func latestRemovals(_ removals: [RemovedMember]) -> [UUID: Date] {
        Dictionary(removals.map { ($0.id, $0.removedAt) }, uniquingKeysWith: max)
    }
}

extension PartyMember {
    /// Equal apart from when it last changed.
    func isSame(as other: PartyMember) -> Bool {
        var copy = self
        copy.modifiedAt = other.modifiedAt
        return copy == other
    }

    /// The later of two versions of this member (this one on a tie). A sheet fetched later on either side is
    /// kept, so a refresh on one device survives an edit on the other; a member unlinked on one side stays
    /// unlinked.
    func merged(with other: PartyMember) -> PartyMember {
        var member = other.modifiedAt > modifiedAt ? other : self
        let otherVersion = other.modifiedAt > modifiedAt ? self : other
        guard let link = member.link, let otherLink = otherVersion.link, otherLink.fetchedAt > link.fetchedAt else {
            return member
        }
        member.sheet = otherVersion.sheet
        member.link = otherLink
        member.level = otherVersion.level
        return member
    }
}
