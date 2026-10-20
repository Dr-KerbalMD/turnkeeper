import TurnkeeperKit
import Foundation
import Testing
@testable import CharacterImport

@Suite("Demiplane client")
struct DemiplaneClientTests {
    private func client(_ transport: FakeTransport) -> DemiplaneClient {
        var client = DemiplaneClient(transport: transport)
        client.sleep = { _ in }
        return client
    }

    @Test("Export keeps asking while Demiplane answers 200 without the PDF link")
    func exportStillBuilding() async throws {
        let transport = FakeTransport()
        transport.respond(to: TestData.exportPath, json: ["success": true, "result": ["cacheStatus": "pending"]])
        transport.respond(to: TestData.exportPath, json: TestData.exportDone())
        let export = try await client(transport).exportSheet(id: TestData.characterID)
        #expect(export.revision == "rev1")
        #expect(transport.requests(to: TestData.exportPath).count == 2)
    }

    @Test("Export waits through 202s, then returns the PDF link and revision, without cookies or a token")
    func export() async throws {
        let transport = FakeTransport()
        transport.respond(to: TestData.exportPath, status: 202, body: Data())
        transport.respond(to: TestData.exportPath, status: 202, body: Data())
        transport.respond(to: TestData.exportPath, json: TestData.exportDone())
        let export = try await client(transport).exportSheet(id: TestData.characterID)
        #expect(export.revision == "rev1" && export.url.absoluteString.hasSuffix("sheet.pdf?revision=rev1"))
        let requests = transport.requests(to: TestData.exportPath)
        #expect(requests.count == 3)
        #expect(requests[0].value(forHTTPHeaderField: "Cookie") == nil)
        #expect(requests[0].value(forHTTPHeaderField: "Authorization") == nil)
        let body = try #require(requests[0].httpBody.flatMap { String(data: $0, encoding: .utf8) })
        #expect(body.contains("GENERATE_CHARACTER_PDF_LAMBDA_NAME") && body.contains(TestData.characterID))
    }

    @Test("Export gives up after too many polls")
    func exportTimesOut() async {
        for answer in [(status: 202, json: [String: Any]()), (status: 200, json: ["success": true])] {
            let transport = FakeTransport()
            transport.respond(to: TestData.exportPath, status: answer.status, json: answer.json)
            var patient = client(transport)
            patient.maximumPolls = 3
            await expectError("timedOut") { try await patient.exportSheet(id: "x") }
        }
    }

    @Test("A character that isn't shared can't be exported or downloaded; other refusals say their status")
    func refusals() async {
        for status in [401, 403, 404] {
            let transport = FakeTransport()
            transport.respond(to: TestData.exportPath, status: status, body: Data())
            transport.respond(to: "/sheet.pdf", status: status, body: Data())
            await expectError("notShared") { try await client(transport).exportSheet(id: "x") }
            await expectError("notShared") { try await client(transport).sheetPDF(at: TestData.sheetURL) }
        }
        let broken = FakeTransport()
        broken.respond(to: TestData.exportPath, status: 500, body: Data())
        broken.respond(to: "/sheet.pdf", status: 500, body: Data())
        await expectError("rejected") { try await client(broken).exportSheet(id: "x") }
        await expectError("rejected") { try await client(broken).sheetPDF(at: TestData.sheetURL) }
    }

    @Test("The sheet PDF downloads as it is")
    func sheetPDF() async throws {
        let transport = FakeTransport()
        transport.respond(to: "/sheet.pdf", body: Data("%PDF".utf8))
        #expect(try await client(transport).sheetPDF(at: TestData.sheetURL) == Data("%PDF".utf8))
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
