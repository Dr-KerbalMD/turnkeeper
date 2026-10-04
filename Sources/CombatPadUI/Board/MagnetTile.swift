import CombatPadKit
import SwiftUI

/// One combatant's magnet: initiative, token, name, HP and condition chips, colored like the paper pad's
/// magnets. Tap to show its card, long-press for its menu, drag to reorder once combat has begun. During
/// setup, a microphone button next to the initiative listens while held.
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
            if isSetup && voice.isAvailable {
                MicButton(isListening: isListening, onPress: startListening, onRelease: stopListening)
            }
            ArtImage(path: tileArt, size: 46, shape: .circle, alignment: .top)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(combatant.name).font(.headline).lineLimit(2).minimumScaleFactor(0.8)
                    if combatant.template != .normal { TemplateBadge(template: combatant.template, color: .black) }
                }
                if isSetup && combatant.initiative == nil, let hint = modifierHint {
                    Text(hint).font(.caption.bold()).opacity(0.85)
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
        .overlay {
            if isMissingInitiative { RoundedRectangle(cornerRadius: 10).stroke(.orange, style: missingStyle) }
        }
        .modifier(Shake(shakes: shakes))
        .contentShape(Rectangle())
        .onTapGesture { controller.pinnedID = combatant.id }
        .contextMenu { TileMenu(controller: controller, combatant: combatant, sheet: $sheet) }
        .modifier(DraggableUnlessSetup(id: combatant.id, isSetup: isSetup))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    private var tileArt: String { controller.entry(for: combatant)?.art.thumbnail ?? "" }

    private var isListening: Bool { voice.listeningFor == combatant.id }

    /// Outlined after Begin Combat's "Go Back", or while a creature that joined mid-fight still needs one.
    private var isMissingInitiative: Bool {
        combatant.initiative == nil && combatant.place == .ladder
            && (controller.highlightsMissingInitiative || controller.state.phase == .active)
    }

    private var missingStyle: StrokeStyle { StrokeStyle(lineWidth: 3, dash: [8, 5]) }

    /// "Perc +7 · Stealth +9": what to add to the die, for the GM's math.
    private var modifierHint: String? {
        let skills = controller.initiativeSkills(for: combatant).prefix(2)
        guard !skills.isEmpty else { return nil }
        return skills.map { "\($0.name == "Perception" ? "Perc" : $0.name) \(signed($0.modifier))" }
            .joined(separator: " · ")
    }

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
        Task {
            if let value = SpokenNumberParser.initiative(from: await voice.finish()) {
                controller.change { $0.setInitiative(value, for: combatant.id) }
            } else {
                shakes += 1
                sheet = .initiative(combatant.id)
            }
        }
    }
}

enum InitiativeText {
    /// "17", or "17½" for a tie-breaking half.
    static func format(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : "\(Int(value.rounded(.down)))½"
    }
}

/// Lets strips be dragged to reorder once combat has begun; during setup the order follows the numbers.
private struct DraggableUnlessSetup: ViewModifier {
    let id: UUID
    let isSetup: Bool

    func body(content: Content) -> some View {
        if isSetup { content } else { content.draggable(id.uuidString) }
    }
}

/// A microphone that listens while it is held down, and glows while listening.
private struct MicButton: View {
    let isListening: Bool
    let onPress: () -> Void
    let onRelease: () -> Void
    @State private var isPressing = false

    var body: some View {
        Image(systemName: isListening ? "mic.fill" : "mic")
            .font(.title2)
            .frame(width: 44, height: 44)
            .background(isListening ? Color.yellow.opacity(0.9) : Color.black.opacity(0.3), in: Circle())
            .foregroundStyle(isListening ? .black : .white)
            .contentShape(Circle())
            .onLongPressGesture(minimumDuration: 0, maximumDistance: 60) {} onPressingChanged: { pressing in
                if pressing && !isPressing {
                    isPressing = true
                    onPress()
                } else if !pressing && isPressing {
                    isPressing = false
                    onRelease()
                }
            }
            .accessibilityLabel("Hold to say the initiative")
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
