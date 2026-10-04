import CombatPadKit
import SwiftUI

/// Planned events of one encounter variant.
struct EventsSection: View {
    let encounter: Encounter
    let label: String
    @Binding var editingEvent: EncounterEvent?
    @Environment(AppModel.self) private var model

    var body: some View {
        Section("Events") {
            ForEach(encounter.variant(label).events) { event in
                Button { editingEvent = event } label: {
                    VStack(alignment: .leading) {
                        Text(event.label).font(.headline)
                        Text(EventDescription.text(for: event, slots: encounter.variant(label).slots, model: model))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                model.changeVariant(encounterID: encounter.id, variantLabel: label) { [model, encounter, label] in
                    var edited = model.encounter(encounter.id) ?? encounter
                    var variant = edited.variant(label)
                    variant.events.remove(atOffsets: offsets)
                    edited.setVariant(variant)
                    model.library.save(edited)
                }
            }
            Button("Add Event…", systemImage: "bell.badge") {
                editingEvent = EncounterEvent(label: "", trigger: .startOfRound)
            }
        }
    }
}

/// Words for an event's trigger and timing, such as "Initiative 15, round 2 only".
enum EventDescription {
    @MainActor
    static func text(for event: EncounterEvent, slots: [EncounterSlot], model: AppModel) -> String {
        var parts = [trigger(event.trigger, slots: slots, model: model), occurrence(event.occurrence)]
        if !event.bringsInSlotIDs.isEmpty { parts.append("brings in benched creatures") }
        return parts.joined(separator: " · ")
    }

    @MainActor
    static func trigger(_ trigger: EventTrigger, slots: [EncounterSlot], model: AppModel) -> String {
        switch trigger {
        case let .initiative(count): return "Initiative \(count)"
        case .startOfRound: return "Start of round"
        case .endOfRound: return "End of round"
        case let .turnStart(slotID): return "Start of \(name(slotID, slots, model))'s turn"
        case let .turnEnd(slotID): return "End of \(name(slotID, slots, model))'s turn"
        }
    }

    static func occurrence(_ occurrence: EventOccurrence) -> String {
        switch occurrence {
        case .everyRound: return "every round"
        case let .onlyRound(round): return "round \(round) only"
        case let .every(interval, start): return "every \(interval) rounds from round \(start)"
        }
    }

    @MainActor
    static func name(_ slotID: UUID, _ slots: [EncounterSlot], _ model: AppModel) -> String {
        guard let slot = slots.first(where: { $0.id == slotID }) else { return "a removed creature" }
        return slot.customName.isEmpty ? (model.entry(slot.creatureKey)?.name ?? "creature") : slot.customName
    }
}
