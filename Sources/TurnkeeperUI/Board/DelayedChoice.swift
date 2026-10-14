import TurnkeeperKit
import SwiftUI

extension View {
    /// Confirms a swipe to delay, and before the turn passes over delaying strips, asks which of them act
    /// now: yes or no for one, a list to tick for several. One modifier presents both, since an alert shown
    /// lower in the board is closed as soon as this one updates.
    func delayedChoice(controller: BoardController) -> some View {
        modifier(DelayedChoiceModifier(controller: controller))
    }
}

private struct DelayedChoiceModifier: ViewModifier {
    let controller: BoardController

    func body(content: Content) -> some View {
        content
            .alert(oneTitle, isPresented: isAsking(count: 1...1)) {
                Button("Act Now") { controller.passTurn(actingNow: Set(controller.delayedChoice.map(\.id))) }
                Button("Keep Waiting") { controller.passTurn(actingNow: []) }
                Button("Cancel", role: .cancel) { controller.cancelDelayedChoice() }
            } message: {
                Text("If it keeps waiting, it moves below the next strip.")
            }
            .alert("Delay \(controller.delayToConfirm?.name ?? "")?", isPresented: isConfirmingDelay,
                   presenting: controller.delayToConfirm) { combatant in
                Button("Delay") { controller.startDelay(combatant.id) }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("It waits below the next strip, and is asked about before each turn passes it.")
            }
            .sheet(isPresented: isAsking(count: 2...)) { DelayedChoiceSheet(controller: controller) }
    }

    private var isConfirmingDelay: Binding<Bool> {
        Binding(get: { controller.delayToConfirm != nil }, set: { if !$0 { controller.delayToConfirm = nil } })
    }

    private var oneTitle: String {
        "Does \(controller.delayedChoice.first?.name ?? "the delaying strip") act now?"
    }

    private func isAsking(count: some RangeExpression<Int>) -> Binding<Bool> {
        // The buttons answer or cancel; dismissing alone must not, since it can come before the button's action.
        Binding(get: { count.contains(controller.delayedChoice.count) }, set: { _ in })
    }
}

/// Several delaying strips ahead: tick those that act now. They go in ladder order; the rest keep waiting.
private struct DelayedChoiceSheet: View {
    let controller: BoardController
    @State private var chosen: Set<UUID> = []

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(controller.delayedChoice) { combatant in
                        Toggle(combatant.name, isOn: binding(combatant.id))
                    }
                } footer: {
                    Text("Those that act now go top to bottom. The rest move below the next strip.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Who Acts Now?")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { controller.cancelDelayedChoice() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Next Turn") { controller.passTurn(actingNow: chosen) }
                }
            }
        }
        .frame(minWidth: 360, minHeight: 280)
        .interactiveDismissDisabled()
    }

    private func binding(_ id: UUID) -> Binding<Bool> {
        Binding(get: { chosen.contains(id) },
                set: { isOn in if isOn { chosen.insert(id) } else { chosen.remove(id) } })
    }
}
