import TurnkeeperKit
import SwiftUI

/// What the Demiplane sheet is being imported for: a new member, or linking the quick PC with this ID.
struct DemiplaneTarget: Identifiable {
    let id = UUID()
    var memberID: UUID?
}

/// Under a party member: for a linked PC, where its sheet came from, its max HP (typed by the GM, shown on
/// the card only), its battle card, and Refresh and Unlink; for a quick PC, a way to link one.
struct MemberLinkRow: View {
    let member: PartyMember
    let partyID: UUID
    let onLink: () -> Void
    @Environment(AppModel.self) private var model
    @State private var isShowingCard = false

    var body: some View {
        if let link = member.link {
            HStack {
                VStack(alignment: .leading) {
                    Text(summary(link))
                    Text(linkedNames(link)).foregroundStyle(.secondary)
                }
                .font(.caption)
                Spacer()
                TextField("Max HP", value: maxHitPoints, format: .number, prompt: Text("Max HP"))
                    .labelsHidden()
                    .frame(width: 70)
                    .multilineTextAlignment(.trailing)
                    .help("Shown on the PC's card only; players track their own HP")
                Button("Battle Card", systemImage: "person.text.rectangle") { isShowingCard = true }
                    .help("Show the PC's battle card")
                if member.isTableBuddy {
                    // A Table Buddy's sheet comes with the app; there's nothing to refresh.
                } else if model.refreshingMemberID == member.id {
                    ProgressView().controlSize(.small)
                } else {
                    Button("Refresh", systemImage: "arrow.clockwise") {
                        Task { await model.refreshFromDemiplane(memberID: member.id, partyID: partyID) }
                    }
                    .disabled(model.demiplaneProgress != nil)
                }
                if !member.isTableBuddy {
                    Button("Unlink", systemImage: "xmark.circle", role: .destructive) {
                        model.unlinkFromDemiplane(memberID: member.id, partyID: partyID)
                    }
                    .help("Unlink from Demiplane")
                }
            }
            .buttonStyle(.borderless)
            .labelStyle(.iconOnly)
            .sheet(isPresented: $isShowingCard) { CreaturePreview(key: PlayerCharacter.key(for: member)) }
        } else {
            Button("Link to Demiplane…", systemImage: "link", action: onLink)
                .buttonStyle(.borderless)
                .font(.caption)
        }
    }

    /// "Demiplane · Human Fighter · updated 2 days ago", or "Table Buddy · Human Wizard · level 3".
    private func summary(_ link: CharacterLink) -> String {
        let player = member.sheet?.player
        let description = [player?.ancestry, player?.className].compactMap { $0 }.filter { !$0.isEmpty }
            .joined(separator: " ")
        let character = description.isEmpty ? "character" : description
        if member.isTableBuddy { return "Table Buddy · \(character) · level \(member.level ?? 1)" }
        let updated = link.fetchedAt.formatted(.relative(presentation: .named))
        return "Demiplane · \(character) · updated \(updated)"
    }

    private func linkedNames(_ link: CharacterLink) -> String {
        "\(link.linkedNames) of \(link.totalNames) spells, abilities and items linked to the rules"
    }

    private var maxHitPoints: Binding<Int?> {
        Binding { member.maxHitPoints } set: { value in
            guard var party = model.party(partyID),
                  let index = party.members.firstIndex(where: { $0.id == member.id }) else { return }
            party.members[index].maxHitPoints = value.flatMap { $0 > 0 ? $0 : nil }
            model.library.save(party)
        }
    }
}
