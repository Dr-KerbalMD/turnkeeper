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
            // One button per row: in a form, a tap anywhere in a row triggers every plain button in it.
            Button("Add Creature…", systemImage: "plus") { isBrowsing = true }
            Button("Add Custom NPC…", systemImage: "person.badge.plus") { isAddingNPC = true }
        }
    }

    /// Changes the difficulty's creatures, asking first if that would reset a fight in progress.
    private func updateVariant(_ change: @escaping (inout EncounterVariant) -> Void) {
        let encounterID = encounter.id
        let label = label
        model.changeVariant(encounterID: encounterID, variantLabel: label) { [model, encounter] in
            var edited = model.encounter(encounterID) ?? encounter
            var variant = edited.variant(label)
            change(&variant)
            edited.setVariant(variant)
            model.library.save(edited)
        }
    }

    private func updateSlot(_ id: UUID, _ change: @escaping (inout EncounterSlot) -> Void) {
        updateVariant { variant in
            if let index = variant.slots.firstIndex(where: { $0.id == id }) { change(&variant.slots[index]) }
        }
    }
}

/// One slot: art, name, level and XP, with its settings.
private struct SlotRow: View {
    let slot: EncounterSlot
    let party: Party?
    let change: (@escaping (inout EncounterSlot) -> Void) -> Void
    @Environment(AppModel.self) private var model
    @State private var isShowingCard = false
    @State private var isEditingConditions = false

    var body: some View {
        let entry = model.entry(slot.creatureKey)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button { isShowingCard = true } label: {
                    HStack(spacing: 12) {
                        ArtImage(path: entry?.art.thumbnail ?? "", size: 44, shape: .circle, alignment: .top)
                        VStack(alignment: .leading) {
                            Text(slot.customName.isEmpty ? (entry?.name ?? "Unknown creature") : slot.customName)
                                .font(.headline)
                            Text(details(entry)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.primary)
                .disabled(slot.isCustom)
                .help("Show the battle card")
                Spacer()
                if !slot.isCustom {
                    Button("Card", systemImage: "rectangle.portrait") { isShowingCard = true }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                }
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
            startingState
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $isShowingCard) {
            CreaturePreview(key: slot.creatureKey, template: slot.template, conditions: slot.conditions)
        }
        .sheet(isPresented: $isEditingConditions) {
            ConditionEditor(title: model.entry(slot.creatureKey)?.name ?? slot.customName,
                            conditions: slot.conditions) { edit in change { edit(&$0.conditions) } }
        }
    }

    /// Conditions and temporary HP the creatures start the fight with.
    private var startingState: some View {
        HStack {
            Button {
                isEditingConditions = true
            } label: {
                Label(slot.conditions.isEmpty ? "Starting Conditions…" : startingConditionsText,
                      systemImage: "staroflife")
            }
            .buttonStyle(.borderless)
            Spacer()
            Stepper("Temp HP \(slot.temporaryHitPoints)", value: field(\.temporaryHitPoints), in: 0...500, step: 5)
                .fixedSize()
        }
        .font(.callout)
    }

    private var startingConditionsText: String {
        "Starts " + slot.conditions.map(ConditionLabel.short).joined(separator: ", ").lowercased()
    }

    private func field<Value>(_ path: WritableKeyPath<EncounterSlot, Value>) -> Binding<Value> {
        Binding(get: { slot[keyPath: path] }, set: { value in change { $0[keyPath: path] = value } })
    }

    private func details(_ entry: BestiaryIndexEntry?) -> String {
        let baseLevel = slot.isCustom ? slot.customLevel : (entry?.level ?? 0)
        let level = slot.template.level(base: baseLevel)
        var parts = ["Level \(level)"]
        if let party {
            let budget = party.budget
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
