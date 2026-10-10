import Bestiary
import CombatPadKit
import SwiftUI

/// The initiative half of the pad: the ladder of magnets with event markers between them, the Delay and
/// Dying drop zones, and the bench of creatures waiting to join.
struct LadderView: View {
    let controller: BoardController
    @Binding var sheet: BoardSheet?
    @Environment(\.padTheme) private var theme

    var body: some View {
        VStack(spacing: 10) {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(LadderItem.items(for: controller.state)) { item in
                        switch item {
                        case let .combatant(combatant):
                            MagnetTile(controller: controller, combatant: combatant, sheet: $sheet)
                                .dropDestination(for: String.self) { ids, _ in drop(ids, before: combatant.id) }
                        case let .event(event):
                            EventMarker(event: event)
                        }
                    }
                }
                .padding(12)
            }
            if controller.state.phase == .active { gutters }
            if controller.state.phase == .setup { HoldToTalkButton(controller: controller) }
            BenchTray(controller: controller) { id in
                controller.bringInFromBench(id)
                sheet = .initiative(id)
            }
        }
        .padding(.bottom, 10)
    }

    private var gutters: some View {
        HStack(spacing: 10) {
            DropZone(title: "Delay", systemImage: "hourglass", items: controller.state.delaying) { id in
                controller.change { $0.endDelay(id) }
            }
            .dropDestination(for: String.self) { ids, _ in
                ids.compactMap(UUID.init(uuidString:)).forEach { id in controller.change { $0.startDelay(id) } }
                return true
            }
            DropZone(title: "Dying", systemImage: "heart.slash", items: dying, action: nil)
                .dropDestination(for: String.self) { ids, _ in
                    ids.compactMap(UUID.init(uuidString:)).forEach { id in controller.change { $0.knockOut(id) } }
                    return true
                }
        }
        .padding(.horizontal, 12)
    }

    private var dying: [Combatant] {
        controller.state.ladder.filter { $0.condition(ConditionSlug.dying) != nil }
    }

    private func drop(_ ids: [String], before target: UUID) -> Bool {
        guard let id = ids.first.flatMap(UUID.init(uuidString:)), id != target else { return false }
        let state = controller.state
        switch state[id]?.place {
        case .bench:
            controller.bringInFromBench(id)
            controller.change { $0.move(id, toIndex: $0.order.firstIndex(of: target) ?? 0) }
            sheet = .initiative(id)
        case .delaying:
            controller.change { $0.endDelay(id) }
        default:
            controller.change { $0.move(id, toIndex: $0.order.firstIndex(of: target) ?? 0) }
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

/// A labeled drop zone listing the combatants in it.
private struct DropZone: View {
    let title: String
    let systemImage: String
    let items: [Combatant]
    let action: ((UUID) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage).font(.caption.bold())
            ForEach(items) { combatant in
                Button(combatant.name) { action?(combatant.id) }
                    .font(.caption)
                    .disabled(action == nil)
                    .help(action == nil ? "" : "Return now: takes its turn at this point in the order")
            }
            if items.isEmpty { Text("Drag a strip here").font(.caption2).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .topLeading)
        .padding(8)
        .foregroundStyle(.white)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.25)) }
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
