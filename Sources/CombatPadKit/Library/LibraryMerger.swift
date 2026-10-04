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
/// - When only one side changed a record since they last shared it, that change wins.
/// - When both sides changed it, the newer change wins. For scenarios and encounters the other version
///   is kept as a "conflict copy", so no planning is lost silently.
/// - Deletions are tombstones, so they carry across like any other change.
public enum LibraryMerger {
    public static func merge(_ incoming: Library, into local: inout Library) -> MergeSummary {
        var summary = MergeSummary()
        merge(incoming.campaigns, into: &local.campaigns, summary: &summary)
        merge(incoming.parties, into: &local.parties, summary: &summary)
        merge(incoming.scenarios, into: &local.scenarios, summary: &summary, copy: conflictCopy)
        merge(incoming.encounters, into: &local.encounters, summary: &summary, copy: conflictCopy)
        merge(incoming.sessions, into: &local.sessions, summary: &summary)
        merge(incoming.customCreatures, into: &local.customCreatures, summary: &summary)
        return summary
    }

    private static func merge<Record: LibraryRecord>(
        _ incoming: [Record], into local: inout [Record], summary: inout MergeSummary,
        copy: ((Record) -> Record)? = nil
    ) {
        for theirs in incoming {
            guard let index = local.firstIndex(where: { $0.id == theirs.id }) else {
                local.append(shared(theirs))
                if !theirs.isDeleted { summary.added += 1 }
                continue
            }
            let ours = local[index]
            guard theirs.modifiedAt != ours.modifiedAt else { continue }
            let oursUnchanged = theirs.sharedVersion == ours.modifiedAt
            let theirsUnchanged = ours.sharedVersion == theirs.modifiedAt
            let theirsWins = oursUnchanged || (!theirsUnchanged && theirs.modifiedAt > ours.modifiedAt)
            if !oursUnchanged && !theirsUnchanged, let copy, !theirs.isDeleted, !ours.isDeleted {
                local.append(copy(theirsWins ? ours : theirs))
                summary.conflicts += 1
            }
            guard theirsWins else { continue }
            local[index] = shared(theirs)
            if theirs.isDeleted { summary.deleted += 1 } else { summary.updated += 1 }
        }
    }

    /// A record received from the other device: both sides now have this version.
    private static func shared<Record: LibraryRecord>(_ record: Record) -> Record {
        var received = record
        received.sharedVersion = record.modifiedAt
        return received
    }

    private static func conflictCopy(_ scenario: Scenario) -> Scenario {
        var copy = scenario
        copy.id = UUID()
        copy.name += " (conflict copy)"
        copy.sharedVersion = nil
        return copy
    }

    private static func conflictCopy(_ encounter: Encounter) -> Encounter {
        var copy = encounter
        copy.id = UUID()
        copy.name += " (conflict copy)"
        copy.sharedVersion = nil
        return copy
    }
}
