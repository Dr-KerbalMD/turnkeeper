import BattleCards
import Bestiary
import SwiftUI

/// A battle card the GM can turn over to see the creature's art privately, the same card back the players see,
/// and show full screen (Tabletop Kit's `InteractiveBattleCard`). Without a bestiary entry it doesn't turn over.
struct CreatureBattleCard: View {
    let entry: BestiaryIndexEntry?
    let front: BattleCard

    var body: some View {
        if let entry {
            InteractiveBattleCard { front } back: { CreatureCardBack(entry: entry) }
        } else {
            InteractiveBattleCard { front }
        }
    }
}
