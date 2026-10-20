import TurnkeeperKit
import Foundation
import Testing
@testable import CharacterImport

@Suite("Importing Demiplane characters")
struct DemiplaneImporterTests {
    private func importer(_ transport: FakeTransport) -> DemiplaneImporter {
        var client = DemiplaneClient(transport: transport)
        client.sleep = { _ in }
        return DemiplaneImporter(client: client, glossary: SmallGlossary())
    }

    /// The sheet page Demiplane serves for the test character, with its avatar.
    private func respondWithPage(_ transport: FakeTransport) {
        let page = DemiplaneSheetPageTests.page(id: TestData.characterID,
                                                avatar: #"\"https://example.com/avatar.png\""#, nexus: "1")
        transport.respond(to: TestData.sheetPagePath, body: Data(page.utf8))
    }

    @Test("Export, download, read and link, with the export's revision and the page's avatar")
    func importsCharacter() async throws {
        let transport = FakeTransport()
        respondWithPage(transport)
        transport.respond(to: TestData.exportPath, status: 202, body: Data())
        transport.respond(to: TestData.exportPath, json: TestData.exportDone(revision: "abc"))
        transport.respond(to: "/sheet.pdf", body: try TestData.sheetPDF())
        let imported = try await importer(transport).importCharacter(id: TestData.characterID, game: nil)
        #expect(imported.sheet.name == "Dr Ignatius Constaline" && imported.sheet.defenses.armorClass == 33)
        #expect(imported.link.characterID == TestData.characterID && imported.link.revision == "abc")
        #expect(imported.link.game == .pathfinder && imported.link.source == .demiplane)
        #expect(imported.sheet.links?.target(.ability, "Toughness") == "pf2e.feats-srd.toughness")
        #expect(imported.link.linkedNames >= 2 && imported.link.totalNames > imported.link.linkedNames)
        #expect(imported.avatarURL?.host == "example.com")
    }

    @Test("A second import after a rebuild reads the new export, not a cached sheet")
    func reimport() async throws {
        let transport = FakeTransport()
        transport.respond(to: TestData.exportPath, json: TestData.exportDone(revision: "r1"))
        transport.respond(to: TestData.exportPath, json: TestData.exportDone(revision: "r2"))
        transport.respond(to: "/sheet.pdf", body: try TestData.sheetPDF("ignatius"))
        transport.respond(to: "/sheet.pdf", body: try TestData.sheetPDF("eagan"))
        let importer = importer(transport)
        let first = try await importer.importCharacter(id: TestData.characterID, game: nil)
        let second = try await importer.importCharacter(id: TestData.characterID, game: nil)
        #expect(first.link.revision == "r1" && first.sheet.name == "Dr Ignatius Constaline")
        #expect(second.link.revision == "r2" && second.sheet.name == "Eagan Norr (v.2)")
    }

    @Test("Requests to Demiplane skip the URL cache and carry no cookies or token")
    func uncached() async throws {
        let transport = FakeTransport()
        respondWithPage(transport)
        transport.respond(to: TestData.exportPath, json: TestData.exportDone())
        transport.respond(to: "/sheet.pdf", body: try TestData.sheetPDF())
        _ = try await importer(transport).importCharacter(id: TestData.characterID, game: nil)
        #expect(transport.requests.count == 3)
        #expect(transport.requests.allSatisfy { $0.cachePolicy == .reloadIgnoringLocalCacheData })
        #expect(transport.requests.allSatisfy {
            $0.value(forHTTPHeaderField: "Cookie") == nil && $0.value(forHTTPHeaderField: "Authorization") == nil
        })
    }

    @Test("Without the sheet page, the character is imported from its sheet and the link's game")
    func withoutPage() async throws {
        let transport = FakeTransport()
        transport.respond(to: TestData.exportPath, json: TestData.exportDone(revision: "r1"))
        transport.respond(to: "/sheet.pdf", body: try TestData.sheetPDF())
        let imported = try await importer(transport).importCharacter(id: TestData.characterID, game: .pathfinder)
        #expect(imported.sheet.name == "Dr Ignatius Constaline" && imported.link.revision == "r1")
        #expect(imported.avatarURL == nil)
    }

    @Test("A character that isn't shared isn't imported")
    func notShared() async throws {
        let transport = FakeTransport()
        transport.respond(to: TestData.exportPath, status: 403, body: Data())
        await #expect(throws: CharacterImportError.self) {
            try await importer(transport).importCharacter(id: TestData.characterID, game: nil)
        }
    }
}
