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
                // Smooth scaling: drawn backs often enlarge a 192 px token.
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

/// A Starfinder card back drawn after the printed Alien Archive backs: a teal field with scanlines inside a
/// glowing frame, edge tick marks, the token in a hexagon badge, the art large, and a silver name plate over
/// the game's logo line.
private struct StarfinderCardBack: View {
    let entry: BestiaryIndexEntry
    private let glow = Color(hex: 0x7FE3FF)

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack {
                ScanlineField()
                RoundedRectangle(cornerRadius: width * 0.04)
                    .strokeBorder(.white.opacity(0.9), lineWidth: max(1.5, width * 0.004))
                    .shadow(color: glow, radius: width * 0.015)
                    .padding(width * 0.055)
                TickMarks(width: width)
                VStack(spacing: width * 0.02) {
                    FullArt(path: entry.art.portrait.isEmpty ? entry.art.token : entry.art.portrait)
                        .padding(.horizontal, width * 0.04)
                        .padding(.top, width * 0.12)
                        .frame(maxHeight: .infinity)
                        .shadow(color: .black.opacity(0.45), radius: width * 0.02)
                    namePlate(width: width)
                    logoLine(width: width)
                }
                .padding(.bottom, width * 0.07)
                HexBadge(path: entry.art.token.isEmpty ? entry.art.portrait : entry.art.token, size: width * 0.11)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(width * 0.035)
            }
            .clipShape(RoundedRectangle(cornerRadius: width * 0.05))
        }
    }

    private func namePlate(width: CGFloat) -> some View {
        Text(entry.name.uppercased())
            .font(.custom(FontName.condensedBold, size: width * 0.05))
            .foregroundStyle(Color(hex: 0x1E2B30))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(.horizontal, width * 0.05)
            .padding(.vertical, width * 0.018)
            .frame(maxWidth: width * 0.78)
            .background(LinearGradient(colors: [Color(hex: 0xE4ECEE), Color(hex: 0x9FB0B6)], startPoint: .top,
                                       endPoint: .bottom), in: Capsule())
            .overlay { Capsule().strokeBorder(.white, lineWidth: max(1.5, width * 0.005)) }
            .shadow(color: glow.opacity(0.8), radius: width * 0.012)
    }

    private func logoLine(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            Text("STARFINDER")
                .font(.custom(FontName.condensedBold, size: width * 0.04))
                .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFB347), Color(hex: 0xE0661B)],
                                                startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.6), radius: 1)
            Text("SECOND EDITION")
                .font(.custom(FontName.condensedBold, size: width * 0.025))
                .foregroundStyle(.white)
        }
    }
}

/// The printed backs' teal field: darker at the edges, with fine horizontal scanlines.
private struct ScanlineField: View {
    var body: some View {
        ZStack {
            RadialGradient(colors: [Color(hex: 0x2A8FA8), Color(hex: 0x135A6E), Color(hex: 0x08303C)],
                           center: .center, startRadius: 10, endRadius: 700)
            Canvas { context, size in
                for line in stride(from: 0.0, to: size.height, by: 4) {
                    context.fill(Path(CGRect(x: 0, y: line, width: size.width, height: 1.2)),
                                 with: .color(.black.opacity(0.18)))
                }
            }
        }
    }
}

/// The rows of small bars on the printed backs' edges: low on the left, high on the right.
private struct TickMarks: View {
    let width: CGFloat

    var body: some View {
        Canvas { context, size in
            let bar = CGSize(width: width * 0.022, height: width * 0.009)
            for index in 0..<14 {
                let step = CGFloat(index) * bar.height * 2
                let left = CGRect(x: width * 0.012, y: size.height * 0.57 + step, width: bar.width, height: bar.height)
                let right = CGRect(x: size.width - width * 0.012 - bar.width, y: size.height * 0.14 + step,
                                   width: bar.width, height: bar.height)
                context.fill(Path(left), with: .color(.white.opacity(0.55)))
                context.fill(Path(right), with: .color(.white.opacity(0.55)))
            }
        }
        .allowsHitTesting(false)
    }
}

/// The token in a white-edged hexagon, as in the printed backs' top-left corner.
private struct HexBadge: View {
    let path: String
    let size: CGFloat

    var body: some View {
        ZStack {
            Hexagon().fill(Color(hex: 0x0B2A33))
            ArtImage(path: path, size: size * 0.8, shape: .circle, alignment: .top)
                .clipShape(Hexagon())
            Hexagon().stroke(.white, lineWidth: max(1.5, size * 0.06))
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.5), radius: 3)
    }
}

/// A flat-sided hexagon with points at left and right.
private struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        let inset = rect.width * 0.25
        return Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX + inset, y: rect.minY + rect.height * 0.07))
            path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY + rect.height * 0.07))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - rect.height * 0.07))
            path.addLine(to: CGPoint(x: rect.minX + inset, y: rect.maxY - rect.height * 0.07))
            path.closeSubpath()
        }
    }
}
