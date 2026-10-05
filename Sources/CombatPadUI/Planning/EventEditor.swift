import CombatPadKit
import SwiftUI

/// Edits an event's label, text, trigger, timing, and the benched creatures it brings in.
struct EventEditor: View {
    @State var event: EncounterEvent
    let slots: [EncounterSlot]
    let save: (EncounterEvent) -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var kind = TriggerKind.startOfRound
    @State private var count = 20
    @State private var slotID: UUID?
    @State private var timing = Timing.everyRound
    @State private var round = 1
    @State private var interval = 2

    enum TriggerKind: String, CaseIterable {
        case initiative = "Initiative count"
        case startOfRound = "Start of round"
        case endOfRound = "End of round"
        case turnStart = "Start of a creature's turn"
        case turnEnd = "End of a creature's turn"
        case endOfCombat = "At the end of combat"
    }

    enum Timing: String, CaseIterable {
        case everyRound = "Every round"
        case onlyRound = "Only in round"
        case every = "Every few rounds"
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Label", text: $event.label, prompt: Text("Reinforcements arrive")).titleEntry()
                TextField("What happens", text: $event.text, axis: .vertical).lineLimit(2...6)
                triggerSection
                if kind != .endOfCombat {
                    timingSection
                    benchSection
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Event")
            .onAppear(perform: load)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: commit) }
            }
        }
        .frame(minWidth: 420, minHeight: 420)
    }

    private var triggerSection: some View {
        Section("When") {
            Picker("Trigger", selection: $kind) {
                ForEach(TriggerKind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            if kind == .initiative {
                Stepper("Initiative \(count)", value: $count, in: 0...50)
            }
            if kind == .turnStart || kind == .turnEnd {
                Picker("Creature", selection: $slotID) {
                    ForEach(slots) { slot in
                        Text(EventDescription.name(slot.id, slots, model)).tag(UUID?.some(slot.id))
                    }
                }
            }
        }
    }

    private var timingSection: some View {
        Section("Rounds") {
            Picker("Timing", selection: $timing) {
                ForEach(Timing.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            if timing != .everyRound { Stepper(timing == .every ? "From round \(round)" : "Round \(round)",
                                               value: $round, in: 1...20) }
            if timing == .every { Stepper("Every \(interval) rounds", value: $interval, in: 2...10) }
        }
    }

    private var benchSection: some View {
        Section("Brings in from the bench") {
            ForEach(slots.filter(\.startsOnBench)) { slot in
                Toggle(EventDescription.name(slot.id, slots, model), isOn: Binding(
                    get: { event.bringsInSlotIDs.contains(slot.id) },
                    set: { isOn in
                        event.bringsInSlotIDs.removeAll { $0 == slot.id }
                        if isOn { event.bringsInSlotIDs.append(slot.id) }
                    }))
            }
        }
    }

    private func load() {
        switch event.trigger {
        case let .initiative(value): (kind, count) = (.initiative, value)
        case .startOfRound: kind = .startOfRound
        case .endOfRound: kind = .endOfRound
        case let .turnStart(id): (kind, slotID) = (.turnStart, id)
        case let .turnEnd(id): (kind, slotID) = (.turnEnd, id)
        case .endOfCombat: kind = .endOfCombat
        }
        switch event.occurrence {
        case .everyRound: timing = .everyRound
        case let .onlyRound(value): (timing, round) = (.onlyRound, value)
        case let .every(every, start): (timing, interval, round) = (.every, every, start)
        }
        slotID = slotID ?? slots.first?.id
    }

    private func commit() {
        let slot = slotID ?? slots.first?.id ?? UUID()
        let triggers: [TriggerKind: EventTrigger] = [
            .initiative: .initiative(count), .startOfRound: .startOfRound, .endOfRound: .endOfRound,
            .turnStart: .turnStart(slotID: slot), .turnEnd: .turnEnd(slotID: slot), .endOfCombat: .endOfCombat
        ]
        event.trigger = triggers[kind] ?? .startOfRound
        event.occurrence = occurrence
        if kind == .endOfCombat { event.bringsInSlotIDs = [] }
        if event.label.isEmpty { event.label = "Event" }
        save(event)
        dismiss()
    }

    /// The rounds the event fires in; an end-of-combat event fires once, so it keeps the default.
    private var occurrence: EventOccurrence {
        guard kind != .endOfCombat else { return .everyRound }
        switch timing {
        case .everyRound: return .everyRound
        case .onlyRound: return .onlyRound(round)
        case .every: return .every(interval: interval, start: round)
        }
    }
}
