import CombatPadKit
import Foundation
import Testing
@testable import CharacterImport

@Suite("Reading a shared character from its sheet page")
struct DemiplaneSheetPageTests {
    static let id = "2c618057-53a1-4b59-a198-707b7b319a4a"

    /// The shape Demiplane's sheet page embeds: React data inside a string, so every quote is escaped.
    static func page(id: String = id, avatar: String = "null", nexus: String = "100") -> String {
        #"<script>self.__next_f.push([1,"52:[\"$\",\"$L53\",null,{\"characterSheetContent\":{\"character\":"#
            + #"{\"id\":\"2433650\",\"uuid\":\"\#(id)\",\"user_id\":\"891208\",\"nexus_id\":\"\#(nexus)\","#
            + #"\"level\":3,\"class\":null,\"view_permission\":2,\"name\":\"Zoë \\\"Spark\\\" Vance\","#
            + #"\"avatar_url\":\#(avatar),\"data\":{\"engines\":[{\"name\":\"other\",\"level\":9}]}}}]"])</script>"#
    }

    @Test("The name, level, game and avatar come from the embedded record")
    func readsTheRecord() throws {
        let character = try #require(DemiplaneClient.sharedCharacter(id: Self.id, inPage: Self.page()))
        #expect(character.name == "Zoë \"Spark\" Vance" && character.level == 3)
        #expect(character.game == .starfinder && character.avatarURL == nil)
        let pictured = DemiplaneClient.sharedCharacter(
            id: Self.id, inPage: Self.page(avatar: #"\"https://example.com/a.png\""#, nexus: "1"))
        #expect(pictured?.avatarURL?.host == "example.com" && pictured?.game == .pathfinder)
    }

    @Test("A page without the character, or for another character, gives nothing")
    func missingRecord() {
        #expect(DemiplaneClient.sharedCharacter(id: Self.id, inPage: "<html></html>") == nil)
        #expect(DemiplaneClient.sharedCharacter(id: Self.id, inPage: Self.page(id: "other")) == nil)
        #expect(DemiplaneClient.game(nexusID: "7") == nil)
    }

    @Test("A shared character is fetched from its page when the API doesn't return it")
    func importsSharedCharacter() async throws {
        let transport = FakeTransport()
        transport.respond(to: TestData.graphQLPath, json: ["data": ["demiplane_user_character": []]])
        let page = Self.page(id: TestData.characterID, avatar: #"\"https://example.com/a.png\""#)
        transport.respond(to: "/nexus/starfinder2e/character-sheet/\(TestData.characterID)", body: Data(page.utf8))
        transport.respond(to: TestData.exportPath, json: TestData.exportDone())
        transport.respond(to: "/sheet.pdf", body: try TestData.sheetPDF())
        var client = DemiplaneClient(transport: transport, token: "token",
                                     session: DemiplaneSession(cookieHeader: "access_token=a"))
        client.sleep = { _ in }
        let imported = try await DemiplaneImporter(client: client, glossary: SmallGlossary())
            .importCharacter(id: TestData.characterID, game: .starfinder)
        #expect(imported.avatarURL?.host == "example.com")
        let request = try #require(
            transport.requests(to: "/nexus/starfinder2e/character-sheet/\(TestData.characterID)").first)
        #expect(request.value(forHTTPHeaderField: "Cookie") == "access_token=a")
    }

    @Test("A page that fails leaves the import to the sheet")
    func pageFails() async throws {
        let transport = FakeTransport()
        transport.respond(to: "/nexus/pathfinder2e/character-sheet/x", status: 404, body: Data())
        let client = DemiplaneClient(transport: transport, token: nil, session: nil)
        #expect(try await client.sharedCharacter(id: "x", game: .pathfinder) == nil)
    }
}
