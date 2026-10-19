import Bestiary
import TurnkeeperKit
import Foundation

/// An imported character: its linked sheet, where it came from, and its portrait.
public struct ImportedCharacter: Sendable {
    public var sheet: Creature
    public var link: CharacterLink
    public var avatarURL: URL?
}

/// Imports shared Demiplane characters: identity from the sheet page, numbers from a freshly exported sheet
/// PDF, and glossary links by name.
public struct DemiplaneImporter: Sendable {
    public var client: DemiplaneClient
    public var glossary: any GlossarySource

    public init(client: DemiplaneClient, glossary: any GlossarySource) {
        self.client = client
        self.glossary = glossary
    }

    /// When the sheet page doesn't describe the character, the import goes on with the link's game and the
    /// sheet's name.
    public func importCharacter(id: String, game hint: Game?) async throws -> ImportedCharacter {
        let character = try? await client.sharedCharacter(id: id, game: hint ?? .pathfinder)
        let game = character?.game ?? hint
        let export = try await client.exportSheet(id: id)
        var sheet = try DemiplaneSheetReader.sheet(fromPDF: try await client.sheetPDF(at: export.url), game: game)
        if sheet.name.isEmpty { sheet.name = character?.name ?? "" }
        let linked = CharacterGlossaryLinker(glossary: glossary).link(sheet)
        var link = CharacterLink(source: .demiplane, characterID: id, game: sheet.game, revision: export.revision)
        link.linkedNames = linked.linkedNames
        link.totalNames = linked.totalNames
        return ImportedCharacter(sheet: linked.sheet, link: link, avatarURL: character?.avatarURL)
    }
}
