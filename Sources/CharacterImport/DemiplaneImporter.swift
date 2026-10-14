import Bestiary
import TurnkeeperKit
import Foundation

/// An imported character: its linked sheet, where it came from, and its portrait.
public struct ImportedCharacter: Sendable {
    public var sheet: Creature
    public var link: CharacterLink
    public var avatarURL: URL?
    /// Read signed out, from whatever Demiplane exported last, which may be older than the character.
    public var isLastExport = false
}

/// Imports Demiplane characters: identity from the API, numbers from the exported sheet PDF, and glossary
/// links by name. With a session it exports the sheet first, so it is always current; without one it
/// reads whatever was last exported.
public struct DemiplaneImporter: Sendable {
    public var client: DemiplaneClient
    public var glossary: any GlossarySource

    public init(client: DemiplaneClient, glossary: any GlossarySource) {
        self.client = client
        self.glossary = glossary
    }

    public func importCharacter(id: String, game hint: Game?) async throws -> ImportedCharacter {
        let character = try await lookUp(id, game: hint)
        let game = character?.game ?? hint
        let export = client.session == nil
            ? SheetExport(url: DemiplaneClient.publicSheetURL(id: id, game: game ?? .pathfinder), revision: "")
            : try await client.exportSheet(id: id)
        var sheet = try DemiplaneSheetReader.sheet(fromPDF: try await client.sheetPDF(at: export.url), game: game)
        if sheet.name.isEmpty { sheet.name = character?.name ?? "" }
        let linked = CharacterGlossaryLinker(glossary: glossary).link(sheet)
        var link = CharacterLink(source: .demiplane, characterID: id, game: sheet.game, revision: export.revision)
        link.linkedNames = linked.linkedNames
        link.totalNames = linked.totalNames
        return ImportedCharacter(sheet: linked.sheet, link: link, avatarURL: character?.avatarURL,
                                 isLastExport: client.session == nil)
    }

    /// The character's identity. The GraphQL API only returns the user's own characters, so a character
    /// shared with the GM is read from its sheet page instead; nil when neither has it, and the import goes
    /// by the sheet and the link's game.
    private func lookUp(_ id: String, game hint: Game?) async throws -> DemiplaneCharacter? {
        do {
            return try await client.character(id: id)
        } catch CharacterImportError.notFound {
            return try? await client.sharedCharacter(id: id, game: hint ?? .pathfinder)
        }
    }

    /// The campaign's characters, one at a time, skipping any that fail; the failures are returned too.
    public func importCampaign(id: String, game hint: Game?) async throws -> CampaignImport {
        let campaign = try await client.campaign(id: id, game: hint ?? .pathfinder)
        var result = CampaignImport(name: campaign.name)
        for characterID in campaign.characterIDs {
            do {
                result.characters.append(try await importCharacter(id: characterID, game: hint))
            } catch {
                result.failures.append(CampaignImport.Failure(characterID: characterID,
                                                              message: error.localizedDescription))
            }
        }
        return result
    }
}

/// What importing a campaign brought back.
public struct CampaignImport: Sendable {
    public struct Failure: Sendable, Equatable {
        public var characterID: String
        public var message: String
    }

    public var name: String
    public var characters: [ImportedCharacter] = []
    public var failures: [Failure] = []
}
