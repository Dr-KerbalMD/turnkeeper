import Bestiary
import CombatPadKit
import SwiftUI

/// The fight as the players see it: the initiative order on one half, the acting combatant's art on the other.
/// Enemies show how hurt they look; nothing shows a stat block or a number.
struct PlayerScreenLayout: View {
    let fight: PlayerScreenFight
    @Environment(AppModel.self) private var model

    var body: some View {
        GeometryReader { geometry in
            let layout = geometry.size.width >= geometry.size.height
                ? AnyLayout(HStackLayout(spacing: 32)) : AnyLayout(VStackLayout(spacing: 32))
            layout {
                PlayerOrder(lines: fight.lines).frame(maxWidth: .infinity, maxHeight: .infinity)
                activeArt.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(32)
    }

    @ViewBuilder
    private var activeArt: some View {
        if let entry = model.entry(fight.activeKey) {
            CreatureCardBack(entry: entry).id(fight.activeKey).transition(.opacity)
        }
    }
}

/// The initiative order, top to bottom, the acting strip outlined and delaying strips shifted right, as on the
/// GM's ladder.
private struct PlayerOrder: View {
    let lines: [PlayerScreenLine]

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(lines) { line in
                    PlayerStrip(line: line)
                        .opacity(line.isDelaying ? 0.7 : 1)
                        .padding(.leading, line.isDelaying ? 32 : 0)
                }
            }
        }
        .scrollIndicators(.hidden)
        .animation(.easeInOut, value: lines)
    }
}

private struct PlayerStrip: View {
    let line: PlayerScreenLine

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: line.isDelaying ? "hourglass" : "arrowtriangle.right.fill")
                .foregroundStyle(.yellow)
                .opacity(line.isActive || line.isDelaying ? 1 : 0)
            Text(line.name).font(.title2.bold()).lineLimit(1).minimumScaleFactor(0.6)
            Spacer(minLength: 8)
            if let health = line.health {
                Text(health.label)
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(health.color, in: Capsule())
                    .overlay { Capsule().strokeBorder(.white.opacity(0.5)) }
            }
        }
        .foregroundStyle(.white)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(line.magnet.color, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            if line.isActive { RoundedRectangle(cornerRadius: 10).stroke(.yellow, lineWidth: 4) }
        }
    }
}

extension HealthEstimate {
    /// Green when unharmed, through yellow and orange, to black when down.
    var color: Color {
        switch self {
        case .unharmed: Color(hex: 0x1F6E3A)
        case .healthy: Color(hex: 0x5B8A2E)
        case .injured: Color(hex: 0xA07A12)
        case .bloodied: Color(hex: 0xB35A12)
        case .nearDeath: Color(hex: 0x8E1B1B)
        case .down: .black
        }
    }
}
