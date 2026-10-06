import CharacterImport
import CombatPadKit
import Foundation

/// Importing party members from Demiplane, and keeping them linked.
extension AppModel {
    /// Imports what a link, ID or QR code points at into a party. A character updates the member linked to
    /// it, or `memberID` (a quick PC being linked), or joins as a new member; a campaign waits in
    /// `campaignImport` for the GM to choose its characters. False when it failed, with `errorMessage` set.
    @discardableResult
    func importFromDemiplane(_ reference: DemiplaneReference, partyID: UUID, memberID: UUID? = nil) async -> Bool {
        await runDemiplane("Importing from Demiplane…") { importer in
            switch reference {
            case let .character(id, game):
                let imported = try await importer.importCharacter(id: id, game: game ?? self.game)
                await self.add([imported], to: partyID, memberID: memberID)
            case let .campaign(id, game):
                let campaign = try await importer.importCampaign(id: id, game: game ?? self.game)
                self.campaignImport = PendingCampaignImport(partyID: partyID, result: campaign)
            }
        }
    }

    /// Re-imports a linked member's sheet, keeping its name and the GM's max HP.
    func refreshFromDemiplane(memberID: UUID, partyID: UUID) async {
        guard let link = party(partyID)?.members.first(where: { $0.id == memberID })?.link else { return }
        await importFromDemiplane(.character(id: link.characterID, game: link.game), partyID: partyID,
                                  memberID: memberID)
    }

    /// Makes a linked member a quick PC again: the name and level stay.
    func unlinkFromDemiplane(memberID: UUID, partyID: UUID) {
        updateMember(memberID, in: partyID) { member in
            member.sheet = nil
            member.link = nil
        }
        removeArtwork(for: PlayerCharacter.key(memberID: memberID))
    }

    /// Adds imported characters to a party, matching members by their Demiplane character.
    func add(_ characters: [ImportedCharacter], to partyID: UUID, memberID: UUID? = nil) async {
        guard var party = party(partyID) else { return }
        var portraits: [(key: String, url: URL)] = []
        for imported in characters {
            let index = party.members.firstIndex { $0.id == memberID }
                ?? party.members.firstIndex { $0.link?.characterID == imported.link.characterID }
                ?? party.members.endIndex
            if index == party.members.endIndex { party.members.append(PartyMember(name: imported.sheet.name)) }
            party.members[index].sheet = imported.sheet
            party.members[index].link = imported.link
            party.members[index].level = imported.sheet.level
            if let url = imported.avatarURL { portraits.append((PlayerCharacter.key(for: party.members[index]), url)) }
        }
        library.save(party)
        statusMessage = characters.count == 1 ? "Imported \(characters[0].sheet.name)."
            : "Imported \(characters.count) characters."
        for portrait in portraits {
            await storePortrait(from: portrait.url, for: portrait.key)
        }
    }

    private func runDemiplane(_ progress: String, _ work: (DemiplaneImporter) async throws -> Void) async -> Bool {
        demiplaneProgress = progress
        defer { demiplaneProgress = nil }
        do {
            let importer = DemiplaneImporter(client: try await demiplane.client(), glossary: bestiary)
            try await work(importer)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// The Demiplane avatar becomes the PC's pasted art, for the card back the players see.
    private func storePortrait(from url: URL, for key: String) async {
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return }
        await setArtwork(data, for: key)
    }

    private func updateMember(_ memberID: UUID, in partyID: UUID, _ change: (inout PartyMember) -> Void) {
        guard var party = party(partyID), let index = party.members.firstIndex(where: { $0.id == memberID }) else {
            return
        }
        change(&party.members[index])
        library.save(party)
    }
}

/// A campaign's imported characters, waiting for the GM to choose which join the party.
struct PendingCampaignImport: Identifiable {
    let id = UUID()
    var partyID: UUID
    var result: CampaignImport
}
