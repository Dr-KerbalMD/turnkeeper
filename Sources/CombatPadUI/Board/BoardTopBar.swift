import CombatPadKit
import SwiftUI

/// Sheets the board opens.
enum BoardSheet: Identifiable, Hashable {
    case hitPoints(UUID)
    case initiative(UUID)
    case conditions(UUID)
    case duration
    case event

    var id: String { String(describing: self) }
}

/// Round, turn controls, duration arrows and the encounter's name and difficulty.
struct BoardTopBar: View {
    let controller: BoardController
    @Binding var sheet: BoardSheet?
    @Environment(AppModel.self) private var model
    @Environment(\.padTheme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            Button("Close", systemImage: "xmark") { model.closeBoard() }
                .labelStyle(.iconOnly)
                .help("Close the board. The fight is kept; Run or Resume brings it back.")
            VStack(alignment: .leading, spacing: 0) {
                Text(controller.session?.name ?? "").font(.headline)
                Text(roundText).font(.caption).foregroundStyle(.secondary)
            }
            DurationArrows(controller: controller)
            Spacer()
            if controller.state.phase == .setup {
                BeginCombatButton(controller: controller)
            } else {
                Menu("Add", systemImage: "plus") {
                    Button("Duration Arrow…", systemImage: "arrow.uturn.right") { sheet = .duration }
                    Button("Event…", systemImage: "bell") { sheet = .event }
                }
                FightMenu(controller: controller)
                Button("Undo", systemImage: "arrow.uturn.backward") { controller.undo() }
                    .disabled(!controller.canUndo)
                Button("Next", systemImage: "forward.end.fill") { controller.next() }
                    .buttonStyle(.borderedProminent)
                    .disabled(controller.isBlocked)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var roundText: String {
        let state = controller.state
        if state.phase == .setup {
            return "Roll for initiative: hold a strip's microphone and say the total, or tap the number"
        }
        let name = state.current?.name ?? "—"
        return "Round \(state.round) · \(name)'s turn"
    }
}

/// The colored duration arrows: what's running and how many rounds are left. Tap one to remove it.
private struct DurationArrows: View {
    let controller: BoardController

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(controller.state.durations) { marker in
                    Button {
                        controller.change { $0.durations.removeAll { $0.id == marker.id } }
                    } label: {
                        Label("\(marker.label) \(marker.roundsRemaining)", systemImage: "arrowtriangle.right.fill")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(color(for: marker).opacity(0.85), in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .help("Ends at the \(marker.moment == .startOfTurn ? "start" : "end") of "
                          + "\(controller.state[marker.anchorCombatantID]?.name ?? "someone")'s turn. Tap to remove.")
                }
            }
        }
        .frame(maxWidth: 360)
    }

    private func color(for marker: DurationMarker) -> Color {
        let colors: [Color] = [.orange, .purple, .teal, .pink, .indigo, .brown]
        return colors[Int(marker.id.uuid.0) % colors.count]
    }
}

/// Resetting or ending the whole fight.
private struct FightMenu: View {
    let controller: BoardController
    @State private var isConfirmingReset = false

    var body: some View {
        Menu("Fight", systemImage: "ellipsis.circle") {
            Button("Reset Combat…", systemImage: "arrow.counterclockwise") { isConfirmingReset = true }
            Button("End Combat", systemImage: "flag.checkered") { controller.endCombat() }
        }
        .confirmationDialog("Reset this fight?", isPresented: $isConfirmingReset, titleVisibility: .visible) {
            Button("Reset Combat", role: .destructive) { controller.reset() }
        } message: {
            Text("Initiative, HP, conditions and the round go back to the start. Undo brings it all back.")
        }
    }
}

/// Begins combat, first warning when someone on the ladder still has no initiative.
private struct BeginCombatButton: View {
    let controller: BoardController
    @State private var missing: [Combatant] = []

    var body: some View {
        Button("Begin Combat", systemImage: "flag.checkered") {
            missing = controller.state.combatantsWithoutInitiative
            if missing.isEmpty { controller.beginCombat() }
        }
        .buttonStyle(.borderedProminent)
        // An alert rather than a confirmation dialog: on the iPad a dialog becomes a popover, which hides the
        // cancel button, and Go Back must always be there.
        .alert(title, isPresented: isWarning) {
            Button("Go Back", role: .cancel) { controller.highlightsMissingInitiative = true }
            Button("Begin Anyway") { controller.beginCombat() }
        } message: {
            Text("Begin Anyway puts them at the bottom of the order.")
        }
    }

    private var title: String {
        let names = missing.map(\.name)
        let list = names.count > 1
            ? names.dropLast().joined(separator: ", ") + " and " + (names.last ?? "")
            : names.first ?? ""
        return "\(list) \(names.count == 1 ? "has" : "have") no initiative yet."
    }

    private var isWarning: Binding<Bool> {
        Binding(get: { !missing.isEmpty }, set: { if !$0 { missing = [] } })
    }
}
