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

    /// Re-imports a linked member's sheet, keeping its name and the GM's max HP, and says what changed.
    func refreshFromDemiplane(memberID: UUID, partyID: UUID) async {
        guard let member = party(partyID)?.members.first(where: { $0.id == memberID }) else { return }
        guard let link = member.link else {
            statusMessage = "\(member.name) isn't linked to Demiplane."
            return
        }
        refreshingMemberID = memberID
        defer { refreshingMemberID = nil }
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
        var updates: [SheetUpdate] = []
        for imported in characters {
            updates.append(party.apply(imported.sheet, link: imported.link, to: memberID))
            guard let url = imported.avatarURL,
                  let member = party.members.first(where: { $0.link?.characterID == imported.link.characterID })
            else { continue }
            portraits.append((PlayerCharacter.key(for: member), url))
        }
        library.save(party)
        statusMessage = characters.count == 1 ? Self.importMessage(characters[0], updates[0], party: party)
            : "Imported \(characters.count) characters."
        for portrait in portraits {
            await storePortrait(from: portrait.url, for: portrait.key)
        }
    }

    /// "Updated Eagan Norr: AC 18 → 19.", or a hint when nothing changed, noting a signed-out import.
    private static func importMessage(_ imported: ImportedCharacter, _ update: SheetUpdate, party: Party) -> String {
        let name = party.members.first { $0.link?.characterID == imported.link.characterID }?.name
            ?? imported.sheet.name
        let message = switch update {
        case .added: "Imported \(name)."
        case .updated(let changes) where changes.isEmpty: "Updated \(name)."
        case .updated(let changes): "Updated \(name): \(changes.joined(separator: ", "))."
        case .unchanged: "No changes to \(name) on Demiplane. Has the player saved the rebuild?"
        }
        guard imported.isLastExport else { return message }
        return message + " Signed out, so Demiplane's last export was used."
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
