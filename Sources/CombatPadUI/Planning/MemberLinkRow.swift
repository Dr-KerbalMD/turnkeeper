import CombatPadKit
import SwiftUI

/// What the Demiplane sheet is being imported for: a new member, or linking the quick PC with this ID.
struct DemiplaneTarget: Identifiable {
    let id = UUID()
    var memberID: UUID?
}

/// Under a party member: for a linked PC, where its sheet came from, its max HP (typed by the GM, shown on
/// the card only) and Refresh and Unlink; for a quick PC, a way to link one.
struct MemberLinkRow: View {
    let member: PartyMember
    let partyID: UUID
    let onLink: () -> Void
    @Environment(AppModel.self) private var model

    var body: some View {
        if let link = member.link {
            HStack {
                VStack(alignment: .leading) {
                    Text(summary(link))
                    Text(linkedNames(link)).foregroundStyle(.secondary)
                }
                .font(.caption)
                Spacer()
                TextField("Max HP", value: maxHitPoints, format: .number)
                    .frame(width: 70)
                    .multilineTextAlignment(.trailing)
                    .help("Shown on the PC's card only; players track their own HP")
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task { await model.refreshFromDemiplane(memberID: member.id, partyID: partyID) }
                }
                .disabled(model.demiplaneProgress != nil)
                Button("Unlink", systemImage: "link.badge.minus", role: .destructive) {
                    model.unlinkFromDemiplane(memberID: member.id, partyID: partyID)
                }
            }
            .buttonStyle(.borderless)
            .labelStyle(.iconOnly)
        } else {
            Button("Link to Demiplane…", systemImage: "link", action: onLink)
                .buttonStyle(.borderless)
                .font(.caption)
        }
    }

    private func summary(_ link: CharacterLink) -> String {
        let player = member.sheet?.player
        let description = [player?.ancestry, player?.className].compactMap { $0 }.filter { !$0.isEmpty }
            .joined(separator: " ")
        let updated = link.fetchedAt.formatted(.relative(presentation: .named))
        return "Demiplane · \(description.isEmpty ? "character" : description) · updated \(updated)"
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
