import Bestiary
import Foundation

/// One strip of the initiative order as the players see it: no numbers, and for enemies only a health estimate.
public struct PlayerScreenLine: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var magnet: Magnet
    public var isActive: Bool
    public var isDelaying: Bool
    /// How hurt an enemy looks; nil for PCs, allies, and creatures without HP.
    public var health: HealthEstimate?
}

/// What the player screen shows of a fight: the initiative order, and the art of whoever is acting.
public struct PlayerScreenFight: Hashable, Sendable {
    public var lines: [PlayerScreenLine]
    /// The acting combatant's creature key, for its art; empty when nobody is acting or it has no key.
    public var activeKey: String
}

public extension CombatState {
    /// The fight for the player screen. `maxHitPoints` is a combatant's maximum HP, 0 when unknown.
    func playerScreen(maxHitPoints: (Combatant) -> Int) -> PlayerScreenFight {
        PlayerScreenFight(lines: playerScreenLines(maxHitPoints: maxHitPoints), activeKey: current?.creatureKey ?? "")
    }

    /// The ladder, top to bottom. Benched combatants aren't in the fight yet, so they're left out.
    private func playerScreenLines(maxHitPoints: (Combatant) -> Int) -> [PlayerScreenLine] {
        ladder.map { combatant in
            PlayerScreenLine(id: combatant.id, name: combatant.name, magnet: combatant.magnet,
                             isActive: combatant.id == currentID, isDelaying: combatant.isDelaying,
                             health: healthEstimate(of: combatant, maxHitPoints: maxHitPoints(combatant)))
        }
    }

    /// Dying counts as down, whatever its HP.
    private func healthEstimate(of combatant: Combatant, maxHitPoints: Int) -> HealthEstimate? {
        guard combatant.side == .enemy, combatant.tracksHitPoints, maxHitPoints > 0 else { return nil }
        if combatant.condition(ConditionSlug.dying) != nil { return .down }
        return HealthEstimate(hitPoints: maxHitPoints - combatant.damageTaken, maxHitPoints: maxHitPoints)
    }
}
