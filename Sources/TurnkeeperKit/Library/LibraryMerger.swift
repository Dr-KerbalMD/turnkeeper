import CryptoKit
import Foundation

/// What a merge did, to tell the GM.
public struct MergeSummary: Sendable, Equatable {
    public var added = 0
    public var updated = 0
    public var deleted = 0
    /// Records changed on both sides; the newer won and the other was kept as a copy.
    public var conflicts = 0

    public init() {}

    public var changedAnything: Bool { added + updated + deleted + conflicts > 0 }
}

/// Merges another device's library into this one, record by record.
///
/// - When one side's version is one the other side has already shared, only the other side changed it, and
///   that change wins.
/// - When both sides changed it, the newer change wins. For scenarios and encounters the other version
///   is kept as a "conflict copy", so no planning is lost silently. Both devices make the same copy, so it
///   comes across only once. Parties are merged member by member, so players edited, added or removed on
///   either device all carry across.
/// - Deletions are tombstones, so they carry across like any other change.
public enum LibraryMerger {
    public static func merge(_ incoming: Library, into local: inout Library) -> MergeSummary {
        var summary = MergeSummary()
        merge(incoming.campaigns, into: &local.campaigns, summary: &summary)
        merge(incoming.parties, into: &local.parties, summary: &summary, combine: Party.merging(newer:older:))
        merge(incoming.scenarios, into: &local.scenarios, summary: &summary, copy: conflictCopy)
        merge(incoming.encounters, into: &local.encounters, summary: &summary, copy: conflictCopy)
        merge(incoming.sessions, into: &local.sessions, summary: &summary)
        merge(incoming.customCreatures, into: &local.customCreatures, summary: &summary)
        merge(incoming.customArt, into: &local.customArt, summary: &summary)
        merge(incoming.handouts, into: &local.handouts, summary: &summary)
        merge(incoming.creatureNotes, into: &local.creatureNotes, summary: &summary)
        return summary
    }

    private static func merge<Record: LibraryRecord>(
        _ incoming: [Record], into local: inout [Record], summary: inout MergeSummary,
        copy: ((Record) -> Record)? = nil, combine: ((_ newer: Record, _ older: Record) -> Record)? = nil
    ) {
        for theirs in incoming {
            guard let index = local.firstIndex(where: { $0.id == theirs.id }) else {
                local.append(theirs.received(alongside: nil))
                if !theirs.isDeleted { summary.added += 1 }
                continue
            }
            let ours = local[index]
            guard theirs.modifiedAt != ours.modifiedAt else {
                local[index] = ours.received(alongside: theirs)
                continue
            }
            let oursUnchanged = theirs.hasShared(ours.modifiedAt)
            let theirsUnchanged = ours.hasShared(theirs.modifiedAt)
            let theirsWins = oursUnchanged || (!theirsUnchanged && theirs.modifiedAt > ours.modifiedAt)
            let (winner, loser) = theirsWins ? (theirs, ours) : (ours, theirs)
            let bothChanged = !oursUnchanged && !theirsUnchanged && !theirs.isDeleted && !ours.isDeleted
            if bothChanged, let combine {
                local[index] = combine(winner, loser).received(alongside: loser)
                summary.updated += 1
                continue
            }
            if bothChanged, let copy {
                local.append(copy(loser))
                summary.conflicts += 1
            }
            local[index] = winner.received(alongside: loser)
            guard theirsWins else { continue }
            if theirs.isDeleted { summary.deleted += 1 } else { summary.updated += 1 }
        }
    }

    private static func conflictCopy(_ scenario: Scenario) -> Scenario {
        var copy = scenario
        copy.id = conflictCopyID(of: scenario)
        copy.name += " (conflict copy)"
        copy.sharedVersion = nil
        copy.sharedVersions = nil
        return copy
    }

    private static func conflictCopy(_ encounter: Encounter) -> Encounter {
        var copy = encounter
        copy.id = conflictCopyID(of: encounter)
        copy.name += " (conflict copy)"
        copy.sharedVersion = nil
        copy.sharedVersions = nil
        return copy
    }

    /// The same ID on both devices for the copy of one version, so the two copies a sync makes are one record.
    static func conflictCopyID(of record: some LibraryRecord) -> UUID {
        let seed = "\(record.id.uuidString) \(record.modifiedAt.timeIntervalSinceReferenceDate)"
        var bytes = Array(SHA256.hash(data: Data(seed.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}

extension LibraryRecord {
    /// The most versions a record remembers sharing; older ones belong to syncs long past.
    static var sharedVersionLimit: Int { 32 }

    /// Whether this record has sent or received the version stamped `version`, so it's an earlier version of
    /// this one.
    func hasShared(_ version: Date) -> Bool {
        sharedVersion == version || (sharedVersions ?? []).contains(version)
    }

    /// This record as the merge keeps it: both devices now have it, so it remembers its own version, the other
    /// device's, and every version either side had shared.
    func received(alongside other: Self?) -> Self {
        var record = self
        var versions = Set(sharedVersions ?? []).union([modifiedAt])
        if let other {
            versions.formUnion(other.sharedVersions ?? [])
            versions.insert(other.modifiedAt)
        }
        record.sharedVersion = modifiedAt
        record.sharedVersions = Array(versions.sorted().suffix(Self.sharedVersionLimit))
        return record
    }

    /// This record about to be sent to another device: it remembers its version as shared.
    func sending() -> Self {
        guard !hasShared(modifiedAt) else { return self }
        var record = self
        record.sharedVersions = Array(((sharedVersions ?? []) + [modifiedAt]).sorted().suffix(Self.sharedVersionLimit))
        return record
    }
}
