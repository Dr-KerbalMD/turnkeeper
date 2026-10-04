import CombatPadKit
import SwiftUI

/// What the players see: the creature's Battle Card back from the PDFs when there is one, otherwise a back
/// drawn in the same style around its portrait.
struct CardBackView: View {
    let entry: BestiaryIndexEntry

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if !entry.art.cardBack.isEmpty {
                FullArt(path: entry.art.cardBack)
                    .padding(24)
            } else if entry.game == .starfinder {
                StarfinderCardBack(entry: entry)
                    .aspectRatio(0.68, contentMode: .fit)
                    .padding(24)
            } else {
                PathfinderCardBack(entry: entry)
                    .aspectRatio(0.68, contentMode: .fit)
                    .padding(24)
            }
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
                Image(decorative: image, scale: 1).resizable().scaledToFit()
            } else {
                ProgressView()
            }
        }
        .task(id: path) {
            guard let url = model.artURL(for: path) else { return }
            image = await ArtLoader.shared.image(at: url, maxPixels: 0)
        }
    }
}

/// A Pathfinder Bestiary card back: a scorched parchment border around a deep red field with the portrait.
private struct PathfinderCardBack: View {
    let entry: BestiaryIndexEntry

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Parchment()
                RoundedRectangle(cornerRadius: 6)
                    .fill(RadialGradient(colors: [Color(hex: 0xA3201A), Color(hex: 0x4E0B08)], center: .center,
                                         startRadius: 20, endRadius: geometry.size.height * 0.6))
                    .padding(geometry.size.width * 0.07)
                FullArt(path: entry.art.portrait.isEmpty ? entry.art.token : entry.art.portrait)
                    .padding(geometry.size.width * 0.1)
                    .shadow(color: .black.opacity(0.5), radius: 12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color(hex: 0x6B4A2B), lineWidth: 4) }
        }
    }
}

/// A Starfinder card back: the portrait in a neon frame over a starfield, with a name plate below.
private struct StarfinderCardBack: View {
    let entry: BestiaryIndexEntry
    private let cyan = Color(hex: 0x27C8F2)

    var body: some View {
        ZStack {
            Starfield()
            VStack(spacing: 16) {
                FullArt(path: entry.art.portrait.isEmpty ? entry.art.token : entry.art.portrait)
                    .frame(maxHeight: .infinity)
                Text(entry.name.uppercased())
                    .font(.custom(FontName.condensedBold, size: 30))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(Color(hex: 0x0D3C47), in: BeveledRectangle(cut: 10))
                    .overlay { BeveledRectangle(cut: 10).stroke(cyan, lineWidth: 2) }
            }
            .padding(28)
        }
        .clipShape(BeveledRectangle(cut: 24))
        .overlay { BeveledRectangle(cut: 24).stroke(cyan, lineWidth: 3).shadow(color: cyan, radius: 8) }
    }
}
