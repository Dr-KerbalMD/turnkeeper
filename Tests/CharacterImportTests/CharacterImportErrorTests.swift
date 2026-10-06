import CombatPadKit
import Foundation
import Testing
@testable import CharacterImport

@Suite("Character import errors and transport")
struct CharacterImportErrorTests {
    @Test("Every error names its operation and says what went wrong")
    func messages() {
        let underlying = URLError(.cannotDecodeContentData)
        let errors: [(CharacterImportError, String)] = [
            (.unreadableImage(operation: "Reading", underlying: underlying), "couldn't be read"),
            (.notASheet(operation: "Reading"), "isn't a fillable"),
            (.notFound(operation: "Reading", id: "abc"), "no character abc"),
            (.notExported(operation: "Reading"), "hasn't been exported"),
            (.signInNeeded(operation: "Reading"), "sign in"),
            (.tokenExpired(operation: "Reading"), "has expired"),
            (.rejected(operation: "Reading", status: 500, message: "boom"), "500 (boom)"),
            (.rejected(operation: "Reading", status: 500, message: ""), "answered 500."),
            (.timedOut(operation: "Reading"), "too long"),
            (.unexpectedResponse(operation: "Reading", detail: "odd"), "unexpected (odd)")
        ]
        for (error, fragment) in errors {
            let message = error.errorDescription ?? ""
            #expect(message.hasPrefix("Reading failed: ") && message.contains(fragment), "\(message)")
        }
    }

    @Test("URLSession sends requests and hands back the HTTP response")
    func urlSession() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        let session = URLSession(configuration: configuration)
        let (data, response) = try await session.send(URLRequest(url: URL(string: "https://stub.test/x")!))
        #expect(response.statusCode == 418 && String(data: data, encoding: .utf8) == "teapot")
    }

    @Test("A client reports refusals, bodies that aren't JSON and failed downloads")
    func clientFailures() async {
        let transport = FakeTransport()
        transport.respond(to: TestData.graphQLPath, status: 500, body: Data("down".utf8))
        transport.respond(to: TestData.graphQLPath, body: Data("<html>".utf8))
        transport.respond(to: "/sheet.pdf", status: 500, body: Data())
        let client = DemiplaneClient(transport: transport, token: nil, session: nil)
        await #expect(throws: CharacterImportError.self) { try await client.character(id: "x") }
        await #expect(throws: CharacterImportError.self) { try await client.character(id: "x") }
        await #expect(throws: CharacterImportError.self) {
            try await client.sheetPDF(at: URL(string: "https://content.demiplane.com/sheet.pdf")!)
        }
    }

    @Test("A character without an avatar or a known game still reads")
    func sparseCharacter() async throws {
        let transport = FakeTransport()
        transport.respond(to: TestData.graphQLPath, json: ["data": ["demiplane_user_character": [
            ["uuid": "x", "name": "Kyra", "level": 3, "avatar_url": "", "nexus": ["slug": "other"]]
        ]]])
        let character = try await DemiplaneClient(transport: transport, token: "", session: nil).character(id: "x")
        #expect(character.avatarURL == nil && character.game == nil && character.name == "Kyra")
        #expect(transport.requests.first?.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("Sheet fields read checkboxes, numbers, lists and proficiency")
    func sheetFields() {
        let fields = SheetFields(values: [
            "flag": "On", "other": "Off", "bonus": "+5", "words": "a, , b", "skill_prof_expert": "Yes",
            "feat_1": "Toughness", "feat_2": "Toughness", "feat_x": "Ignored"
        ])
        #expect(fields.isChecked("flag") && !fields.isChecked("other") && !fields.isChecked("missing"))
        #expect(fields.int("bonus") == 5 && fields.int("words") == 0)
        #expect(fields.list("words") == ["a", "b"])
        #expect(fields.proficiency("skill_prof") == 2 && fields.proficiency("none") == 0)
        #expect(fields.numbered("feat_") == ["Toughness"])
    }
}

/// Answers every request with 418 "teapot".
final class StubProtocol: URLProtocol {
    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 418, httpVersion: nil, headerFields: nil) else {
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("teapot".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
