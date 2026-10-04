import CombatPadKit
import SwiftUI

/// A battle card in the look of the Starfinder Alien Archive Battle Cards: a teal holo-panel in a glowing
/// cyan frame over a starfield, a black title bar, and DEFENSE, OFFENSE, STATISTICS and SPECIAL ABILITIES
/// sections, holding second-edition stats.
struct StarfinderBattleCard: View {
    let content: CardContent
    var textSize: CGFloat = 15
    /// Off for snapshots, which need the whole card laid out at once.
    var scrolls = true
    private let cyan = Color(hex: 0x27C8F2)

    var body: some View {
        ZStack {
            Starfield()
            Scrollable(scrolls: scrolls) {
                VStack(alignment: .leading, spacing: 4) {
                    titleBar
                    TraitChips(traits: content.traits, game: .starfinder)
                    lines(content.hazard)
                    lines(content.senses)
                    section("DEFENSE", trailing: content.hitPoints, content.defense + content.defensive)
                    section("OFFENSE", content.offense + content.offensive)
                    section("STATISTICS", content.statistics)
                    section("SPECIAL ABILITIES", content.interaction)
                    SourceLine(text: content.source, color: Color(hex: 0x9FC7D2, opacity: 0.7))
                }
                .padding(18)
            }
            .background(Color(hex: 0x0D3C47, opacity: 0.88), in: BeveledRectangle(cut: 14))
            .overlay {
                BeveledRectangle(cut: 14).stroke(cyan, lineWidth: 2).shadow(color: cyan.opacity(0.9), radius: 6)
            }
            .padding(10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var titleBar: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(content.name.uppercased())
            Spacer(minLength: 8)
            TemplateBadge(template: content.template, color: Color(hex: 0x0B6E85))
            Text(content.levelLabel)
        }
        .font(.custom(FontName.condensedBold, size: textSize * 1.6))
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.black)
    }

    @ViewBuilder
    private func section(_ title: String, trailing: [CardSegment] = [], _ lines: [CardLine]) -> some View {
        if !lines.isEmpty || !trailing.isEmpty {
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(.custom(FontName.condensedBold, size: textSize * 1.15))
                    Spacer()
                    if !trailing.isEmpty { CardLineView(line: CardLine(trailing), style: style).fixedSize() }
                }
                .foregroundStyle(.white)
                Rectangle().fill(.white).frame(height: 1)
            }
            .padding(.top, 6)
            self.lines(lines)
        }
    }

    private func lines(_ lines: [CardLine]) -> some View {
        ForEach(lines) { CardLineView(line: $0, style: style) }
    }

    private var style: CardTextStyle {
        CardTextStyle(body: FontName.body, bold: FontName.bodyBold, italic: FontName.bodyItalic, size: textSize * 0.92,
                      ink: Color(hex: 0xEAF7FB), worse: Color(hex: 0xFF6B6B), better: Color(hex: 0x7CFC9A))
    }
}

/// A rectangle with its corners cut at 45 degrees, like the Starfinder card frames.
struct BeveledRectangle: Shape {
    var cut: CGFloat

    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut))
            path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + cut, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cut))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut))
            path.closeSubpath()
        }
    }
}

/// Deep space with scattered stars, drawn the same way every time.
struct Starfield: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0x030B14)))
            var generator = SeededGenerator(seed: 7)
            for _ in 0..<Int(size.width * size.height / 900) {
                let point = CGPoint(x: .random(in: 0...size.width, using: &generator),
                                    y: .random(in: 0...size.height, using: &generator))
                let radius = CGFloat.random(in: 0.3...1.3, using: &generator)
                let brightness = Double.random(in: 0.3...1, using: &generator)
                context.fill(Path(ellipseIn: CGRect(x: point.x, y: point.y, width: radius * 2, height: radius * 2)),
                             with: .color(.white.opacity(brightness)))
            }
        }
    }
}

/// A small deterministic random generator, so the starfield doesn't flicker between redraws.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &* 0x9E37_79B9_7F4A_7C15
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state ^ (state >> 33)
    }
}
