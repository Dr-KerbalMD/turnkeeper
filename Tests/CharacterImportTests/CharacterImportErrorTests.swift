import TurnkeeperKit
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
            (.missingNumbers(operation: "Reading", name: ""), "sent the sheet without its numbers"),
            (.notShared(operation: "Reading"), "isn't shared"),
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

    @Test("Only a sheet sent without its numbers is fixed by opening the character on Demiplane")
    func fixedByOpeningSheet() {
        #expect(CharacterImportError.missingNumbers(operation: "Reading", name: "Mandor").isFixedByOpeningSheet)
        #expect(!CharacterImportError.notShared(operation: "Reading").isFixedByOpeningSheet)
    }

    @Test("URLSession sends requests and hands back the HTTP response")
    func urlSession() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        let session = URLSession(configuration: configuration)
        let (data, response) = try await session.send(URLRequest(url: URL(string: "https://stub.test/x")!))
        #expect(response.statusCode == 418 && String(data: data, encoding: .utf8) == "teapot")
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
