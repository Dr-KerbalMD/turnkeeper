import CombatPadKit
import SwiftUI

/// The condition magnets: tap to add, tap again to raise a valued one; current conditions can be lowered
/// or removed. Persistent damage and custom reminders ask for their details.
struct ConditionPalette: View {
    let controller: BoardController
    let id: UUID
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var persistentFormula = "1d6"
    @State private var persistentType = "bleed"
    @State private var reminderText = ""
    @State private var reminderMoment = TurnMoment.startOfTurn

    private var combatant: Combatant? { controller.state[id] }

    var body: some View {
        NavigationStack {
            List {
                Section("On \(combatant?.name ?? "")") { current }
                Section("Add") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
                        ForEach(available) { definition in
                            Button { add(definition) } label: { ConditionButtonLabel(definition: definition) }
                                .buttonStyle(.bordered)
                        }
                    }
                }
                Section("Persistent damage") {
                    HStack {
                        TextField("Formula", text: $persistentFormula)
                        TextField("Type", text: $persistentType)
                        Button("Add") {
                            let damage = DamagePart(formula: persistentFormula, type: persistentType,
                                                    isPersistent: true)
                            controller.change { $0.addCondition(.persistent(damage), to: id) }
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Section("Reminder") {
                    TextField("Sustain wall of fire", text: $reminderText)
                    Picker("When", selection: $reminderMoment) {
                        Text("Start of turn").tag(TurnMoment.startOfTurn)
                        Text("End of turn").tag(TurnMoment.endOfTurn)
                    }
                    .pickerStyle(.segmented)
                    Button("Add Reminder") {
                        controller.change { $0.addCondition(.reminder(reminderText, at: reminderMoment), to: id) }
                        reminderText = ""
                    }
                    .disabled(reminderText.isEmpty)
                }
            }
            .navigationTitle("Conditions")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .frame(minWidth: 520, minHeight: 620)
    }

    @ViewBuilder
    private var current: some View {
        ForEach(combatant?.conditions ?? []) { condition in
            HStack {
                Text(ConditionLabel.short(condition))
                Spacer()
                if let value = condition.value {
                    Stepper("Value", value: Binding(get: { value }, set: { newValue in
                        controller.change { $0.setConditionValue(newValue, conditionID: condition.id, on: id) }
                    }), in: 0...10)
                    .labelsHidden()
                }
                Button("Remove", systemImage: "xmark.circle.fill", role: .destructive) {
                    controller.change { $0.removeCondition(condition.id, from: id) }
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
            }
        }
        if combatant?.conditions.isEmpty ?? true { Text("None").foregroundStyle(.secondary) }
    }

    /// The game's conditions, without the attitude ones that rarely matter in a fight and the persistent
    /// damage entry, which has its own section.
    private var available: [ConditionDefinition] {
        let skipped: Set<String> = ["friendly", "helpful", "hostile", "indifferent", "unfriendly", "observed",
                                    "persistent-damage", "malevolence"]
        return model.bestiary.conditions.filter { $0.games.contains(model.game) && !skipped.contains($0.slug) }
    }

    /// Adds the condition at value 1, or raises it by 1 if the combatant already has it.
    private func add(_ definition: ConditionDefinition) {
        controller.change { state in
            let existing = state[id]?.condition(definition.slug)
            if let existing, let value = existing.value {
                state.setConditionValue(value + 1, conditionID: existing.id, on: id)
            } else if existing == nil {
                let condition = AppliedCondition(slug: definition.slug, value: definition.isValued ? 1 : nil)
                state.addCondition(condition, to: id)
            }
        }
    }
}

/// A condition's icon from the system art, with its name.
private struct ConditionButtonLabel: View {
    let definition: ConditionDefinition

    var body: some View {
        HStack(spacing: 6) {
            ArtImage(path: "Conditions/\(definition.slug).webp", size: 22, shape: .circle, contentMode: .fit)
            Text(definition.name).font(.callout).lineLimit(1)
            Spacer(minLength: 0)
        }
    }
}
