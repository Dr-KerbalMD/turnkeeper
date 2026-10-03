import CombatPadKit
import SwiftUI

/// A party's name, level and members. Players track their own HP, so members are just names.
struct PartyEditorView: View {
    let party: Party
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section {
                TextField("Name", text: binding(\.name))
                Stepper("Level \(party.level)", value: binding(\.level), in: -1...25)
            }
            Section("Members") {
                ForEach(party.members) { member in
                    TextField("Name", text: memberName(member.id))
                }
                .onDelete { offsets in update { $0.members.remove(atOffsets: offsets) } }
                .onMove { source, target in update { $0.members.move(fromOffsets: source, toOffset: target) } }
                Button("Add Member", systemImage: "plus") {
                    update { $0.members.append(PartyMember(name: "Player \($0.members.count + 1)")) }
                }
            }
            Section {
                Text("\(party.members.count) members: budgets are worked out for this size and level.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(party.name)
    }

    private func update(_ change: (inout Party) -> Void) {
        var edited = model.party(party.id) ?? party
        change(&edited)
        model.library.save(edited)
    }

    private func binding<Value>(_ path: WritableKeyPath<Party, Value>) -> Binding<Value> {
        Binding(get: { (model.party(party.id) ?? party)[keyPath: path] },
                set: { value in update { $0[keyPath: path] = value } })
    }

    private func memberName(_ id: UUID) -> Binding<String> {
        Binding(get: { party.members.first { $0.id == id }?.name ?? "" },
                set: { name in update { party in
                    if let index = party.members.firstIndex(where: { $0.id == id }) { party.members[index].name = name }
                } })
    }
}
