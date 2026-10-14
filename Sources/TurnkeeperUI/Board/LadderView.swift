import TurnkeeperKit
import SwiftUI

/// The initiative half of the board: the ladder of magnets with event markers between them, and the bench of
/// creatures waiting to join. In combat, swiping a strip left to right delays it, and right to left knocks it
/// out, or brings a delaying strip back.
struct LadderView: View {
    let controller: BoardController
    @Binding var sheet: BoardSheet?
    @Environment(\.boardTheme) private var theme

    /// Swiping to delay asks first, while the gesture is new to the table.
    private static let confirmsSwipeToDelay = true

    var body: some View {
        VStack(spacing: 10) {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(LadderItem.items(for: controller.state)) { item in
                        switch item {
                        case let .combatant(combatant):
                            MagnetTile(controller: controller, combatant: combatant, sheet: $sheet)
                                .modifier(SwipeableStrip(leading: delayAction(combatant),
                                                         trailing: knockOutAction(combatant)))
                                .opacity(combatant.isDelaying ? 0.7 : 1)
                                .padding(.leading, combatant.isDelaying ? 24 : 0)
                                .dropDestination(for: String.self) { ids, _ in drop(ids, before: combatant.id) }
                        case let .event(event):
                            EventMarker(event: event)
                        }
                    }
                }
                .padding(12)
            }
            if controller.state.phase == .setup { HoldToTalkButton(controller: controller) }
            BenchTray(controller: controller) { id in
                controller.bringInFromBench(id)
                sheet = .initiative(id)
            }
        }
        .padding(.bottom, 10)
    }

    /// Left to right: delay, in combat and when not delaying already.
    private func delayAction(_ combatant: Combatant) -> StripSwipeAction? {
        guard controller.state.phase == .active, !combatant.isDelaying else { return nil }
        return StripSwipeAction(title: "Delay", systemImage: "hourglass", color: .orange) {
            if Self.confirmsSwipeToDelay {
                controller.delayToConfirm = combatant
            } else {
                controller.startDelay(combatant.id)
            }
        }
    }

    /// Right to left: a delaying strip returns; any other is knocked out.
    private func knockOutAction(_ combatant: Combatant) -> StripSwipeAction? {
        guard controller.state.phase == .active else { return nil }
        if combatant.isDelaying {
            return StripSwipeAction(title: "Return", systemImage: "arrow.uturn.left", color: .green) {
                controller.change { $0.endDelay(combatant.id) }
            }
        }
        return StripSwipeAction(title: "Knocked Out", systemImage: "heart.slash", color: .red) {
            controller.change { $0.knockOut(combatant.id) }
        }
    }

    private func drop(_ ids: [String], before target: UUID) -> Bool {
        guard let id = ids.first.flatMap(UUID.init(uuidString:)), id != target else { return false }
        let state = controller.state
        switch state[id]?.place {
        case .bench:
            controller.bringInFromBench(id)
            controller.change { $0.move(id, toIndex: $0.order.firstIndex(of: target) ?? 0) }
            sheet = .initiative(id)
        default:
            // A delaying strip only moves down.
            let index = state.order.firstIndex(of: target) ?? 0
            guard state.canMove(id, toIndex: index) else { return false }
            controller.change { $0.move(id, toIndex: index) }
        }
        return true
    }
}

/// A row on the ladder: a combatant, or an event at its initiative count.
enum LadderItem: Identifiable {
    case combatant(Combatant)
    case event(EncounterEvent)

    var id: UUID {
        switch self {
        case let .combatant(combatant): return combatant.id
        case let .event(event): return event.id
        }
    }

    /// Round-start events at the top, initiative events after the last combatant at or above their count,
    /// round-end events at the bottom.
    static func items(for state: CombatState) -> [LadderItem] {
        let events = state.events.filter(\.isEnabled)
        var items = events.filter { $0.trigger == .startOfRound }.map(LadderItem.event)
        var pending = events.filter { $0.initiativeCount != nil }
            .sorted { ($0.initiativeCount ?? 0) > ($1.initiativeCount ?? 0) }
        for combatant in state.ladder {
            let initiative = combatant.initiative ?? -100
            while let event = pending.first, Double(event.initiativeCount ?? 0) > initiative {
                items.append(.event(event))
                pending.removeFirst()
            }
            items.append(.combatant(combatant))
        }
        items += pending.map(LadderItem.event)
        items += events.filter { $0.trigger == .endOfRound }.map(LadderItem.event)
        return items
    }
}

/// A dashed gray marker for an event on the ladder.
private struct EventMarker: View {
    let event: EncounterEvent

    var body: some View {
        HStack {
            Image(systemName: "bell.fill")
            Text(event.label).bold()
            Spacer()
            Text(EventDescription.occurrence(event.occurrence)).font(.caption)
            if let count = event.initiativeCount { Text("\(count)").font(.headline.monospacedDigit()) }
        }
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .overlay {
            RoundedRectangle(cornerRadius: 8).strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .foregroundStyle(.gray)
        }
    }
}

/// Creatures waiting off the ladder. Tap to bring one in and enter its initiative, or drag it into place.
private struct BenchTray: View {
    let controller: BoardController
    let bringIn: (UUID) -> Void

    var body: some View {
        let bench = controller.state.bench
        if !bench.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Label("Bench", systemImage: "chair.lounge").font(.caption.bold()).foregroundStyle(.white)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(bench) { combatant in
                            Button {
                                bringIn(combatant.id)
                            } label: {
                                Label(combatant.name, systemImage: "arrow.up.circle")
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(combatant.magnet.color, in: Capsule())
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                            .draggable(combatant.id.uuidString)
                            .help("Bring into the fight and enter its initiative")
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
        }
    }
}
