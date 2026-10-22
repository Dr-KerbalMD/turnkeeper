import Bestiary
import Foundation

/// Builds the opening state of a fight from a planned encounter variant and a party.
public enum CombatSetup {
    /// PCs and creatures on the ladder (or bench), numbered when there are several of a kind, with the
    /// variant's events. Nobody has initiative yet; the state starts in setup.
    public static func state(
        for variant: EncounterVariant, party: Party?, lookup: (String) -> BestiaryIndexEntry?
    ) -> CombatState {
        let pcs = (party?.members ?? []).map { member -> Combatant in
            let key = member.sheet == nil ? "" : PlayerCharacter.key(for: member)
            var pc = Combatant(kind: .playerCharacter, name: member.name, creatureKey: key)
            pc.playerName = member.playerName
            if member.isAway { pc.place = .bench }  // A late arrival is brought in from the bench.
            return pc
        }
        let creatures = combatants(for: variant.slots, lookup: lookup)
        return CombatState(combatants: pcs + creatures, events: variant.events.filter(\.isEnabled))
    }

    private static func combatants(
        for slots: [EncounterSlot], lookup: (String) -> BestiaryIndexEntry?
    ) -> [Combatant] {
        let totals = Dictionary(grouping: slots, by: { baseName($0, lookup: lookup) })
            .mapValues { $0.reduce(0) { $0 + max($1.count, 1) } }
        var used: [String: Int] = [:]
        return slots.flatMap { slot -> [Combatant] in
            let name = baseName(slot, lookup: lookup)
            return (0..<max(slot.count, 1)).map { _ in
                used[name, default: 0] += 1
                let numbered = totals[name, default: 1] > 1 ? "\(name) \(used[name, default: 1])" : name
                return combatant(for: slot, named: numbered, entry: lookup(slot.creatureKey))
            }
        }
    }

    private static func baseName(_ slot: EncounterSlot, lookup: (String) -> BestiaryIndexEntry?) -> String {
        lookup(slot.creatureKey)?.name ?? "Unknown creature"
    }

    private static func combatant(
        for slot: EncounterSlot, named name: String, entry: BestiaryIndexEntry?
    ) -> Combatant {
        let kind: CombatantKind = entry?.kind == .hazard ? .hazard : .creature
        var combatant = Combatant(kind: kind, name: name, side: slot.side, creatureKey: slot.creatureKey)
        combatant.slotID = slot.id
        combatant.template = slot.template
        combatant.place = slot.startsOnBench ? .bench : .ladder
        combatant.temporaryHitPoints = slot.temporaryHitPoints
        // Each creature gets its own copies, so removing one creature's condition leaves the others'.
        combatant.conditions = slot.conditions.map { condition in
            var copy = condition
            copy.id = UUID()
            return copy
        }
        return combatant
    }

    /// d20 plus the modifier.
    public static func rollInitiative<Generator: RandomNumberGenerator>(
        modifier: Int, using generator: inout Generator
    ) -> Double {
        Double(Int.random(in: 1...20, using: &generator) + modifier)
    }
}

public extension EncounterBudget {
    /// The XP of a variant's enemies at their template-adjusted levels. Benched creatures count, since
    /// they're expected to join; allies don't.
    func experience(of variant: EncounterVariant, lookup: (String) -> BestiaryIndexEntry?) -> Int {
        variant.slots.filter { $0.side == .enemy }.reduce(0) { total, slot in
            let baseLevel = lookup(slot.creatureKey)?.level ?? partyLevel
            return total + experience(forLevel: slot.template.level(base: baseLevel)) * max(slot.count, 1)
        }
    }
}
