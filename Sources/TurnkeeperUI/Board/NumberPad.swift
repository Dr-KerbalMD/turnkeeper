import TurnkeeperKit
import SwiftUI

/// A big-key number pad for the table: digits, delete and clear. Keyboard digits work too on the Mac.
struct NumberPad: View {
    @Binding var digits: String

    var body: some View {
        VStack(spacing: 8) {
            Text(digits.isEmpty ? "0" : digits)
                .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal)
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach([["7", "8", "9"], ["4", "5", "6"], ["1", "2", "3"], ["C", "0", "⌫"]], id: \.self) { row in
                    GridRow {
                        ForEach(row, id: \.self) { key in
                            Button { press(key) } label: {
                                Text(key).font(.title.bold()).frame(maxWidth: .infinity, minHeight: 52)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
        .onKeyPress(characters: .decimalDigits) { press in
            digits = String((digits + press.characters).suffix(4))
            return .handled
        }
        .onKeyPress(.delete) {
            digits = String(digits.dropLast())
            return .handled
        }
    }

    var value: Int { Int(digits) ?? 0 }

    private func press(_ key: String) {
        switch key {
        case "C": digits = ""
        case "⌫": digits = String(digits.dropLast())
        default: digits = String((digits + key).suffix(4))
        }
    }
}

/// Damage, healing and temporary HP for a creature.
struct HitPointsPad: View {
    let controller: BoardController
    let id: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var digits = ""

    var body: some View {
        VStack(spacing: 14) {
            Text(controller.state[id]?.name ?? "").font(.title2.bold())
            NumberPad(digits: $digits)
            HStack {
                action("Damage", "minus.circle.fill", .red) { $0.applyDamage($1, to: id) }
                action("Heal", "plus.circle.fill", .green) { $0.heal($1, on: id) }
                action("Temp HP", "shield.fill", .blue) { $0.grantTemporaryHitPoints($1, to: id) }
            }
        }
        .padding(24)
        .frame(minWidth: 340)
    }

    private func action(
        _ title: String, _ image: String, _ color: Color, apply: @escaping (inout CombatState, Int) -> Void
    ) -> some View {
        Button {
            let amount = Int(digits) ?? 0
            controller.change { apply(&$0, amount) }
            dismiss()
        } label: {
            Label(title, systemImage: image).frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
        .disabled(digits.isEmpty)
    }
}

/// Sets a combatant's initiative, with a half for breaking ties. When other strips share its creature type,
/// the All buttons give the whole group one total: Set All from the keypad, Roll All from a single die.
struct InitiativePad: View {
    let controller: BoardController
    let id: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var digits = ""
    @State private var addHalf = false

    private var combatant: Combatant? { controller.state[id] }
    /// The strips the All buttons act on, this one included.
    private var group: [Combatant] { controller.initiativeGroup(of: id) }
    private var isGroup: Bool { group.count > 1 }
    private var canRoll: Bool { combatant?.kind != .playerCharacter }
    private var value: Double { Double(Int(digits) ?? 0) + (addHalf ? 0.5 : 0) }

    var body: some View {
        VStack(spacing: 14) {
            Text(combatant?.name ?? "").font(.title2.bold())
            if let combatant {
                InitiativeSkillsView(skills: controller.initiativeSkills(for: combatant))
            }
            NumberPad(digits: $digits)
            Toggle("Add ½ to go after a tie", isOn: $addHalf)
            buttons
            if isGroup {
                Text("\(group.count) × \(typeName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(minWidth: 420)
    }

    /// Roll and Set for this strip, and Roll All and Set All when the creature type has more than one.
    /// All four are filled, since a bordered button reads as plain text on the pad's light sheet.
    private var buttons: some View {
        HStack(spacing: 8) {
            if canRoll {
                Button("Roll") { set(controller.rollInitiative(for: combatant)) }
                    .buttonStyle(.borderedProminent)
                    .tint(.gray)
                    .frame(maxWidth: .infinity)
            }
            if canRoll && isGroup {
                // One die for the group, so every creature of the type shares the total.
                Button("Roll All") { setGroup(controller.rollInitiative(for: combatant)) }
                    .buttonStyle(.borderedProminent)
                    .tint(.gray)
                    .frame(maxWidth: .infinity)
            }
            Button("Set") { set(value) }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(digits.isEmpty)
            if isGroup {
                Button("Set All") { setGroup(value) }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(digits.isEmpty)
            }
        }
        .controlSize(.large)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    /// The creature's name as the group shares it, without the strip's number.
    private var typeName: String {
        guard let combatant else { return "" }
        if let name = controller.creature(for: combatant)?.name, !name.isEmpty { return name }
        return combatant.name.replacingOccurrences(of: #" \d+$"#, with: "", options: .regularExpression)
    }

    private func set(_ value: Double) { apply { $0.setInitiative(value, for: id) } }

    private func setGroup(_ value: Double) { apply { $0.setInitiative(value, forGroupOf: id) } }

    /// Applies an initiative change, bringing a benched strip in first, and keeps the turn in a fight.
    private func apply(_ edit: (inout CombatState) -> Void) {
        controller.change { state in
            if state[id]?.place == .bench { state.bringIn(id) }
            edit(&state)
            if state.phase == .active { state.sortByInitiativeKeepingCurrent() }
        }
        finish()
    }

    private func finish() {
        controller.highlightsMissingInitiative = !controller.state.combatantsWithoutInitiative.isEmpty
            && controller.highlightsMissingInitiative
        dismiss()
    }
}

extension CombatState {
    /// Re-sorts after an initiative change in the middle of a fight without changing whose turn it is.
    mutating func sortByInitiativeKeepingCurrent() {
        let current = currentID
        sortByInitiative()
        currentID = current
    }
}
