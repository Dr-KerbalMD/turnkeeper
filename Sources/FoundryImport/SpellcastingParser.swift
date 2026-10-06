import CombatPadKit
import Foundation

/// Groups `spell` items under their `spellcastingEntry`, by rank, as the stat block lists them.
enum SpellcastingParser {
    static func entries(_ items: [JSONValue], creatureLevel: Int) -> [Spellcasting] {
        let spells = items.filter { $0["type"].string == "spell" }
        return items.filter { $0["type"].string == "spellcastingEntry" }.map { entry in
            let entrySpells = spells.filter { $0[path: "system.location.value"].string == entry["_id"].string }
            let system = entry["system"]
            let cantripRank = system[path: "autoHeightenLevel.value"].optionalInt ?? max(1, (creatureLevel + 1) / 2)
            let ranks = system[path: "prepared.value"].string == "prepared"
                ? preparedRanks(system["slots"], spells: entrySpells, cantripRank: cantripRank)
                : listedRanks(entrySpells, slots: system["slots"], cantripRank: cantripRank)
            return Spellcasting(
                name: entry["name"].string,
                difficultyClass: system[path: "spelldc.dc"].int,
                attack: system[path: "spelldc.value"].int,
                ranks: ranks
            )
        }
    }

    /// Innate, spontaneous and focus spells: each spell sits at its own (heightened) rank.
    private static func listedRanks(_ spells: [JSONValue], slots: JSONValue, cantripRank: Int) -> [SpellRank] {
        var groups: [GroupKey: [SpellEntry]] = [:]
        for spell in spells {
            let parsed = nameAndKind(spell)
            let rank = parsed.kind == .cantrips ? cantripRank : spellRank(spell)
            groups[GroupKey(kind: parsed.kind, rank: rank), default: []].append(parsed.entry)
        }
        return sorted(groups).map { key, entries in
            let slotCount = slots["slot\(key.rank)"]["max"].int
            let note = key.kind == .ranked && slotCount > 0 ? "\(slotCount) slots" : ""
            return SpellRank(kind: key.kind, rank: key.rank, spells: entries, note: note)
        }
    }

    /// Prepared spells: the slots list which spells are prepared at each rank, with repeats.
    private static func preparedRanks(_ slots: JSONValue, spells: [JSONValue], cantripRank: Int) -> [SpellRank] {
        let byID = Dictionary(spells.map { ($0["_id"].string, $0) }, uniquingKeysWith: { first, _ in first })
        var groups: [GroupKey: [SpellEntry]] = [:]
        for slotRank in 0...10 {
            let ids = slots["slot\(slotRank)"]["prepared"].array.map { $0["id"].string }.filter { byID[$0] != nil }
            guard !ids.isEmpty else { continue }
            let key = slotRank == 0
                ? GroupKey(kind: .cantrips, rank: cantripRank)
                : GroupKey(kind: .ranked, rank: slotRank)
            groups[key] = countedEntries(ids.compactMap { byID[$0] })
        }
        return sorted(groups).map { SpellRank(kind: $0.key.kind, rank: $0.key.rank, spells: $0.value) }
    }

    private static func countedEntries(_ spells: [JSONValue]) -> [SpellEntry] {
        var order: [String] = []
        var counts: [String: Int] = [:]
        for spell in spells {
            let name = nameAndKind(spell).entry.name
            if counts[name] == nil { order.append(name) }
            counts[name, default: 0] += 1
        }
        return order.map { SpellEntry(name: $0, note: counts[$0, default: 1] > 1 ? "×\(counts[$0, default: 1])" : "") }
    }

    private struct GroupKey: Hashable {
        var kind: SpellRank.Kind
        var rank: Int
    }

    /// Ranked spells from highest to lowest, then cantrips, then constant spells.
    private static func sorted(_ groups: [GroupKey: [SpellEntry]]) -> [(key: GroupKey, value: [SpellEntry])] {
        let order: [SpellRank.Kind: Int] = [.ranked: 0, .cantrips: 1, .constant: 2]
        return groups.sorted { left, right in
            let leftOrder = order[left.key.kind, default: 0]
            let rightOrder = order[right.key.kind, default: 0]
            return leftOrder != rightOrder ? leftOrder < rightOrder : left.key.rank > right.key.rank
        }
    }

    private static func spellRank(_ spell: JSONValue) -> Int {
        spell[path: "system.location.heightenedLevel"].optionalInt ?? spell[path: "system.level.value"].int
    }

    /// Strips "(Constant)" and "(At Will)" from the name and turns them into the group or note.
    /// The spell's name as the card lists it, such as "detect magic".
    static func listedName(_ spell: JSONValue) -> String {
        nameAndKind(spell).entry.name
    }

    private static func nameAndKind(_ spell: JSONValue) -> (entry: SpellEntry, kind: SpellRank.Kind) {
        var name = spell["name"].string
        var kind: SpellRank.Kind = spell[path: "system.traits.value"].strings.contains("cantrip") ? .cantrips : .ranked
        var notes: [String] = []
        if name.hasSuffix("(Constant)") {
            kind = .constant
            name = String(name.dropLast("(Constant)".count))
        }
        if name.hasSuffix("(At Will)") {
            notes.append("at will")
            name = String(name.dropLast("(At Will)".count))
        }
        let uses = spell[path: "system.location.uses.max"].int
        if uses > 1 { notes.append("×\(uses)") }
        let entry = SpellEntry(
            name: name.trimmingCharacters(in: .whitespaces).lowercased(), note: notes.joined(separator: ", ")
        )
        return (entry, kind)
    }
}
