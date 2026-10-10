import Bestiary
import CombatPadKit
import SwiftUI

/// The sheet for a board action.
struct BoardSheetContent: View {
    let sheet: BoardSheet
    let controller: BoardController

    var body: some View {
        switch sheet {
        case let .hitPoints(id): HitPointsPad(controller: controller, id: id)
        case let .initiative(id): InitiativePad(controller: controller, id: id)
        case let .conditions(id): ConditionPalette(controller: controller, id: id)
        case .duration: DurationEditor(controller: controller)
        case .event:
            EventEditor(event: EncounterEvent(label: "", trigger: .initiative(20)), slots: []) { event in
                controller.change { $0.addEvent(event) }
            }
        }
    }
}

/// Adds a duration arrow: a label, how many rounds, and whose turn it counts down on.
private struct DurationEditor: View {
    let controller: BoardController
    @Environment(\.dismiss) private var dismiss
    @State private var label = ""
    @State private var rounds = 1
    @State private var anchor: UUID?
    @State private var moment = TurnMoment.startOfTurn

    var body: some View {
        NavigationStack {
            Form {
                TextField("Label", text: $label, prompt: Text("Bless"))
                Stepper("\(rounds) round\(rounds == 1 ? "" : "s")", value: $rounds, in: 1...100)
                Picker("Counts down on", selection: $anchor) {
                    ForEach(controller.state.ladder) { Text($0.name).tag(UUID?.some($0.id)) }
                }
                Picker("At", selection: $moment) {
                    Text("Start of turn").tag(TurnMoment.startOfTurn)
                    Text("End of turn").tag(TurnMoment.endOfTurn)
                }
                .pickerStyle(.segmented)
            }
            .formStyle(.grouped)
            .navigationTitle("Duration Arrow")
            .onAppear { anchor = controller.state.currentID ?? controller.state.order.first }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let anchor {
                            let marker = DurationMarker(label: label.isEmpty ? "Effect" : label, rounds: rounds,
                                                        anchor: anchor, moment: moment)
                            controller.change { $0.addDuration(marker) }
                        }
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 320)
    }
}
