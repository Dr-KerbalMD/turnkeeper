import CombatPadKit
import Foundation
import Testing
@testable import CharacterImport

@Suite("Demiplane client")
struct DemiplaneClientTests {
    private let session = DemiplaneSession(cookieHeader: "access_token=abc; refresh_token=def")

    private func client(_ transport: FakeTransport, token: String? = "token", signedIn: Bool = true)
    -> DemiplaneClient {
        var client = DemiplaneClient(transport: transport, token: token, session: signedIn ? session : nil)
        client.sleep = { _ in }
        return client
    }

    @Test("A character's identity comes from GraphQL with the bearer token")
    func character() async throws {
        let transport = FakeTransport()
        transport.respond(to: TestData.graphQLPath, json: TestData.character)
        let character = try await client(transport).character(id: TestData.characterID)
        #expect(character.name == "Dr Ignatius Constaline" && character.level == 15 && character.game == .pathfinder)
        #expect(character.avatarURL?.absoluteString == "https://example.com/avatar.png")
        let request = try #require(transport.requests.first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
        let body = try #require(request.httpBody.flatMap { String(data: $0, encoding: .utf8) })
        #expect(body.contains(TestData.characterID))
    }

    @Test("Without a token, GraphQL is asked anonymously, which works for public characters")
    func anonymous() async throws {
        let transport = FakeTransport()
        transport.respond(to: TestData.graphQLPath, json: TestData.character)
        _ = try await client(transport, token: nil).character(id: TestData.characterID)
        #expect(transport.requests.first?.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("An unknown character, an expired token and other GraphQL errors are told apart")
    func characterErrors() async {
        let transport = FakeTransport()
        transport.respond(to: TestData.graphQLPath, json: ["data": ["demiplane_user_character": []]])
        transport.respond(to: TestData.graphQLPath, json: ["errors": [["message": "could not verify: Jwt expired"]]])
        transport.respond(to: TestData.graphQLPath, json: ["errors": [["message": "field not found"]]])
        transport.respond(to: TestData.graphQLPath, status: 401, body: Data())
        let client = client(transport)
        await #expect(throws: CharacterImportError.self) { try await client.character(id: "x") }
        await expectError("tokenExpired") { try await client.character(id: "x") }
        await expectError("rejected") { try await client.character(id: "x") }
        await expectError("tokenExpired") { try await client.character(id: "x") }
    }

    @Test("Export waits through 202s, then returns the PDF link and revision, sending the session cookies")
    func export() async throws {
        let transport = FakeTransport()
        transport.respond(to: TestData.exportPath, status: 202, body: Data())
        transport.respond(to: TestData.exportPath, status: 202, body: Data())
        transport.respond(to: TestData.exportPath, json: TestData.exportDone())
        let export = try await client(transport).exportSheet(id: TestData.characterID)
        #expect(export.revision == "rev1" && export.url.absoluteString.hasSuffix("sheet.pdf?revision=rev1"))
        let requests = transport.requests(to: TestData.exportPath)
        #expect(requests.count == 3)
        #expect(requests[0].value(forHTTPHeaderField: "Cookie") == session.cookieHeader)
        let body = try #require(requests[0].httpBody.flatMap { String(data: $0, encoding: .utf8) })
        #expect(body.contains("GENERATE_CHARACTER_PDF_LAMBDA_NAME") && body.contains(TestData.characterID))
    }

    @Test("Export gives up after too many 202s, and needs a session")
    func exportFailures() async {
        let transport = FakeTransport()
        transport.respond(to: TestData.exportPath, status: 202, body: Data())
        var patient = client(transport)
        patient.maximumPolls = 3
        await expectError("timedOut") { try await patient.exportSheet(id: "x") }
        await expectError("signInNeeded") { try await client(transport, signedIn: false).exportSheet(id: "x") }
        let rejected = FakeTransport()
        rejected.respond(to: TestData.exportPath, status: 401, body: Data())
        await expectError("signInNeeded") { try await client(rejected).exportSheet(id: "x") }
        let odd = FakeTransport()
        odd.respond(to: TestData.exportPath, json: ["success": true])
        await expectError("unexpectedResponse") { try await client(odd).exportSheet(id: "x") }
    }

    @Test("A sheet that was never exported is reported as such")
    func notExported() async throws {
        let transport = FakeTransport()
        let url = DemiplaneClient.publicSheetURL(id: "abc", game: .pathfinder)
        transport.respond(to: url.path, status: 403, body: Data())
        await expectError("notExported") { try await client(transport).sheetPDF(at: url) }
        #expect(url.absoluteString.contains("/nexus/pathfinder-2e/character/pdf/v2/user/abc/default.pdf"))
        #expect(DemiplaneClient.publicSheetURL(id: "abc", game: .starfinder).path.contains("starfinder-2e"))
    }

    @Test("A campaign's characters are found wherever their UUIDs sit, without repeats")
    func campaign() async throws {
        let transport = FakeTransport()
        transport.respond(to: "/api/getCampaign", json: ["campaignResponse": [
            "campaign": ["name": "Starfinder Society"],
            "campaignUserCharacters": [
                ["id": 1, "user_character": ["uuid": "aaa", "name": "Navasi"]],
                ["uuid": "bbb"], ["user_character": ["uuid": "aaa"]], ["id": 4]
            ]
        ]])
        let campaign = try await client(transport).campaign(id: "camp")
        #expect(campaign == DemiplaneCampaign(name: "Starfinder Society", characterIDs: ["aaa", "bbb"]))
        #expect(transport.requests.first?.url?.query == "campaignUuid=camp")
    }

    @Test("A campaign needs a signed-in session")
    func campaignSignedOut() async {
        let transport = FakeTransport()
        transport.respond(to: "/api/getCampaign", status: 401, json: ["error": "User is not logged in"])
        await expectError("signInNeeded") { try await client(transport).campaign(id: "camp") }
        await expectError("signInNeeded") { try await client(transport, signedIn: false).campaign(id: "camp") }
    }

    @Test("A fresh GraphQL token comes from the session's access token")
    func renewToken() async throws {
        let transport = FakeTransport()
        transport.respond(to: "/api/auth/token", json: ["accessToken": "openauth", "refreshToken": "r"])
        transport.respond(to: "/api/generate-graphql-token", json: ["success": true, "data": ["token": "hasura"]])
        #expect(try await client(transport).graphQLToken() == "hasura")
        let generate = try #require(transport.requests(to: "/api/generate-graphql-token").first)
        #expect(generate.value(forHTTPHeaderField: "Authorization") == "Bearer openauth")
        let signedOut = FakeTransport()
        signedOut.respond(to: "/api/auth/token", json: [:])
        await expectError("signInNeeded") { try await client(signedOut).graphQLToken() }
    }

    @Test("A session needs Demiplane's access token cookie")
    func sessionFromCookies() throws {
        let cookie = { (name: String, domain: String) in
            HTTPCookie(properties: [.name: name, .value: "v", .domain: domain, .path: "/"])!
        }
        #expect(DemiplaneSession(cookies: [cookie("_ga", ".demiplane.com")]) == nil)
        let session = try #require(DemiplaneSession(cookies: [
            cookie("access_token", "app.demiplane.com"), cookie("refresh_token", ".demiplane.com"),
            cookie("other", "example.com")
        ]))
        #expect(session.cookieHeader == "access_token=v; refresh_token=v")
    }

    private func expectError(
        _ name: String, sourceLocation: SourceLocation = #_sourceLocation, _ body: () async throws -> some Any
    ) async {
        do {
            _ = try await body()
            Issue.record("Expected \(name)", sourceLocation: sourceLocation)
        } catch {
            #expect(String(describing: error).hasPrefix(name), sourceLocation: sourceLocation)
        }
    }
}
