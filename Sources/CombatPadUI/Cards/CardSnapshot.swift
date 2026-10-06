import CharacterImport
import CombatPadKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Renders battle cards to PNG, for checking their look against the printed cards.
public enum CardSnapshot {
    /// A PNG of a creature's card, or nil when the creature isn't in the bestiary. A key of `pdf=<path>`
    /// renders a player character from a Demiplane sheet PDF instead, linked to the glossary.
    @MainActor
    public static func png(
        key: String, template: CreatureTemplate = .normal, conditions: [AppliedCondition] = [], width: CGFloat = 560
    ) -> Data? {
        guard let directory = BestiaryStore.locateGeneratedDirectory(),
              let bestiary = try? BestiaryStore(generatedDirectory: directory),
              let creature = creature(key, bestiary: bestiary) else { return nil }
        Fonts.register(from: directory)
        let card = BattleCard(creature: creature, template: template, conditions: conditions, scrolls: false)
            .frame(width: width)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 2
        guard let image = renderer.cgImage else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    private static func creature(_ key: String, bestiary: BestiaryStore) -> Creature? {
        guard key.hasPrefix("pdf=") else { return bestiary.creature(key) }
        let url = URL(fileURLWithPath: String(key.dropFirst(4)))
        guard let data = try? Data(contentsOf: url),
              let sheet = try? DemiplaneSheetReader.sheet(fromPDF: data, game: nil) else { return nil }
        return CharacterGlossaryLinker(glossary: bestiary).link(sheet).sheet
    }
}
