import CombatPadKit
import Foundation

/// Lends art between creatures of the same name and game: a scenario's Skeleton Guard without art borrows
/// the Monster Core one's. Each kind (portrait, token, card back) is filled only where it is missing, from
/// the creature with the most art, preferring remastered ones on ties.
enum ArtFallback {
    /// Fills the gaps and returns "Name (pack) ← donor pack" for each creature that borrowed something.
    static func borrow(into creatures: inout [Creature]) -> [String] {
        let donors = Dictionary(grouping: creatures.indices.filter { creatures[$0].art.hasArt }) { index in
            key(creatures[index])
        }
        .compactMapValues { indices in indices.max { rank(creatures[$0]) < rank(creatures[$1]) } }
        var borrowed: [String] = []
        for index in creatures.indices {
            guard let donor = donors[key(creatures[index])], donor != index else { continue }
            let before = creatures[index].art
            creatures[index].art = filled(before, from: creatures[donor].art)
            if creatures[index].art != before {
                borrowed.append("\(creatures[index].name) (\(creatures[index].source.pack)) ← "
                                + creatures[donor].source.pack)
            }
        }
        return borrowed
    }

    private static func key(_ creature: Creature) -> String {
        "\(creature.game.rawValue)|\(creature.name.lowercased().trimmingCharacters(in: .whitespaces))"
    }

    /// More kinds of art first, then remastered.
    private static func rank(_ creature: Creature) -> (Int, Int) {
        let art = creature.art
        let kinds = [art.portrait, art.token, art.cardBack].filter { !$0.isEmpty }.count
        return (kinds, creature.source.isRemastered ? 1 : 0)
    }

    private static func filled(_ art: ArtReference, from donor: ArtReference) -> ArtReference {
        var art = art
        if art.portrait.isEmpty { art.portrait = donor.portrait }
        if art.token.isEmpty { art.token = donor.token }
        if art.cardBack.isEmpty { art.cardBack = donor.cardBack }
        return art
    }
}
