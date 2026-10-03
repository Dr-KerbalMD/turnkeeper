import CombatPadKit
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

/// Sets a combatant's initiative, with a half for breaking ties.
struct InitiativePad: View {
    let controller: BoardController
    let id: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var digits = ""
    @State private var addHalf = false

    var body: some View {
        VStack(spacing: 14) {
            Text(controller.state[id]?.name ?? "").font(.title2.bold())
            NumberPad(digits: $digits)
            Toggle("Add ½ to go after a tie", isOn: $addHalf)
            HStack {
                if controller.state[id]?.kind != .playerCharacter {
                    Button("Roll") { set(controller.rollInitiative(for: controller.state[id])) }
                        .frame(maxWidth: .infinity)
                }
                Button("Set") { set(Double(Int(digits) ?? 0) + (addHalf ? 0.5 : 0)) }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(digits.isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 340)
    }

    private func set(_ value: Double) {
        controller.change { state in
            state.setInitiative(value, for: id)
            if state.phase == .active { state.sortByInitiativeKeepingCurrent() }
        }
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
