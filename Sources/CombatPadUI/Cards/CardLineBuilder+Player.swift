import CombatPadKit
import Foundation

/// The lines only a player character's card has: class and origin, class DC, feats and class features.
extension CardLineBuilder {
    func playerLines() -> [CardLine] {
        guard let player = presenter.creature.player else { return [] }
        var lines: [CardLine] = []
        let origin = [player.heritage.isEmpty ? player.ancestry : player.heritage, player.background]
            .filter { !$0.isEmpty }.joined(separator: ", ")
        if !player.className.isEmpty {
            let classLine: [CardSegment] = [.text(player.className)] + (origin.isEmpty ? [] : [.text(" (\(origin))")])
                + (player.classDC > 0 ? [.text("; "), .bold("Class DC "), .text("\(player.classDC)")] : [])
            lines.append(.labeled("Class", classLine))
        }
        lines += abilityNames("Feats", player.feats) + abilityNames("Class Features", player.classFeatures)
        return lines
    }

    private func abilityNames(_ label: String, _ names: [String]) -> [CardLine] {
        names.isEmpty ? [] : [.labeled(label, joined(names.map { [linked(.ability, $0, label: $0)] }))]
    }
}
