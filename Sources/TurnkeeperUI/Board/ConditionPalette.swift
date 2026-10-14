import BattleCards
import Bestiary
import TurnkeeperKit
import SwiftUI

/// The condition palette for a combatant on the board. Each change is one undoable step.
struct ConditionPalette: View {
    let controller: BoardController
    let id: UUID

    var body: some View {
        let combatant = controller.state[id]
        ConditionEditor(title: combatant?.name ?? "", conditions: combatant?.conditions ?? []) { edit in
            controller.change { state in
                guard var combatant = state[id] else { return }
                edit(&combatant.conditions)
                state[id] = combatant
            }
        }
    }
}

/// The condition magnets: tap to add, tap again to raise a valued one; current conditions can be lowered
/// or removed. Persistent damage and custom reminders ask for their details. Used on the board and for a
/// planned creature's starting conditions.
struct ConditionEditor: View {
    let title: String
    let conditions: [AppliedCondition]
    /// Applies an edit to wherever the conditions are kept.
    let change: (@escaping (inout [AppliedCondition]) -> Void) -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var persistentFormula = "1d6"
    @State private var persistentType = "bleed"
    @State private var reminderText = ""
    @State private var reminderMoment = TurnMoment.startOfTurn

    var body: some View {
        NavigationStack {
            List {
                Section("On \(title)") { current }
                Section("Add") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
                        ForEach(available) { definition in
                            Button { add(definition) } label: { ConditionButtonLabel(definition: definition) }
                                .buttonStyle(.bordered)
                        }
                    }
                }
                persistentSection
                reminderSection
            }
            .navigationTitle("Conditions")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .frame(minWidth: 520, minHeight: 620)
    }

    @ViewBuilder
    private var current: some View {
        ForEach(conditions) { condition in
            HStack {
                Text(ConditionLabel.short(condition))
                Spacer()
                if let value = condition.value {
                    Stepper("Value", value: Binding(get: { value }, set: { newValue in
                        change { $0.setValue(newValue, of: condition.id) }
                    }), in: 0...10)
                    .labelsHidden()
                }
                Button("Remove", systemImage: "xmark.circle.fill", role: .destructive) {
                    change { $0.removeAll { $0.id == condition.id } }
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
            }
        }
        if conditions.isEmpty { Text("None").foregroundStyle(.secondary) }
    }

    private var persistentSection: some View {
        Section("Persistent damage") {
            HStack {
                TextField("Formula", text: $persistentFormula)
                TextField("Type", text: $persistentType)
                Button("Add") {
                    let damage = DamagePart(formula: persistentFormula, type: persistentType, isPersistent: true)
                    change { $0.add(.persistent(damage)) }
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private var reminderSection: some View {
        Section("Reminder") {
            TextField("Sustain wall of fire", text: $reminderText)
            Picker("When", selection: $reminderMoment) {
                Text("Start of turn").tag(TurnMoment.startOfTurn)
                Text("End of turn").tag(TurnMoment.endOfTurn)
            }
            .pickerStyle(.segmented)
            Button("Add Reminder") {
                let reminder = AppliedCondition.reminder(reminderText, at: reminderMoment)
                change { $0.add(reminder) }
                reminderText = ""
            }
            .disabled(reminderText.isEmpty)
        }
    }

    /// The game's conditions, without the attitude ones that rarely matter in a fight and the persistent
    /// damage entry, which has its own section.
    private var available: [ConditionDefinition] {
        let skipped: Set<String> = ["friendly", "helpful", "hostile", "indifferent", "unfriendly", "observed",
                                    "persistent-damage", "malevolence"]
        return model.bestiary.conditions.filter { $0.games.contains(model.game) && !skipped.contains($0.slug) }
    }

    /// Adds the condition at value 1, or raises it by 1 if it's already there.
    private func add(_ definition: ConditionDefinition) {
        change { conditions in
            if let existing = conditions.first(where: { $0.slug == definition.slug }) {
                if let value = existing.value { conditions.setValue(value + 1, of: existing.id) }
            } else {
                conditions.append(AppliedCondition(slug: definition.slug, value: definition.isValued ? 1 : nil))
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
