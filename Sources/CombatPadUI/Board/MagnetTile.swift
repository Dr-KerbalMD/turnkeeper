import CombatPadKit
import SwiftUI

/// One combatant's magnet: initiative, token, name, HP and condition chips, colored like the paper pad's
/// magnets. Tap to show its card; drag to reorder once combat has begun; during setup, press and hold to say
/// its initiative.
struct MagnetTile: View {
    let controller: BoardController
    let combatant: Combatant
    @Binding var sheet: BoardSheet?
    @State private var voice = VoiceInitiative.shared
    @State private var shakes = 0

    private var isCurrent: Bool { controller.state.currentID == combatant.id }
    private var isSetup: Bool { controller.state.phase == .setup }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrowtriangle.right.fill")
                .foregroundStyle(.yellow)
                .opacity(isCurrent ? 1 : 0)
            initiativeBadge
            ArtImage(path: tileArt, size: 46, shape: .circle, alignment: .top)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(combatant.name).font(.headline).lineLimit(2).minimumScaleFactor(0.8)
                    if combatant.template != .normal { TemplateBadge(template: combatant.template, color: .black) }
                }
                ConditionChips(combatant: combatant) { sheet = .conditions(combatant.id) }
            }
            Spacer(minLength: 4)
            if combatant.tracksHitPoints { hitPoints }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .foregroundStyle(.white)
        .background(background)
        .overlay { if isListening { RoundedRectangle(cornerRadius: 10).stroke(.yellow, lineWidth: 3) } }
        .modifier(Shake(shakes: shakes))
        .contentShape(Rectangle())
        .onTapGesture { controller.pinnedID = combatant.id }
        .contextMenu { TileMenu(controller: controller, combatant: combatant, sheet: $sheet) }
        .modifier(SetupVoiceGesture(isEnabled: isSetup && voice.isAvailable, onPress: startListening,
                                    onRelease: stopListening))
        .modifier(DraggableUnlessSetup(id: combatant.id, isSetup: isSetup))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    private var tileArt: String { controller.entry(for: combatant)?.art.thumbnail ?? "" }

    private var isListening: Bool { voice.listeningFor == combatant.id }

    private var initiativeBadge: some View {
        Button { sheet = .initiative(combatant.id) } label: {
            Text(combatant.initiative.map(InitiativeText.format) ?? "–")
                .font(.title3.monospacedDigit().bold())
                .frame(minWidth: 40)
                .padding(.vertical, 4)
                .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help("Initiative")
    }

    private var hitPoints: some View {
        let maximum = max(controller.maxHitPoints(of: combatant), 1)
        let current = max(maximum - combatant.damageTaken, 0)
        return Button { sheet = .hitPoints(combatant.id) } label: {
            VStack(alignment: .trailing, spacing: 3) {
                let temporary = combatant.temporaryHitPoints > 0 ? " +\(combatant.temporaryHitPoints)" : ""
                Text("\(current)/\(maximum)\(temporary)")
                    .font(.callout.monospacedDigit().bold())
                ProgressView(value: Double(current), total: Double(maximum))
                    .tint(current * 4 <= maximum ? .red : .green)
                    .frame(width: 80)
            }
        }
        .buttonStyle(.plain)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(combatant.magnet.color.gradient)
            .overlay {
                if isCurrent { RoundedRectangle(cornerRadius: 10).stroke(.yellow, lineWidth: 2) }
            }
            .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
    }

    private func startListening() {
        voice.listen(for: combatant.id)
    }

    private func stopListening() {
        let transcript = voice.stop()
        if let value = SpokenNumberParser.initiative(from: transcript) {
            controller.change { $0.setInitiative(value, for: combatant.id) }
        } else {
            shakes += 1
            sheet = .initiative(combatant.id)
        }
    }
}

enum InitiativeText {
    /// "17", or "17½" for a tie-breaking half.
    static func format(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : "\(Int(value.rounded(.down)))½"
    }
}

/// Lets strips be dragged to reorder, except during setup, when pressing and holding means "listen".
private struct DraggableUnlessSetup: ViewModifier {
    let id: UUID
    let isSetup: Bool

    func body(content: Content) -> some View {
        if isSetup { content } else { content.draggable(id.uuidString) }
    }
}

/// Press and hold to listen; let go to stop. Only during setup.
private struct SetupVoiceGesture: ViewModifier {
    let isEnabled: Bool
    let onPress: () -> Void
    let onRelease: () -> Void
    @State private var isPressing = false

    func body(content: Content) -> some View {
        if isEnabled {
            content.onLongPressGesture(minimumDuration: 0.25) {} onPressingChanged: { pressing in
                if pressing {
                    isPressing = true
                    onPress()
                } else if isPressing {
                    isPressing = false
                    onRelease()
                }
            }
        } else {
            content
        }
    }
}

/// A short side-to-side shake, for when no number was heard.
private struct Shake: GeometryEffect {
    var shakes: Int
    var animatableData: CGFloat

    init(shakes: Int) {
        self.shakes = shakes
        animatableData = CGFloat(shakes)
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(animatableData * .pi * 4), y: 0))
    }
}
