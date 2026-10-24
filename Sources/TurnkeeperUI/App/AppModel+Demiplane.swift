import CharacterImport
import TurnkeeperKit
import Foundation

/// Importing party members from Demiplane, and keeping them linked.
extension AppModel {
    /// Imports the character a link, ID or QR code points at into a party. It updates the member linked to
    /// it, or `memberID` (a quick PC being linked), or joins as a new member. False when it failed, with
    /// `errorMessage` set.
    @discardableResult
    func importFromDemiplane(_ reference: DemiplaneReference, partyID: UUID, memberID: UUID? = nil) async -> Bool {
        await runDemiplane("Importing from Demiplane…", reference: reference) { importer in
            let imported = try await importer.importCharacter(id: reference.id, game: reference.game ?? self.game)
            await self.add(imported, to: partyID, memberID: memberID)
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
        await importFromDemiplane(DemiplaneReference(id: link.characterID, game: link.game), partyID: partyID,
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

    /// Adds an imported character to a party, matching members by their Demiplane character.
    func add(_ imported: ImportedCharacter, to partyID: UUID, memberID: UUID? = nil) async {
        guard var party = party(partyID) else { return }
        let update = party.apply(imported.sheet, link: imported.link, to: memberID)
        library.save(party)
        statusMessage = Self.importMessage(imported, update, party: party)
        guard let url = imported.avatarURL,
              let member = party.members.first(where: { $0.link?.characterID == imported.link.characterID })
        else { return }
        await storePortrait(from: url, for: PlayerCharacter.key(for: member))
    }

    /// "Updated Eagan Norr: AC 18 → 19.", or a hint when nothing changed.
    private static func importMessage(_ imported: ImportedCharacter, _ update: SheetUpdate, party: Party) -> String {
        let name = party.members.first { $0.link?.characterID == imported.link.characterID }?.name
            ?? imported.sheet.name
        return switch update {
        case .added: "Imported \(name)."
        case .updated(let changes) where changes.isEmpty: "Updated \(name)."
        case .updated(let changes): "Updated \(name): \(changes.joined(separator: ", "))."
        case .unchanged: "No changes to \(name) on Demiplane. Has the player saved the rebuild?"
        }
    }

    private func runDemiplane(
        _ progress: String, reference: DemiplaneReference, _ work: (DemiplaneImporter) async throws -> Void
    ) async -> Bool {
        demiplaneProgress = progress
        defer { demiplaneProgress = nil }
        errorSheetURL = nil
        do {
            let importer = DemiplaneImporter(client: DemiplaneClient(transport: URLSession.shared), glossary: bestiary)
            try await work(importer)
            return true
        } catch {
            errorMessage = error.localizedDescription
            if (error as? CharacterImportError)?.isFixedByOpeningSheet == true {
                errorSheetURL = reference.sheetURL(defaultGame: game)
            }
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
