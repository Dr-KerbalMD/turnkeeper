import CombatPadKit
import SwiftUI

/// The turn reminders, one card at a time. Each must be dismissed before the fight can move on.
struct ReminderStack: View {
    let controller: BoardController
    @State private var damage = ""

    var body: some View {
        if let reminder = controller.reminders.first {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "bell.badge.fill").font(.title).foregroundStyle(.orange)
                    VStack(alignment: .leading) {
                        if let name = reminder.combatantID.flatMap({ controller.state[$0]?.name }) {
                            Text(name).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Text(reminder.title).font(.title.bold())
                    }
                    Spacer()
                    Text("\(controller.reminders.count) to go").font(.caption).foregroundStyle(.secondary)
                }
                if !reminder.text.isEmpty { Text(reminder.text).font(.title3) }
                actions(for: reminder)
                Button {
                    controller.dismissReminder()
                } label: {
                    Text("Got It").font(.headline).frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(28)
            .frame(minWidth: 460)
            .interactiveDismissDisabled()
            .sensoryFeedback(.warning, trigger: reminder.id)
            .id(reminder.id)
        }
    }

    @ViewBuilder
    private func actions(for reminder: Reminder) -> some View {
        ForEach(Array(reminder.actions.enumerated()), id: \.offset) { _, action in
            switch action {
            case .takeDamage:
                HStack {
                    TextField("Damage rolled", text: $damage)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 160)
                    Button("Take Damage") {
                        controller.amend { $0.apply(action, amount: Int(damage) ?? 0) }
                        damage = ""
                    }
                    .disabled(Int(damage) == nil)
                }
            case .removeCondition:
                Button("Recovered (flat check succeeded)", systemImage: "checkmark.seal") {
                    controller.dismissReminder(applying: action)
                }
            case let .recoveryCheck(degree, _):
                Button(label(for: degree)) { controller.dismissReminder(applying: action) }
            case .undoAutomaticChange:
                Button("Undo This Change", systemImage: "arrow.uturn.backward") {
                    controller.dismissReminder(applying: action)
                }
            case .bringIn:
                Button("Bring Them In", systemImage: "arrow.up.circle") { controller.dismissReminder(applying: action) }
            }
        }
    }

    private func label(for degree: DegreeOfSuccess) -> String {
        switch degree {
        case .criticalSuccess: return "Critical success (dying −2)"
        case .success: return "Success (dying −1)"
        case .failure: return "Failure (dying +1)"
        case .criticalFailure: return "Critical failure (dying +2)"
        }
    }
}
