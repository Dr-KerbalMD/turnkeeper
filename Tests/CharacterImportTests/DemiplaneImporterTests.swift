import TurnkeeperKit
import Foundation
import Testing
@testable import CharacterImport

@Suite("Importing Demiplane characters")
struct DemiplaneImporterTests {
    private func importer(_ transport: FakeTransport, signedIn: Bool) -> DemiplaneImporter {
        let session = signedIn ? DemiplaneSession(cookieHeader: "access_token=a") : nil
        var client = DemiplaneClient(transport: transport, token: "token", session: session)
        client.sleep = { _ in }
        return DemiplaneImporter(client: client, glossary: SmallGlossary())
    }

    @Test("Signed in: export, download, read and link, with the export's revision")
    func signedIn() async throws {
        let transport = FakeTransport()
        transport.respond(to: TestData.graphQLPath, json: TestData.character)
        transport.respond(to: TestData.exportPath, status: 202, body: Data())
        transport.respond(to: TestData.exportPath, json: TestData.exportDone(revision: "abc"))
        transport.respond(to: "/sheet.pdf", body: try TestData.sheetPDF())
        let imported = try await importer(transport, signedIn: true).importCharacter(id: TestData.characterID,
                                                                                     game: nil)
        #expect(imported.sheet.name == "Dr Ignatius Constaline" && imported.sheet.defenses.armorClass == 33)
        #expect(imported.link.characterID == TestData.characterID && imported.link.revision == "abc")
        #expect(imported.link.game == .pathfinder && imported.link.source == .demiplane)
        #expect(imported.sheet.links?.target(.ability, "Toughness") == "pf2e.feats-srd.toughness")
        #expect(imported.link.linkedNames >= 2 && imported.link.totalNames > imported.link.linkedNames)
        #expect(imported.avatarURL?.host == "example.com")
    }

    @Test("Signed out: the last exported sheet is read from its public address")
    func signedOut() async throws {
        let transport = FakeTransport()
        transport.respond(to: TestData.graphQLPath, json: TestData.character)
        let url = DemiplaneClient.publicSheetURL(id: TestData.characterID, game: .pathfinder)
        transport.respond(to: url.path, body: try TestData.sheetPDF())
        let imported = try await importer(transport, signedIn: false).importCharacter(id: TestData.characterID,
                                                                                      game: .starfinder)
        #expect(imported.link.revision.isEmpty && imported.link.game == .pathfinder && imported.isLastExport)
        #expect(transport.requests(to: TestData.exportPath).isEmpty)
    }

    @Test("A second import after a rebuild reads the new export, not a cached sheet")
    func reimport() async throws {
        let transport = FakeTransport()
        transport.respond(to: TestData.graphQLPath, json: ["data": ["demiplane_user_character": []]])
        transport.respond(to: TestData.exportPath, json: TestData.exportDone(revision: "r1"))
        transport.respond(to: TestData.exportPath, json: TestData.exportDone(revision: "r2"))
        transport.respond(to: "/sheet.pdf", body: try TestData.sheetPDF("ignatius"))
        transport.respond(to: "/sheet.pdf", body: try TestData.sheetPDF("eagan"))
        let importer = importer(transport, signedIn: true)
        let first = try await importer.importCharacter(id: TestData.characterID, game: nil)
        let second = try await importer.importCharacter(id: TestData.characterID, game: nil)
        #expect(first.link.revision == "r1" && first.sheet.name == "Dr Ignatius Constaline")
        #expect(second.link.revision == "r2" && second.sheet.name == "Eagan Norr (v.2)")
        #expect(!first.isLastExport && !second.isLastExport)
    }

    @Test("Requests to Demiplane skip the URL cache")
    func uncached() async throws {
        let transport = FakeTransport()
        transport.respond(to: TestData.graphQLPath, json: TestData.character)
        transport.respond(to: TestData.exportPath, json: TestData.exportDone())
        transport.respond(to: "/sheet.pdf", body: try TestData.sheetPDF())
        _ = try await importer(transport, signedIn: true).importCharacter(id: TestData.characterID, game: nil)
        #expect(!transport.requests.isEmpty)
        #expect(transport.requests.allSatisfy { $0.cachePolicy == .reloadIgnoringLocalCacheData })
    }

    @Test("A campaign imports each character, keeping the failures")
    func campaign() async throws {
        let transport = FakeTransport()
        transport.respond(to: "/api/getCampaign", json: ["campaignResponse": [
            "campaign": ["name": "Friday"],
            "campaignUserCharacters": [["user_character": ["uuid": TestData.characterID]],
                                       ["user_character": ["uuid": "missing"]]]
        ]])
        transport.respond(to: TestData.graphQLPath, json: TestData.character)
        transport.respond(to: TestData.graphQLPath, json: ["data": ["demiplane_user_character": []]])
        transport.respond(to: TestData.exportPath, json: TestData.exportDone())
        transport.respond(to: TestData.exportPath, status: 500, body: Data())
        transport.respond(to: "/sheet.pdf", body: try TestData.sheetPDF())
        let result = try await importer(transport, signedIn: true).importCampaign(id: "camp", game: .starfinder)
        #expect(result.name == "Friday" && result.characters.count == 1)
        #expect(result.failures.map(\.characterID) == ["missing"])
        #expect(result.failures.first?.message.contains("answered 500") == true)
        #expect(transport.requests(to: "/api/getCampaign").first?.value(forHTTPHeaderField: "Client-Pathname")
                == "/nexus/starfinder2e/campaigns/camp")
    }

    @Test("A character the API won't show (another player's) is imported from its sheet and the link's game")
    func otherPlayersCharacter() async throws {
        let transport = FakeTransport()
        transport.respond(to: TestData.graphQLPath, json: ["data": ["demiplane_user_character": []]])
        transport.respond(to: TestData.exportPath, json: TestData.exportDone(revision: "r1"))
        transport.respond(to: "/sheet.pdf", body: try TestData.sheetPDF())
        let imported = try await importer(transport, signedIn: true).importCharacter(id: TestData.characterID,
                                                                                     game: .pathfinder)
        #expect(imported.sheet.name == "Dr Ignatius Constaline" && imported.link.revision == "r1")
        #expect(imported.avatarURL == nil)
    }
}

@Suite("Demiplane token")
struct DemiplaneTokenTests {
    @Test("A pasted token loses its Bearer prefix and whitespace")
    func normalized() {
        #expect(DemiplaneToken.normalized("  Bearer abc.def.ghi\n") == "abc.def.ghi")
        #expect(DemiplaneToken.normalized("abc") == "abc")
    }

    @Test("Expiry comes from the JWT's exp claim")
    func expiry() throws {
        let future = Date(timeIntervalSince1970: 1_900_000_000)
        let token = TestData.token(expiring: future)
        #expect(DemiplaneToken.expiry(of: token) == future)
        #expect(!DemiplaneToken.isExpired(token, at: future.addingTimeInterval(-1)))
        #expect(DemiplaneToken.isExpired("Bearer " + token, at: future))
        #expect(DemiplaneToken.expiry(of: "not-a-jwt") == nil && !DemiplaneToken.isExpired("not-a-jwt"))
    }

    @Test("The Keychain keeps one token per account")
    func keychain() throws {
        let store = KeychainTokenStore(service: "io.github.scooper4711.turnkeeper.tests", account: UUID().uuidString)
        defer { store.delete() }
        #expect(store.read() == nil)
        try store.save("first")
        try store.save("second")
        #expect(store.read() == "second")
        store.delete()
        #expect(store.read() == nil)
    }
}
