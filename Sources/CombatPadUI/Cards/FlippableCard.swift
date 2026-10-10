import Bestiary
import CombatPadKit
import SwiftUI

/// A battle card that turns over to show the GM its art, the same card back the players see, without
/// showing it to anyone. The flip button only appears when there's art to show.
struct FlippableCard<Front: View>: View {
    let entry: BestiaryIndexEntry?
    @Binding var isFlipped: Bool
    @ViewBuilder let front: () -> Front

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                front().opacity(isFlipped ? 0 : 1)
                if let entry, isFlipped {
                    CardBackView(entry: entry)
                        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                }
            }
            .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
            if entry != nil {
                Button(isFlipped ? "Show Stat Block" : "Flip Card",
                       systemImage: "arrow.triangle.2.circlepath.circle") {
                    withAnimation(.easeInOut(duration: 0.45)) { isFlipped.toggle() }
                }
                .labelStyle(.iconOnly)
                .font(.title)
                .symbolRenderingMode(.hierarchical)
                .buttonStyle(.borderless)
                .padding(8)
                .background(.ultraThinMaterial, in: Circle())
                .padding(6)
            }
        }
    }
}
