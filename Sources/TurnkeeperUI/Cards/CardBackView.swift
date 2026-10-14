import BattleCards
import Bestiary
import TurnkeeperKit
import SwiftUI

/// What the players see: the creature's card back on black, filling the screen.
struct CardBackView: View {
    let entry: BestiaryIndexEntry

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CreatureCardBack(entry: entry).padding(24)
        }
    }
}

/// The creature's art from the user's PDFs on a card back (Tabletop Kit's `CardBack`), with its name. The back of
/// a battle card, and what the player screen shows.
struct CreatureCardBack: View {
    let entry: BestiaryIndexEntry

    var body: some View {
        CardBack(name: entry.name, game: entry.game, traits: entry.traits.traits) {
            let path = entry.art.portrait.isEmpty ? entry.art.token : entry.art.portrait
            if !path.isEmpty { ArtPicture(path: path) }
        }
    }
}

extension View {
    /// What battle cards take from the app: the glossary for links, the card UI art and the creatures' art.
    func battleCardEnvironment(_ model: AppModel) -> some View {
        environment(\.glossary, GlossaryContext(bestiary: model.bestiary))
            .environment(\.cardArt, CardArtPieces(folder: model.bestiary.cardArtFolder))
            .environment(\.artPictureLoader, ArtPictureLoader { [model] path in
                await model.artPicture(for: path, maxPixels: 0)
            })
    }
}
