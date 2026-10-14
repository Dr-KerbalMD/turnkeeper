import TurnkeeperKit
import SwiftUI

/// A party's name, level and members. Players track their own HP, so a member is a name and level, linked
/// to a Demiplane character for a battle card if the GM likes.
struct PartyEditorView: View {
    let party: Party
    @Environment(AppModel.self) private var model
    @State private var demiplaneTarget: DemiplaneTarget?

    var body: some View {
        Form {
            Section {
                TextField("Name", text: binding(\.name)).nameEntry()
                Stepper("Level \(party.level)", value: binding(\.level), in: -1...25)
            }
            Section("Members") {
                ForEach(party.members) { member in
                    HStack {
                        TextField("Name", text: memberName(member.id)).nameEntry()
                            .foregroundStyle(member.isAway ? .secondary : .primary)
                        Stepper("Level \(member.level ?? party.level)", value: levelBinding(member.id), in: 1...20)
                            .fixedSize()
                        Toggle(isOn: awayBinding(member.id)) {
                            Label("Away", systemImage: member.isAway ? "moon.zzz.fill" : "person.fill.checkmark")
                        }
                        .toggleStyle(.button)
                        .buttonStyle(.borderless)
                        .help(member.isAway ? "Away: not in budgets; waits on the bench in fights"
                                            : "At the table")
                    }
                    .modifier(memberActions(member))
                    MemberLinkRow(member: member, partyID: party.id) {
                        demiplaneTarget = DemiplaneTarget(memberID: member.id)
                    }
                    .modifier(memberActions(member))
                }
                .onMove { source, target in update { $0.members.move(fromOffsets: source, toOffset: target) } }
                Button("Add Member", systemImage: "plus") {
                    update { $0.members.append(PartyMember(name: "Player \($0.members.count + 1)")) }
                }
                Button("Add from Demiplane…", systemImage: "person.crop.rectangle.badge.plus") {
                    demiplaneTarget = DemiplaneTarget(memberID: nil)
                }
            }
            Section {
                Text("\(party.presentMembers.count) of \(party.members.count) at the table: budgets are worked out "
                     + "for them. Away players wait on the bench in fights, ready to join if they arrive.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(party.name)
        .sheet(item: $demiplaneTarget) { target in
            DemiplaneImportSheet(partyID: party.id, memberID: target.memberID)
        }
    }

    /// Swipe right to left to remove a member, left to right to mark them away or back; the context menu
    /// and the Delete key do the same on the Mac.
    private func memberActions(_ member: PartyMember) -> MemberRowActions {
        MemberRowActions(member: member,
                         remove: { update { $0.members.removeAll { $0.id == member.id } } },
                         toggleAway: { awayBinding(member.id).wrappedValue.toggle() })
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

    /// A member's level, which follows the party's level until it is changed.
    private func levelBinding(_ id: UUID) -> Binding<Int> {
        Binding(get: { party.members.first { $0.id == id }?.level ?? party.level },
                set: { level in update { party in
                    guard let index = party.members.firstIndex(where: { $0.id == id }) else { return }
                    party.members[index].level = level
                } })
    }

    private func awayBinding(_ id: UUID) -> Binding<Bool> {
        Binding(get: { party.members.first { $0.id == id }?.isAway ?? false },
                set: { away in update { party in
                    guard let index = party.members.firstIndex(where: { $0.id == id }) else { return }
                    party.members[index].isAway = away
                } })
    }

    private func memberName(_ id: UUID) -> Binding<String> {
        Binding(get: { party.members.first { $0.id == id }?.name ?? "" },
                set: { name in update { party in
                    if let index = party.members.firstIndex(where: { $0.id == id }) { party.members[index].name = name }
                } })
    }
}

/// A party member's row actions: Remove and Away (or Back) by swipe, context menu and, for Remove, the
/// Delete key.
private struct MemberRowActions: ViewModifier {
    let member: PartyMember
    let remove: () -> Void
    let toggleAway: () -> Void

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .trailing) {
                Button("Remove", systemImage: "trash", role: .destructive, action: remove)
            }
            .swipeActions(edge: .leading) {
                Button(awayTitle, systemImage: awayImage, action: toggleAway).tint(.indigo)
            }
            .contextMenu {
                Button(awayTitle, systemImage: awayImage, action: toggleAway)
                Button("Remove", systemImage: "trash", role: .destructive, action: remove)
            }
            .deleteCommand(perform: remove)
    }

    private var awayTitle: String { member.isAway ? "Back" : "Away" }
    private var awayImage: String { member.isAway ? "person.fill.checkmark" : "moon.zzz.fill" }
}
