import CombatPadKit
import SwiftUI

/// The creatures of one encounter variant: count, template, side and whether they start on the bench.
struct SlotsSection: View {
    let encounter: Encounter
    let label: String
    let party: Party?
    @Binding var isBrowsing: Bool
    @Binding var isAddingNPC: Bool
    @Environment(AppModel.self) private var model

    var body: some View {
        Section("Creatures") {
            ForEach(encounter.variant(label).slots) { slot in
                SlotRow(slot: slot, party: party, change: { change in updateSlot(slot.id, change) })
            }
            .onDelete { offsets in updateVariant { $0.slots.remove(atOffsets: offsets) } }
            .onMove { source, target in updateVariant { $0.slots.move(fromOffsets: source, toOffset: target) } }
            HStack {
                Button("Add Creature…", systemImage: "plus") { isBrowsing = true }
                Button("Add Custom NPC…", systemImage: "person.badge.plus") { isAddingNPC = true }
            }
        }
    }

    private func updateVariant(_ change: (inout EncounterVariant) -> Void) {
        var edited = model.encounter(encounter.id) ?? encounter
        var variant = edited.variant(label)
        change(&variant)
        edited.setVariant(variant)
        model.library.save(edited)
    }

    private func updateSlot(_ id: UUID, _ change: (inout EncounterSlot) -> Void) {
        updateVariant { variant in
            if let index = variant.slots.firstIndex(where: { $0.id == id }) { change(&variant.slots[index]) }
        }
    }
}

/// One slot: art, name, level and XP, with its settings.
private struct SlotRow: View {
    let slot: EncounterSlot
    let party: Party?
    let change: ((inout EncounterSlot) -> Void) -> Void
    @Environment(AppModel.self) private var model

    var body: some View {
        let entry = model.entry(slot.creatureKey)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ArtImage(path: entry?.art.thumbnail ?? "", size: 44, shape: .circle, alignment: .top)
                VStack(alignment: .leading) {
                    Text(slot.customName.isEmpty ? (entry?.name ?? "Unknown creature") : slot.customName)
                        .font(.headline)
                    Text(details(entry)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Stepper("× \(slot.count)", value: field(\.count), in: 1...20)
                    .fixedSize()
            }
            HStack {
                Picker("Template", selection: field(\.template)) {
                    Text("Weak").tag(CreatureTemplate.weak)
                    Text("Normal").tag(CreatureTemplate.normal)
                    Text("Elite").tag(CreatureTemplate.elite)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 240)
                Picker("Side", selection: field(\.side)) {
                    Text("Enemy").tag(Side.enemy)
                    Text("Ally").tag(Side.ally)
                }
                .labelsHidden()
                .fixedSize()
                Toggle("Starts on bench", isOn: field(\.startsOnBench))
            }
        }
        .padding(.vertical, 4)
    }

    private func field<Value>(_ path: WritableKeyPath<EncounterSlot, Value>) -> Binding<Value> {
        Binding(get: { slot[keyPath: path] }, set: { value in change { $0[keyPath: path] = value } })
    }

    private func details(_ entry: BestiaryIndexEntry?) -> String {
        let baseLevel = slot.isCustom ? slot.customLevel : (entry?.level ?? 0)
        let level = slot.template.level(base: baseLevel)
        var parts = ["Level \(level)"]
        if let party {
            let budget = EncounterBudget(partyLevel: party.level, partySize: party.members.count)
            parts.append(slot.side == .ally ? "ally, no XP" : "\(budget.experience(forLevel: level)) XP each")
            if budget.isOutsideTable(level: level) { parts.append("outside the XP table") }
        }
        if let source = entry?.source.title, !source.isEmpty { parts.append(source) }
        return parts.joined(separator: " · ")
    }
}

/// Adds an NPC or ally that isn't in the bestiary.
struct CustomNPCSheet: View {
    let add: (EncounterSlot) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var level = 1
    @State private var hitPoints = 20
    @State private var side = Side.ally

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Stepper("Level \(level)", value: $level, in: -1...25)
                Stepper("HP \(hitPoints)", value: $hitPoints, in: 1...999)
                Picker("Side", selection: $side) {
                    Text("Ally").tag(Side.ally)
                    Text("Enemy").tag(Side.enemy)
                }
                .pickerStyle(.segmented)
            }
            .formStyle(.grouped)
            .navigationTitle("Custom NPC")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        var slot = EncounterSlot.customNPC(name: name.isEmpty ? "NPC" : name, level: level,
                                                           hitPoints: hitPoints)
                        slot.side = side
                        add(slot)
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 360, minHeight: 260)
    }
}
