import BattleCards
import SwiftUI

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
