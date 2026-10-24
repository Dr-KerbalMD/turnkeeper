import TurnkeeperKit
import SwiftUI

/// A party's name, level and members. Players track their own HP, so a member is a name and level, linked
/// to a Demiplane character for a battle card if the GM likes.
struct PartyEditorView: View {
    let party: Party
    @Environment(AppModel.self) private var model
    @State private var demiplaneTarget: DemiplaneTarget?
    @State private var isPickingTableBuddy = false

    var body: some View {
        Form {
            Section {
                TextField("Name", text: binding(\.name)).nameEntry()
                Stepper("Level \(party.level)", value: binding(\.level), in: -1...25)
            }
            Section("Members") {
                ForEach(party.members) { member in
                    // One row per member, so the form's dividers fall between characters.
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("Name", text: memberBinding(member.id, \.name), prompt: Text("Character name"))
                                .labelsHidden()
                                .textFieldStyle(.plain)
                                .nameEntry()
                                .font(.title3.bold())
                                .foregroundStyle(member.isAway ? .secondary : .primary)
                            // Named, not just an icon, so it reads as the way to bench a player.
                            Toggle(isOn: awayBinding(member.id)) {
                                Label(member.isAway ? "Away" : "At Table",
                                      systemImage: member.isAway ? "moon.zzz.fill" : "person.fill.checkmark")
                            }
                            .toggleStyle(.button)
                            .buttonStyle(.borderless)
                            .labelStyle(.titleAndIcon)
                            .fixedSize()
                            .help(member.isAway ? "Away: not in budgets; waits on the bench in fights"
                                                : "At the table")
                        }
                        if member.isTableBuddy {
                            LabeledContent("Level \(member.level ?? party.level)",
                                           value: "set by the scenario's challenge points")
                        } else {
                            Stepper("Level \(member.level ?? party.level)", value: levelBinding(member.id),
                                    in: 1...20)
                        }
                        MemberPlayerRow(playerName: memberBinding(member.id, \.playerName),
                                        notes: memberBinding(member.id, \.notes))
                        MemberLinkRow(member: member, partyID: party.id) {
                            demiplaneTarget = DemiplaneTarget(memberID: member.id)
                        }
                    }
                    .padding(.vertical, 6)
                    .modifier(memberActions(member))
                }
                .onMove { source, target in update { $0.members.move(fromOffsets: source, toOffset: target) } }
                Button("Add Member", systemImage: "plus") {
                    update { $0.members.append(PartyMember(name: "Player \($0.members.count + 1)")) }
                }
                Button("Add from Demiplane…", systemImage: "person.crop.rectangle.badge.plus") {
                    demiplaneTarget = DemiplaneTarget(memberID: nil)
                }
                if !model.tableBuddyChoices.isEmpty {
                    Button("Add Table Buddy…", systemImage: "person.2.badge.plus") { isPickingTableBuddy = true }
                        .help("Add an iconic pregen to fill out a small table")
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
        .sheet(isPresented: $isPickingTableBuddy) { TableBuddyPicker(partyID: party.id) }
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

    private func memberBinding(_ id: UUID, _ path: WritableKeyPath<PartyMember, String>) -> Binding<String> {
        Binding(get: { party.members.first { $0.id == id }?[keyPath: path] ?? "" },
                set: { value in update { party in
                    if let index = party.members.firstIndex(where: { $0.id == id }) {
                        party.members[index][keyPath: path] = value
                    }
                } })
    }
}

/// Who plays the character, and the GM's notes about them, such as their Discord handle.
private struct MemberPlayerRow: View {
    @Binding var playerName: String
    @Binding var notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Player", text: $playerName, prompt: Text("Player's name")).nameEntry()
            TextField("Notes", text: $notes, prompt: Text("Notes, such as their Discord handle"), axis: .vertical)
                .lineLimit(1...4)
        }
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
            // The whole row, gaps included, answers a right-click.
            .contentShape(Rectangle())
            .contextMenu {
                Button(awayTitle, systemImage: awayImage, action: toggleAway)
                Button("Remove", systemImage: "trash", role: .destructive, action: remove)
            }
            .deleteCommand(perform: remove)
    }

    private var awayTitle: String { member.isAway ? "Back" : "Away" }
    private var awayImage: String { member.isAway ? "person.fill.checkmark" : "moon.zzz.fill" }
}
