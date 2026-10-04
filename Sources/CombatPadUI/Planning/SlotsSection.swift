import CombatPadKit
import SwiftUI

/// The creatures of one encounter variant: count, template, side and whether they start on the bench.
struct SlotsSection: View {
    let encounter: Encounter
    let label: String
    let party: Party?
    @Binding var isBrowsing: Bool
    @Binding var isAddingCustom: Bool
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
            Button("Add Custom Creature…", systemImage: "person.badge.plus") { isAddingCustom = true }
            PasteStatBlocksRow(encounterID: encounter.id, label: label)
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
    @State private var isEditingCreature = false
    @State private var isConfirmingDelete = false

    var body: some View {
        let entry = model.entry(slot.creatureKey)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button { isShowingCard = true } label: {
                    HStack(spacing: 12) {
                        ArtImage(path: entry?.art.thumbnail ?? "", size: 44, shape: .circle, alignment: .top)
                        VStack(alignment: .leading) {
                            Text(entry?.name ?? "Unknown creature").font(.headline)
                            Text(details(entry)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.primary)
                .help("Show the battle card")
                Spacer()
                if slot.isCustom {
                    Button("Edit Creature…", systemImage: "pencil") { isEditingCreature = true }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                }
                Button("Card", systemImage: "rectangle.portrait") { isShowingCard = true }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
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
            ConditionEditor(title: model.entry(slot.creatureKey)?.name ?? "",
                            conditions: slot.conditions) { edit in change { edit(&$0.conditions) } }
        }
        .contextMenu {
            if slot.isCustom {
                Button("Edit Creature…", systemImage: "pencil") { isEditingCreature = true }
                Button("Delete Custom Creature…", systemImage: "trash", role: .destructive) {
                    isConfirmingDelete = true
                }
            }
        }
        .alert("Delete \(model.entry(slot.creatureKey)?.name ?? "this creature")?", isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive) { model.deleteCustomCreature(key: slot.creatureKey) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(deleteMessage)
        }
        .sheet(isPresented: $isEditingCreature) {
            if let custom = model.library.customCreature(key: slot.creatureKey) {
                CustomCreatureEditor(custom: custom) { model.library.save($0) }
            }
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

    private var deleteMessage: String {
        let count = model.encountersUsing(key: slot.creatureKey).count
        let place = count == 1 ? "this encounter" : "\(count) encounters"
        return "It's removed from \(place), and from the campaign's custom creatures."
    }

    private func field<Value>(_ path: WritableKeyPath<EncounterSlot, Value>) -> Binding<Value> {
        Binding(get: { slot[keyPath: path] }, set: { value in change { $0[keyPath: path] = value } })
    }

    private func details(_ entry: BestiaryIndexEntry?) -> String {
        let baseLevel = entry?.level ?? 0
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
