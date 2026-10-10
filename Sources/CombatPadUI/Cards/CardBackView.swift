import BattleCards
import Bestiary
import CombatPadKit
import SwiftUI

/// What the players see: the creature's art from the user's PDFs on a card back (Tabletop Kit's `CardBack`), with
/// its name.
struct CardBackView: View {
    let entry: BestiaryIndexEntry

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CardBack(name: entry.name, game: entry.game, traits: entry.traits.traits) {
                let path = entry.art.portrait.isEmpty ? entry.art.token : entry.art.portrait
                if !path.isEmpty { FullArt(path: path) }
            }
            .padding(24)
        }
    }
}

/// An image at full resolution, fitted to the space.
private struct FullArt: View {
    let path: String
    @Environment(AppModel.self) private var model
    @State private var image: CGImage?

    var body: some View {
        Group {
            if let image {
                // Smooth scaling: a small token's art may be enlarged.
                Image(decorative: image, scale: 1).resizable().interpolation(.high).scaledToFit()
            } else {
                ProgressView()
            }
        }
        .task(id: path) {
            image = await model.artPicture(for: path, maxPixels: 0)
        }
    }
}

/// A Pathfinder Bestiary card back: a scorched parchment border around a deep red field with the portrait.
